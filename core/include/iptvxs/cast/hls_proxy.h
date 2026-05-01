// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QProcess>
#include <QTcpServer>
#include <QTemporaryDir>

namespace iptvxs {

class HlsProxy : public QObject {
    Q_OBJECT

public:
    explicit HlsProxy(QObject *parent = nullptr);
    ~HlsProxy() override;

    Q_INVOKABLE QString start(const QString &inputUrl);
    Q_INVOKABLE void stop();
    Q_INVOKABLE bool running() const;

signals:
    void errorOccurred(const QString &message);

private:
    QTcpServer *server_{nullptr};
    QProcess *ffmpeg_{nullptr};
    QTemporaryDir *tmpDir_{nullptr};
    QString localIp_;

    void handleConnection();
    void serveFile(QTcpSocket *socket, const QString &path);
    QString findLocalIp() const;
    QString findFfmpeg() const;
};

} // namespace iptvxs
