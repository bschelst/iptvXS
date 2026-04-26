// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QElapsedTimer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QTimer>
#include <QUrl>
#include <QVector>

namespace iptvxs {

struct SpeedTestResult {
    double downloadMbps{0.0};
    qint64 bytesReceived{0};
    qint64 elapsedMs{0};
};

class SpeedTestRunner : public QObject {
    Q_OBJECT

public:
    explicit SpeedTestRunner(QObject *parent = nullptr);

    void start(const QUrl &streamUrl, int durationSecs = 10);
    void stop();
    bool isRunning() const;

signals:
    void progressUpdated(double currentMbps, qint64 bytesReceived, qint64 elapsedMs);
    void finished(const iptvxs::SpeedTestResult &result);
    void errorOccurred(const QString &message);

private slots:
    void onReadyRead();
    void onTimerTimeout();
    void onReplyFinished();
    void onReplyError(QNetworkReply::NetworkError code);

private:
    void cleanup();
    void startConnection(const QUrl &url);
    double calculateMbps(qint64 bytes, qint64 ms) const;

    static constexpr int kParallelConnections = 6;

    QNetworkAccessManager nam_;
    QVector<QNetworkReply *> replies_;
    QElapsedTimer elapsed_;
    QTimer timer_;
    QUrl testUrl_;
    qint64 totalBytes_{0};
    bool running_{false};
    int activeConnections_{0};
};

} // namespace iptvxs
