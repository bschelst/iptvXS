// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/cast/chromecast_manager.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkDatagram>
#include <QNetworkInterface>
#include <QSslConfiguration>
#include <QtEndian>

namespace iptvxs {

static const char *NS_CONNECTION = "urn:x-cast:com.google.cast.tp.connection";
static const char *NS_HEARTBEAT = "urn:x-cast:com.google.cast.tp.heartbeat";
static const char *NS_RECEIVER = "urn:x-cast:com.google.cast.receiver";
static const char *NS_MEDIA = "urn:x-cast:com.google.cast.media";
static const char *DEFAULT_MEDIA_RECEIVER = "CC1AD845";

ChromecastManager::ChromecastManager(QObject *parent)
    : QObject(parent) {}

ChromecastManager::~ChromecastManager() {
    stopDiscovery();
    disconnect();
}

// --- mDNS Discovery ---

void ChromecastManager::startDiscovery() {
    devices_.clear();
    emit devicesChanged();

    if (!mdnsSocket_) {
        mdnsSocket_ = new QUdpSocket(this);
        mdnsSocket_->bind(QHostAddress::AnyIPv4, 5353,
                          QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint);
        mdnsSocket_->joinMulticastGroup(QHostAddress("224.0.0.251"));
        QObject::connect(mdnsSocket_, &QUdpSocket::readyRead,
                         this, &ChromecastManager::readMdnsResponse);
    }

    if (!discoveryTimer_) {
        discoveryTimer_ = new QTimer(this);
        discoveryTimer_->setInterval(3000);
        QObject::connect(discoveryTimer_, &QTimer::timeout,
                         this, &ChromecastManager::sendMdnsQuery);
    }

    sendMdnsQuery();
    discoveryTimer_->start();
}

void ChromecastManager::stopDiscovery() {
    if (discoveryTimer_) {
        discoveryTimer_->stop();
    }
}

void ChromecastManager::sendMdnsQuery() {
    // DNS query for _googlecast._tcp.local PTR record
    QByteArray query;
    // Header: ID=0, flags=0, QDCOUNT=1
    query.append(QByteArray(4, '\0'));                         // ID + flags
    query.append('\0'); query.append('\x01');                  // QDCOUNT=1
    query.append(QByteArray(4, '\0'));                         // ANCOUNT=0, NSCOUNT=0
    query.append('\0'); query.append('\0');                    // ARCOUNT=0

    // QNAME: _googlecast._tcp.local
    auto appendLabel = [&](const char *label) {
        auto len = static_cast<uint8_t>(strlen(label));
        query.append(static_cast<char>(len));
        query.append(label, len);
    };
    appendLabel("_googlecast");
    appendLabel("_tcp");
    appendLabel("local");
    query.append('\0'); // root label

    // QTYPE=PTR(12), QCLASS=IN(1)
    query.append('\0'); query.append('\x0c');
    query.append('\0'); query.append('\x01');

    mdnsSocket_->writeDatagram(query, QHostAddress("224.0.0.251"), 5353);
}

QString ChromecastManager::parseMdnsName(const QByteArray &data, int &offset) const {
    QString name;
    bool first = true;
    while (offset < data.size()) {
        uint8_t len = static_cast<uint8_t>(data.at(offset));
        if (len == 0) { offset++; break; }
        // Pointer compression
        if ((len & 0xC0) == 0xC0) {
            int ptr = ((len & 0x3F) << 8) | static_cast<uint8_t>(data.at(offset + 1));
            offset += 2;
            if (!first) name += '.';
            name += parseMdnsName(data, ptr);
            return name;
        }
        offset++;
        if (!first) name += '.';
        first = false;
        name += QString::fromUtf8(data.mid(offset, len));
        offset += len;
    }
    return name;
}

void ChromecastManager::readMdnsResponse() {
    while (mdnsSocket_->hasPendingDatagrams()) {
        auto datagram = mdnsSocket_->receiveDatagram();
        auto data = datagram.data();
        if (data.size() < 12) continue;

        // Parse DNS header
        int ancount = (static_cast<uint8_t>(data[6]) << 8) | static_cast<uint8_t>(data[7]);
        if (ancount == 0) continue;

        // Skip questions
        int qdcount = (static_cast<uint8_t>(data[4]) << 8) | static_cast<uint8_t>(data[5]);
        int offset = 12;
        for (int i = 0; i < qdcount && offset < data.size(); i++) {
            parseMdnsName(data, offset);
            offset += 4; // QTYPE + QCLASS
        }

        // Parse answers + additional records
        int totalRecords = ancount +
            ((static_cast<uint8_t>(data[8]) << 8) | static_cast<uint8_t>(data[9])) +
            ((static_cast<uint8_t>(data[10]) << 8) | static_cast<uint8_t>(data[11]));

        QString deviceName;
        QString deviceHost;
        quint16 devicePort = 8009;
        QString deviceId;

        for (int i = 0; i < totalRecords && offset + 10 < data.size(); i++) {
            parseMdnsName(data, offset);
            if (offset + 10 > data.size()) break;

            uint16_t rtype = (static_cast<uint8_t>(data[offset]) << 8) |
                             static_cast<uint8_t>(data[offset + 1]);
            offset += 8; // type(2) + class(2) + ttl(4)
            uint16_t rdlength = (static_cast<uint8_t>(data[offset]) << 8) |
                                static_cast<uint8_t>(data[offset + 1]);
            offset += 2;

            if (offset + rdlength > data.size()) break;

            if (rtype == 33) { // SRV
                if (rdlength >= 6) {
                    devicePort = (static_cast<uint8_t>(data[offset + 4]) << 8) |
                                 static_cast<uint8_t>(data[offset + 5]);
                    int targetOffset = offset + 6;
                    deviceHost = parseMdnsName(data, targetOffset);
                }
            } else if (rtype == 1) { // A record
                if (rdlength == 4) {
                    deviceHost = QString("%1.%2.%3.%4")
                        .arg(static_cast<uint8_t>(data[offset]))
                        .arg(static_cast<uint8_t>(data[offset + 1]))
                        .arg(static_cast<uint8_t>(data[offset + 2]))
                        .arg(static_cast<uint8_t>(data[offset + 3]));
                }
            } else if (rtype == 16) { // TXT
                int txtEnd = offset + rdlength;
                while (offset < txtEnd) {
                    uint8_t txtLen = static_cast<uint8_t>(data[offset]);
                    offset++;
                    if (offset + txtLen > txtEnd) break;
                    QString txt = QString::fromUtf8(data.mid(offset, txtLen));
                    if (txt.startsWith("fn=")) {
                        deviceName = txt.mid(3);
                    } else if (txt.startsWith("id=")) {
                        deviceId = txt.mid(3);
                    }
                    offset += txtLen;
                }
                continue;
            }
            offset += rdlength;
        }

        if (!deviceName.isEmpty() && !deviceHost.isEmpty()) {
            // Check for duplicate
            bool found = false;
            for (auto &d : devices_) {
                if (d.host == deviceHost) { found = true; break; }
            }
            if (!found) {
                devices_.append({deviceName, deviceHost, devicePort, deviceId});
                emit devicesChanged();
            }
        }
    }
}

QVariantList ChromecastManager::devices() const {
    QVariantList list;
    for (const auto &d : devices_) {
        list.append(QVariantMap{
            {"name", d.name},
            {"host", d.host},
            {"port", d.port},
            {"id", d.id}
        });
    }
    return list;
}

// --- Protobuf encoding ---

QByteArray ChromecastManager::encodeVarint(quint64 value) {
    QByteArray result;
    while (value > 0x7F) {
        result.append(static_cast<char>((value & 0x7F) | 0x80));
        value >>= 7;
    }
    result.append(static_cast<char>(value & 0x7F));
    return result;
}

QByteArray ChromecastManager::encodeVarintField(int fieldNumber, quint64 value) {
    QByteArray result;
    result.append(encodeVarint(static_cast<quint64>(fieldNumber << 3 | 0))); // wire type 0
    result.append(encodeVarint(value));
    return result;
}

QByteArray ChromecastManager::encodeString(int fieldNumber, const QString &value) {
    QByteArray utf8 = value.toUtf8();
    QByteArray result;
    result.append(encodeVarint(static_cast<quint64>(fieldNumber << 3 | 2))); // wire type 2
    result.append(encodeVarint(static_cast<quint64>(utf8.size())));
    result.append(utf8);
    return result;
}

quint64 ChromecastManager::decodeVarint(const QByteArray &data, int &offset) {
    quint64 result = 0;
    int shift = 0;
    while (offset < data.size()) {
        uint8_t byte = static_cast<uint8_t>(data.at(offset++));
        result |= static_cast<quint64>(byte & 0x7F) << shift;
        if ((byte & 0x80) == 0) break;
        shift += 7;
    }
    return result;
}

QString ChromecastManager::decodeString(const QByteArray &data, int &offset) {
    auto len = static_cast<int>(decodeVarint(data, offset));
    if (offset + len > data.size()) return {};
    auto result = QString::fromUtf8(data.mid(offset, len));
    offset += len;
    return result;
}

QByteArray ChromecastManager::encodeCastMessage(const QString &sourceId,
                                                 const QString &destId,
                                                 const QString &ns,
                                                 const QString &jsonPayload) const {
    QByteArray msg;
    msg.append(encodeVarintField(1, 0));          // protocol_version = CASTV2_1_0
    msg.append(encodeString(2, sourceId));         // source_id
    msg.append(encodeString(3, destId));           // destination_id
    msg.append(encodeString(4, ns));               // namespace
    msg.append(encodeVarintField(5, 0));           // payload_type = STRING
    msg.append(encodeString(6, jsonPayload));      // payload_utf8

    // Frame: 4-byte big-endian length prefix
    QByteArray frame;
    quint32 len = static_cast<quint32>(msg.size());
    char lenBytes[4];
    qToBigEndian(len, lenBytes);
    frame.append(lenBytes, 4);
    frame.append(msg);
    return frame;
}

// --- Cast Protocol ---

void ChromecastManager::sendCastMessage(const QString &destId, const QString &ns,
                                         const QString &jsonPayload) {
    if (!castSocket_ || castSocket_->state() != QAbstractSocket::ConnectedState) return;
    auto frame = encodeCastMessage("sender-0", destId, ns, jsonPayload);
    castSocket_->write(frame);
}

void ChromecastManager::connectToDevice(int index) {
    if (index < 0 || index >= devices_.size()) return;
    disconnect();

    connectedDeviceIndex_ = index;
    const auto &device = devices_[index];

    castSocket_ = new QSslSocket(this);

    auto sslConfig = castSocket_->sslConfiguration();
    sslConfig.setPeerVerifyMode(QSslSocket::VerifyNone);
    castSocket_->setSslConfiguration(sslConfig);

    QObject::connect(castSocket_, &QSslSocket::encrypted,
                     this, &ChromecastManager::onCastConnected);
    QObject::connect(castSocket_, &QSslSocket::readyRead,
                     this, &ChromecastManager::onCastData);
    QObject::connect(castSocket_, &QSslSocket::errorOccurred,
                     this, &ChromecastManager::onCastError);

    castSocket_->connectToHostEncrypted(device.host, device.port);
}

void ChromecastManager::disconnect() {
    if (hlsProxy_) {
        hlsProxy_->stop();
    }
    if (heartbeatTimer_) {
        heartbeatTimer_->stop();
        delete heartbeatTimer_;
        heartbeatTimer_ = nullptr;
    }
    if (castSocket_) {
        castSocket_->disconnectFromHost();
        castSocket_->deleteLater();
        castSocket_ = nullptr;
    }
    transportId_.clear();
    connectedDeviceIndex_ = -1;
    mediaSessionId_ = -1;
    requestId_ = 1;
    emit connectedChanged();
    emit castStopped();
}

bool ChromecastManager::connected() const {
    return castSocket_ && castSocket_->state() == QAbstractSocket::ConnectedState
           && connectedDeviceIndex_ >= 0;
}

QString ChromecastManager::connectedDeviceName() const {
    if (connectedDeviceIndex_ >= 0 && connectedDeviceIndex_ < devices_.size())
        return devices_[connectedDeviceIndex_].name;
    return {};
}

void ChromecastManager::onCastConnected() {
    // Open virtual connection to receiver
    QJsonObject connectMsg;
    connectMsg["type"] = "CONNECT";
    connectMsg["origin"] = QJsonObject();
    sendCastMessage("receiver-0", NS_CONNECTION,
                    QString::fromUtf8(QJsonDocument(connectMsg).toJson(QJsonDocument::Compact)));

    // Start heartbeat
    heartbeatTimer_ = new QTimer(this);
    heartbeatTimer_->setInterval(5000);
    QObject::connect(heartbeatTimer_, &QTimer::timeout,
                     this, &ChromecastManager::sendHeartbeat);
    heartbeatTimer_->start();

    // Get receiver status to find running apps
    QJsonObject statusMsg;
    statusMsg["type"] = "GET_STATUS";
    statusMsg["requestId"] = requestId_++;
    sendCastMessage("receiver-0", NS_RECEIVER,
                    QString::fromUtf8(QJsonDocument(statusMsg).toJson(QJsonDocument::Compact)));

    emit connectedChanged();
}

void ChromecastManager::onCastData() {
    static QByteArray buffer;
    buffer.append(castSocket_->readAll());

    while (buffer.size() >= 4) {
        quint32 msgLen = qFromBigEndian<quint32>(buffer.constData());
        if (static_cast<int>(msgLen) + 4 > buffer.size()) break;

        QByteArray msgData = buffer.mid(4, static_cast<int>(msgLen));
        buffer.remove(0, static_cast<int>(msgLen) + 4);

        // Parse protobuf CastMessage
        int offset = 0;
        QString ns, payload;
        while (offset < msgData.size()) {
            auto key = decodeVarint(msgData, offset);
            int fieldNum = static_cast<int>(key >> 3);
            int wireType = static_cast<int>(key & 0x07);

            if (wireType == 0) {
                decodeVarint(msgData, offset);
            } else if (wireType == 2) {
                auto str = decodeString(msgData, offset);
                if (fieldNum == 4) ns = str;
                else if (fieldNum == 6) payload = str;
            } else {
                break;
            }
        }

        if (!ns.isEmpty()) {
            handleCastMessage(ns, payload);
        }
    }
}

void ChromecastManager::handleCastMessage(const QString &ns, const QString &payload) {
    auto doc = QJsonDocument::fromJson(payload.toUtf8());
    auto obj = doc.object();
    auto type = obj["type"].toString();

    if (ns == NS_HEARTBEAT && type == "PING") {
        QJsonObject pong;
        pong["type"] = "PONG";
        sendCastMessage("receiver-0", NS_HEARTBEAT,
                        QString::fromUtf8(QJsonDocument(pong).toJson(QJsonDocument::Compact)));
    } else if (ns == NS_RECEIVER && type == "RECEIVER_STATUS") {
        auto status = obj["status"].toObject();
        auto apps = status["applications"].toArray();
        if (!apps.isEmpty()) {
            auto app = apps[0].toObject();
            auto newTransportId = app["transportId"].toString();
            if (!newTransportId.isEmpty() && newTransportId != transportId_) {
                transportId_ = newTransportId;
                mediaSessionId_ = -1;
                QJsonObject connectMsg;
                connectMsg["type"] = "CONNECT";
                connectMsg["origin"] = QJsonObject();
                sendCastMessage(transportId_, NS_CONNECTION,
                                QString::fromUtf8(QJsonDocument(connectMsg).toJson(QJsonDocument::Compact)));
                if (!pendingUrl_.isEmpty()) {
                    auto *t = new QTimer(this);
                    t->setSingleShot(true);
                    t->setInterval(1000);
                    QObject::connect(t, &QTimer::timeout, this, [this, t]() {
                        t->deleteLater();
                        sendPendingMedia();
                    });
                    t->start();
                }
            }
        }
    } else if (ns == NS_MEDIA) {
        if (type == "MEDIA_STATUS") {
            auto statusArr = obj["status"].toArray();
            if (!statusArr.isEmpty()) {
                auto ms = statusArr[0].toObject();
                mediaSessionId_ = ms["mediaSessionId"].toInt(-1);
                auto playerState = ms["playerState"].toString();
                auto idleReason = ms["idleReason"].toString();
                if (playerState == "IDLE" && idleReason == "ERROR") {
                    if (hlsAttempted_ && lastCastUrl_.endsWith(".m3u8")) {
                        // HLS failed — retry with original .ts URL
                        qWarning() << "Cast: HLS failed, retrying with original TS URL";
                        auto origUrl = lastCastUrl_.left(lastCastUrl_.length() - 5) + ".ts";
                        hlsAttempted_ = false;

                        QJsonObject media;
                        media["contentId"] = origUrl;
                        media["contentType"] = QStringLiteral("video/mp2t");
                        media["streamType"] = QStringLiteral("LIVE");

                        QJsonObject metadata;
                        metadata["type"] = 0;
                        metadata["metadataType"] = 0;
                        metadata["title"] = pendingTitle_.isEmpty() ? QStringLiteral("Live TV") : pendingTitle_;
                        QJsonObject logoImage;
                        logoImage["url"] = QStringLiteral("https://iptvxs.schelstraete.org/static/assets/iptvxs_cast_logo.png");
                        QJsonArray images;
                        images.append(logoImage);
                        metadata["images"] = images;
                        media["metadata"] = metadata;

                        QJsonObject load;
                        load["type"] = "LOAD";
                        load["media"] = media;
                        load["autoplay"] = true;
                        load["requestId"] = requestId_++;

                        lastCastUrl_ = origUrl;
                        qWarning() << "Cast LOAD retry:" << origUrl;
                        sendCastMessage(transportId_, NS_MEDIA,
                                        QString::fromUtf8(QJsonDocument(load).toJson(QJsonDocument::Compact)));
                        return;
                    }
                    emit castError("Chromecast: " + idleReason);
                    emit castStopped();
                } else if (playerState == "IDLE" && idleReason == "FINISHED") {
                    if (!nextEpisodeUrl_.isEmpty()) {
                        qWarning() << "Cast: episode finished, loading next";
                        pendingUrl_ = nextEpisodeUrl_;
                        pendingTitle_ = nextEpisodeTitle_;
                        pendingContentType_ = nextEpisodeContentType_;
                        nextEpisodeUrl_.clear();
                        nextEpisodeTitle_.clear();
                        nextEpisodeContentType_.clear();
                        sendPendingMedia();
                    } else {
                        emit castStopped();
                    }
                } else if (playerState == "IDLE" && !idleReason.isEmpty() && idleReason != "INTERRUPTED") {
                    emit castError("Chromecast: " + idleReason);
                    emit castStopped();
                }
            }
        } else if (type == "LOAD_FAILED") {
            if (hlsAttempted_ && lastCastUrl_.endsWith(".m3u8")) {
                qWarning() << "Cast: LOAD_FAILED with HLS, retrying with TS";
                auto origUrl = lastCastUrl_.left(lastCastUrl_.length() - 5) + ".ts";
                hlsAttempted_ = false;
                lastCastUrl_ = origUrl;

                QJsonObject media;
                media["contentId"] = origUrl;
                media["contentType"] = QStringLiteral("video/mp2t");
                media["streamType"] = QStringLiteral("LIVE");

                QJsonObject metadata;
                metadata["type"] = 0;
                metadata["metadataType"] = 0;
                metadata["title"] = QStringLiteral("Live TV");
                QJsonObject logoImage;
                logoImage["url"] = QStringLiteral("https://iptvxs.schelstraete.org/static/assets/iptvxs_cast_logo.png");
                QJsonArray images;
                images.append(logoImage);
                metadata["images"] = images;
                media["metadata"] = metadata;

                QJsonObject load;
                load["type"] = "LOAD";
                load["media"] = media;
                load["autoplay"] = true;
                load["requestId"] = requestId_++;

                sendCastMessage(transportId_, NS_MEDIA,
                                QString::fromUtf8(QJsonDocument(load).toJson(QJsonDocument::Compact)));
                return;
            }
            emit castError("Chromecast failed to load media");
            emit castStopped();
        } else if (type == "INVALID_REQUEST") {
            auto reason = obj["reason"].toString();
            emit castError("Chromecast: invalid request — " + reason);
        }
    }
}

void ChromecastManager::setNextEpisode(const QString &url, const QString &title,
                                        const QString &contentType) {
    nextEpisodeUrl_ = url;
    nextEpisodeTitle_ = title;
    nextEpisodeContentType_ = contentType;
}

void ChromecastManager::sendHeartbeat() {
    QJsonObject ping;
    ping["type"] = "PING";
    sendCastMessage("receiver-0", NS_HEARTBEAT,
                    QString::fromUtf8(QJsonDocument(ping).toJson(QJsonDocument::Compact)));
}

void ChromecastManager::launchDefaultReceiver() {
    QJsonObject launch;
    launch["type"] = "LAUNCH";
    launch["appId"] = DEFAULT_MEDIA_RECEIVER;
    launch["requestId"] = requestId_++;
    sendCastMessage("receiver-0", NS_RECEIVER,
                    QString::fromUtf8(QJsonDocument(launch).toJson(QJsonDocument::Compact)));
}

QString ChromecastManager::convertToHlsUrl(const QString &url) {
    // Xtream API: /live/user/pass/id.ts → /live/user/pass/id.m3u8
    // Chromecast can't play raw MPEG-TS but supports HLS natively
    if (url.contains("/live/") && url.endsWith(".ts")) {
        return url.left(url.length() - 3) + ".m3u8";
    }
    return url;
}

void ChromecastManager::sendPendingMedia() {
    if (pendingUrl_.isEmpty() || transportId_.isEmpty()) {
        if (transportId_.isEmpty())
            emit castError("Failed to launch media receiver");
        pendingUrl_.clear();
        return;
    }

    bool isLive = pendingUrl_.contains("/live/");
    QString castUrl;
    QString contentType;

    if (isLive) {
        // Start local HLS proxy — remux TS to HLS via ffmpeg
        if (!hlsProxy_)
            hlsProxy_ = new HlsProxy(this);
        castUrl = hlsProxy_->start(pendingUrl_);
        if (castUrl.isEmpty()) {
            emit castError("Failed to start HLS proxy");
            pendingUrl_.clear();
            return;
        }
        contentType = "application/vnd.apple.mpegurl";
    } else {
        castUrl = pendingUrl_;
    }

    if (contentType.isEmpty()) {
        if (castUrl.endsWith(".mp4"))
            contentType = "video/mp4";
        else if (castUrl.endsWith(".mkv"))
            contentType = "video/x-matroska";
        else
            contentType = pendingContentType_;
    }

    QJsonObject media;
    media["contentId"] = castUrl;
    media["contentType"] = contentType;
    media["streamType"] = isLive ? "LIVE" : "BUFFERED";

    QJsonObject metadata;
    metadata["type"] = 0;
    metadata["metadataType"] = 0;
    metadata["title"] = pendingTitle_;

    QJsonObject logoImage;
    logoImage["url"] = QStringLiteral("https://iptvxs.schelstraete.org/static/assets/iptvxs_cast_logo.png");
    QJsonArray images;
    images.append(logoImage);
    metadata["images"] = images;

    media["metadata"] = metadata;

    QJsonObject load;
    load["type"] = "LOAD";
    load["media"] = media;
    load["autoplay"] = true;
    load["requestId"] = requestId_++;

    lastCastUrl_ = castUrl;
    hlsAttempted_ = false;

    auto loadJson = QString::fromUtf8(QJsonDocument(load).toJson(QJsonDocument::Compact));
    qWarning() << "Cast LOAD: contentType:" << contentType << "streamType:" << (isLive ? "LIVE" : "BUFFERED");
    sendCastMessage(transportId_, NS_MEDIA, loadJson);

    activeCastUrl_ = pendingUrl_;
    activeCastTitle_ = pendingTitle_;
    pendingUrl_.clear();
    pendingTitle_.clear();
    pendingContentType_.clear();
    emit castStarted();
}

void ChromecastManager::castMedia(const QString &url, const QString &title,
                                   const QString &contentType) {
    if (!connected()) {
        emit castError("Not connected to a Chromecast");
        return;
    }

    pendingUrl_ = url;
    pendingTitle_ = title;
    pendingContentType_ = contentType;

    // If we already have a transport, send directly
    if (!transportId_.isEmpty()) {
        sendPendingMedia();
        return;
    }

    // Otherwise launch receiver — media will be sent when RECEIVER_STATUS arrives
    launchDefaultReceiver();
}

void ChromecastManager::stopMedia() {
    if (hlsProxy_) {
        hlsProxy_->stop();
    }
    auto url = activeCastUrl_;
    auto title = activeCastTitle_;
    activeCastUrl_.clear();
    activeCastTitle_.clear();
    if (transportId_.isEmpty()) return;
    QJsonObject stop;
    stop["type"] = "STOP";
    stop["requestId"] = requestId_++;
    if (mediaSessionId_ >= 0)
        stop["mediaSessionId"] = mediaSessionId_;
    sendCastMessage(transportId_, NS_MEDIA,
                    QString::fromUtf8(QJsonDocument(stop).toJson(QJsonDocument::Compact)));
    emit castStopped();
    if (!url.isEmpty())
        emit resumeLocal(url, title);
}

void ChromecastManager::pauseMedia() {
    if (transportId_.isEmpty()) return;
    QJsonObject pause;
    pause["type"] = "PAUSE";
    pause["requestId"] = requestId_++;
    sendCastMessage(transportId_, NS_MEDIA,
                    QString::fromUtf8(QJsonDocument(pause).toJson(QJsonDocument::Compact)));
}

void ChromecastManager::playMedia() {
    if (transportId_.isEmpty()) return;
    QJsonObject play;
    play["type"] = "PLAY";
    play["requestId"] = requestId_++;
    sendCastMessage(transportId_, NS_MEDIA,
                    QString::fromUtf8(QJsonDocument(play).toJson(QJsonDocument::Compact)));
}

void ChromecastManager::onCastError(QAbstractSocket::SocketError error) {
    Q_UNUSED(error)
    emit castError("Connection to Chromecast failed: " + castSocket_->errorString());
    disconnect();
}

} // namespace iptvxs
