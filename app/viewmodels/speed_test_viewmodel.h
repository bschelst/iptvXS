// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>

#include "iptvxs/net/speed_test_runner.h"
#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/favorite_repository.h"
#include "iptvxs/db/history_repository.h"

class SpeedTestViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(double currentMbps READ currentMbps NOTIFY currentMbpsChanged)
    Q_PROPERTY(double resultMbps READ resultMbps NOTIFY resultMbpsChanged)
    Q_PROPERTY(QString bytesReceived READ bytesReceived NOTIFY bytesReceivedChanged)
    Q_PROPERTY(QString elapsed READ elapsed NOTIFY elapsedChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(bool hasResult READ hasResult NOTIFY hasResultChanged)
    Q_PROPERTY(int duration READ duration WRITE setDuration NOTIFY durationChanged)

public:
    explicit SpeedTestViewModel(QObject *parent = nullptr);

    void setRunner(iptvxs::SpeedTestRunner *runner);
    void setChannelRepository(iptvxs::ChannelRepository *repo);

    bool running() const;
    double currentMbps() const;
    double resultMbps() const;
    QString bytesReceived() const;
    QString elapsed() const;
    QString errorMessage() const;
    bool hasResult() const;
    int duration() const;
    void setDuration(int secs);

    Q_INVOKABLE void startTest(const QString &streamUrl);
    Q_INVOKABLE void startTestForChannel(qint64 channelId);
    Q_INVOKABLE void startInternetTest();
    Q_INVOKABLE void stopTest();
    Q_INVOKABLE QVariantList quickTestChannels(int serverId);

    void setFavoriteRepository(iptvxs::FavoriteRepository *repo);
    void setHistoryRepository(iptvxs::HistoryRepository *repo);

signals:
    void runningChanged();
    void currentMbpsChanged();
    void resultMbpsChanged();
    void bytesReceivedChanged();
    void elapsedChanged();
    void errorMessageChanged();
    void hasResultChanged();
    void durationChanged();

private:
    static QString formatBytes(qint64 bytes);
    void startTestInternal(const QString &streamUrl, bool internetTest);
    void startInternetTestAttempt();
    bool shouldRetryInternetError(const QString &message) const;

    iptvxs::SpeedTestRunner *runner_{nullptr};
    iptvxs::ChannelRepository *channelRepo_{nullptr};
    iptvxs::FavoriteRepository *favoriteRepo_{nullptr};
    iptvxs::HistoryRepository *historyRepo_{nullptr};

    bool running_{false};
    double currentMbps_{0.0};
    double resultMbps_{0.0};
    qint64 bytesReceived_{0};
    qint64 elapsedMs_{0};
    QString errorMessage_;
    bool hasResult_{false};
    int duration_{60};
    QStringList internetTestUrls_;
    int internetTestIndex_{0};
    bool internetTestActive_{false};
};
