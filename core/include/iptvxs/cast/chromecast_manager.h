// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSslSocket>
#include <QTimer>
#include <QUdpSocket>
#include <QVariantList>
#include <QVariantMap>

#include "hls_proxy.h"

namespace iptvxs {

class ChromecastManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString connectedDeviceName READ connectedDeviceName NOTIFY connectedChanged)

public:
    explicit ChromecastManager(QObject *parent = nullptr);
    ~ChromecastManager() override;

    struct Device {
        QString name;
        QString host;
        quint16 port{8009};
        QString id;
    };

    Q_INVOKABLE void startDiscovery();
    Q_INVOKABLE void stopDiscovery();
    QVariantList devices() const;

    Q_INVOKABLE void connectToDevice(int index);
    Q_INVOKABLE void disconnect();
    bool connected() const;
    QString connectedDeviceName() const;

    Q_INVOKABLE void castMedia(const QString &url, const QString &title,
                               const QString &contentType = "video/mp4");
    Q_INVOKABLE void stopMedia();
    Q_INVOKABLE void pauseMedia();
    Q_INVOKABLE void playMedia();
    Q_INVOKABLE void setNextEpisode(const QString &url, const QString &title,
                                     const QString &contentType = "video/mp4");

signals:
    void devicesChanged();
    void connectedChanged();
    void castError(const QString &message);
    void castStarted();
    void castStopped();
    void resumeLocal(const QString &url, const QString &title);

private:
    // mDNS discovery
    QUdpSocket *mdnsSocket_{nullptr};
    QTimer *discoveryTimer_{nullptr};
    QList<Device> devices_;
    void sendMdnsQuery();
    void readMdnsResponse();
    QString parseMdnsName(const QByteArray &data, int &offset) const;

    // Cast protocol
    QSslSocket *castSocket_{nullptr};
    QTimer *heartbeatTimer_{nullptr};
    QString transportId_;
    int requestId_{1};
    int mediaSessionId_{-1};
    int connectedDeviceIndex_{-1};

    QByteArray encodeCastMessage(const QString &sourceId,
                                 const QString &destId,
                                 const QString &ns,
                                 const QString &jsonPayload) const;
    void sendCastMessage(const QString &destId, const QString &ns,
                         const QString &jsonPayload);
    void onCastConnected();
    void onCastData();
    void onCastError(QAbstractSocket::SocketError error);
    void handleCastMessage(const QString &ns, const QString &payload);
    void sendHeartbeat();
    void launchDefaultReceiver();
    void sendPendingMedia();
    static QString convertToHlsUrl(const QString &url);

    // Pending media for async launch
    QString pendingUrl_;
    QString pendingTitle_;
    QString pendingContentType_;
    QString lastCastUrl_;
    bool hlsAttempted_{false};
    QString activeCastUrl_;
    QString activeCastTitle_;
    HlsProxy *hlsProxy_{nullptr};

    // Auto-next episode
    QString nextEpisodeUrl_;
    QString nextEpisodeTitle_;
    QString nextEpisodeContentType_;

    // Protobuf helpers
    static QByteArray encodeVarint(quint64 value);
    static QByteArray encodeString(int fieldNumber, const QString &value);
    static QByteArray encodeVarintField(int fieldNumber, quint64 value);
    static quint64 decodeVarint(const QByteArray &data, int &offset);
    static QString decodeString(const QByteArray &data, int &offset);
};

} // namespace iptvxs
