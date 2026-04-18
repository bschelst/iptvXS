#include "iptvxs/parser/m3u_parser.h"

#include <QNetworkReply>
#include <QRegularExpression>
#include <QTextStream>
#include <QUrl>

#include "iptvxs/net/http_client.h"

namespace iptvxs {

M3uParser::M3uParser(QObject *parent)
    : QObject(parent) {}

void M3uParser::parse(QIODevice *device, int64_t serverId) {
    discoveredGroups_.clear();
    QTextStream stream(device);
    stream.setEncoding(QStringConverter::Utf8);

    QString line;
    ExtInfData currentInfo{};
    bool hasExtInf = false;
    int lineNumber = 0;
    int parsedCount = 0;

    while (stream.readLineInto(&line)) {
        ++lineNumber;

        // Strip BOM from first line
        if (lineNumber == 1 && line.startsWith(QChar(0xFEFF))) {
            line = line.mid(1);
        }

        line = line.trimmed();
        if (line.isEmpty()) {
            continue;
        }

        if (line.startsWith("#EXTM3U")) {
            continue;
        }

        if (line.startsWith("#EXTINF:")) {
            currentInfo = parseExtInf(line);
            hasExtInf = true;
            continue;
        }

        if (line.startsWith('#')) {
            continue;
        }

        // This is a URL line
        if (!hasExtInf) {
            emit errorOccurred(QStringLiteral("URL without EXTINF"), lineNumber);
            continue;
        }

        Channel channel;
        channel.serverId = serverId;
        channel.name = currentInfo.name;
        channel.streamUrl = line;
        channel.logoUrl = currentInfo.tvgLogo;
        channel.epgChannelId = currentInfo.tvgId;
        channel.type = QStringLiteral("live");

        if (!currentInfo.groupTitle.isEmpty() &&
            !discoveredGroups_.contains(currentInfo.groupTitle)) {
            discoveredGroups_.insert(currentInfo.groupTitle);
            emit categoryDiscovered(currentInfo.groupTitle);
        }

        ++parsedCount;
        emit channelParsed(channel);

        if (parsedCount % 1000 == 0) {
            emit progressUpdated(parsedCount);
        }

        hasExtInf = false;
        currentInfo = {};
    }

    emit finished(parsedCount);
}

QVector<Channel> M3uParser::parseAll(QIODevice *device, int64_t serverId) {
    QVector<Channel> channels;
    connect(this, &M3uParser::channelParsed, this,
            [&channels](const Channel &ch) { channels.append(ch); });

    parse(device, serverId);

    disconnect(this, &M3uParser::channelParsed, this, nullptr);
    return channels;
}

void M3uParser::fromUrl(HttpClient *http, const QUrl &url, int64_t serverId,
                         std::function<void(QVector<Channel>, QSet<QString>)> onComplete,
                         std::function<void(QString)> onError,
                         QObject *context) {
    auto *reply = http->get(url);
    auto *ctx = context ? context : http;
    QObject::connect(reply, &QNetworkReply::finished, ctx, [reply, serverId, onComplete, onError]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            if (onError) {
                onError(reply->errorString());
            }
            return;
        }

        auto parser = std::make_unique<M3uParser>();
        auto channels = parser->parseAll(reply, serverId);
        if (onComplete) {
            onComplete(std::move(channels), parser->discoveredGroups_);
        }
    });
}

M3uParser::ExtInfData M3uParser::parseExtInf(const QString &line) {
    ExtInfData data;

    // Channel name is after the last comma
    auto lastComma = line.lastIndexOf(',');
    if (lastComma >= 0) {
        data.name = line.mid(lastComma + 1).trimmed();
    }

    data.tvgId = extractAttribute(line, QStringLiteral("tvg-id"));
    data.tvgLogo = extractAttribute(line, QStringLiteral("tvg-logo"));
    data.groupTitle = extractAttribute(line, QStringLiteral("group-title"));

    if (data.name.isEmpty()) {
        auto tvgName = extractAttribute(line, QStringLiteral("tvg-name"));
        if (!tvgName.isEmpty()) {
            data.name = tvgName;
        }
    }

    return data;
}

QString M3uParser::extractAttribute(const QString &line, const QString &key) {
    auto pattern = QStringLiteral("%1=\"").arg(key);
    auto start = line.indexOf(pattern, 0, Qt::CaseInsensitive);
    if (start < 0) {
        return {};
    }
    start += pattern.length();
    auto end = line.indexOf('"', start);
    if (end < 0) {
        return {};
    }
    return line.mid(start, end - start);
}

} // namespace iptvxs
