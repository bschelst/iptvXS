// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/cast/hls_proxy.h"

#include <QDir>
#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QNetworkInterface>
#include <QTcpSocket>

namespace iptvxs {

HlsProxy::HlsProxy(QObject *parent)
    : QObject(parent) {}

HlsProxy::~HlsProxy() {
    stop();
}

QString HlsProxy::findLocalIp() const {
    for (const auto &iface : QNetworkInterface::allInterfaces()) {
        if (iface.flags().testFlag(QNetworkInterface::IsLoopBack)) continue;
        if (!iface.flags().testFlag(QNetworkInterface::IsUp)) continue;
        if (!iface.flags().testFlag(QNetworkInterface::IsRunning)) continue;
        for (const auto &entry : iface.addressEntries()) {
            auto addr = entry.ip();
            if (addr.protocol() == QAbstractSocket::IPv4Protocol && !addr.isLoopback()) {
                return addr.toString();
            }
        }
    }
    return "127.0.0.1";
}

QString HlsProxy::findFfmpeg() const {
    const auto appDir = QCoreApplication::applicationDirPath();
    const QStringList candidates = {
        appDir + QStringLiteral("/ffmpeg"),
        appDir + QStringLiteral("/ffmpeg.exe"),
        QStringLiteral("/app/bin/ffmpeg"),
        QStringLiteral("ffmpeg")
    };
    for (const auto &candidate : candidates) {
        if (candidate == QStringLiteral("ffmpeg") || QFileInfo::exists(candidate)) {
            return candidate;
        }
    }
    return "ffmpeg";
}

QString HlsProxy::start(const QString &inputUrl) {
    stop();

    tmpDir_ = new QTemporaryDir();
    if (!tmpDir_->isValid()) {
        emit errorOccurred("Failed to create temp directory for HLS proxy");
        return {};
    }

    server_ = new QTcpServer(this);
    localIp_ = findLocalIp();
    if (!server_->listen(QHostAddress(localIp_), 0)) {
        emit errorOccurred("Failed to start HLS proxy server: " + server_->errorString());
        stop();
        return {};
    }
    QObject::connect(server_, &QTcpServer::newConnection,
                     this, &HlsProxy::handleConnection);
    auto port = server_->serverPort();
    auto hlsPath = tmpDir_->path() + "/stream.m3u8";

    ffmpeg_ = new QProcess(this);
    ffmpeg_->setProcessChannelMode(QProcess::MergedChannels);

    QObject::connect(ffmpeg_, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        Q_UNUSED(err)
        emit errorOccurred("ffmpeg error: " + ffmpeg_->errorString());
    });

    QStringList args = {
        "-y",
        "-i", inputUrl,
        "-c", "copy",
        "-f", "hls",
        "-hls_time", "2",
        "-hls_list_size", "5",
        "-hls_flags", "delete_segments+append_list",
        "-hls_segment_filename", tmpDir_->path() + "/seg%05d.ts",
        hlsPath
    };

    qWarning() << "HLS proxy starting on port" << port;
    ffmpeg_->start(findFfmpeg(), args);
    if (!ffmpeg_->waitForStarted(5000)) {
        emit errorOccurred("Failed to start ffmpeg for HLS proxy");
        stop();
        return {};
    }

    auto url = QString("http://%1:%2/stream.m3u8").arg(localIp_).arg(port);
    qWarning() << "HLS proxy serving at:" << url;
    return url;
}

void HlsProxy::stop() {
    if (ffmpeg_) {
        ffmpeg_->terminate();
        ffmpeg_->waitForFinished(3000);
        if (ffmpeg_->state() != QProcess::NotRunning)
            ffmpeg_->kill();
        ffmpeg_->deleteLater();
        ffmpeg_ = nullptr;
    }
    if (server_) {
        server_->close();
        server_->deleteLater();
        server_ = nullptr;
    }
    if (tmpDir_) {
        delete tmpDir_;
        tmpDir_ = nullptr;
    }
}

bool HlsProxy::running() const {
    return ffmpeg_ && ffmpeg_->state() == QProcess::Running;
}

void HlsProxy::handleConnection() {
    while (server_ && server_->hasPendingConnections()) {
        auto *socket = server_->nextPendingConnection();
        QObject::connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
            auto request = socket->readAll();
            auto firstLine = QString::fromUtf8(request.split('\n').first()).trimmed();
            // Parse "GET /path HTTP/1.1"
            auto parts = firstLine.split(' ');
            if (parts.size() >= 2) {
                auto path = parts[1];
                if (path.startsWith("/"))
                    path = path.mid(1);
                serveFile(socket, path);
            } else {
                socket->write("HTTP/1.1 400 Bad Request\r\n\r\n");
                socket->flush();
                socket->disconnectFromHost();
            }
        });
        QObject::connect(socket, &QTcpSocket::disconnected,
                         socket, &QTcpSocket::deleteLater);
    }
}

void HlsProxy::serveFile(QTcpSocket *socket, const QString &path) {
    if (!tmpDir_) {
        socket->write("HTTP/1.1 503 Service Unavailable\r\n\r\n");
        socket->flush();
        socket->disconnectFromHost();
        return;
    }

    auto filePath = tmpDir_->path() + "/" + QFileInfo(path).fileName();
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        socket->write("HTTP/1.1 404 Not Found\r\n\r\n");
        socket->flush();
        socket->disconnectFromHost();
        return;
    }

    auto data = file.readAll();
    QString contentType = "application/octet-stream";
    if (path.endsWith(".m3u8"))
        contentType = "application/vnd.apple.mpegurl";
    else if (path.endsWith(".ts"))
        contentType = "video/mp2t";

    auto response = QString(
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: %1\r\n"
        "Content-Length: %2\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "Cache-Control: no-cache\r\n"
        "Connection: close\r\n"
        "\r\n").arg(contentType).arg(data.size());

    socket->write(response.toUtf8());
    socket->write(data);
    socket->flush();
    socket->disconnectFromHost();
}

} // namespace iptvxs
