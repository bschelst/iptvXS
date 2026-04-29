// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QTimer>

#include "iptvxs/player/mpv_player.h"

class PlayerViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool playing READ playing NOTIFY stateChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY stateChanged)
    Q_PROPERTY(bool stopped READ stopped NOTIFY stateChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY stateChanged)
    Q_PROPERTY(int64_t channelId READ channelId NOTIFY channelIdChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double cacheDuration READ cacheDuration NOTIFY cacheDurationChanged)
    Q_PROPERTY(QString channelName READ channelName NOTIFY channelNameChanged)
    Q_PROPERTY(QString channelLogo READ channelLogo NOTIFY channelLogoChanged)
    Q_PROPERTY(iptvxs::MpvPlayer *mpvPlayer READ mpvPlayer CONSTANT)
    Q_PROPERTY(bool isLive READ isLive NOTIFY isLiveChanged)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY subtitleTracksChanged)
    Q_PROPERTY(QVariantList audioTracks READ audioTracks NOTIFY audioTracksChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(QString recordingPath READ recordingPath NOTIFY recordingChanged)
    Q_PROPERTY(qint64 recordingStartTime READ recordingStartTime NOTIFY recordingChanged)
    Q_PROPERTY(bool stretched READ stretched NOTIFY stretchedChanged)
    Q_PROPERTY(bool autoNextEnabled READ autoNextEnabled NOTIFY autoNextEnabledChanged)
    Q_PROPERTY(int autoNextCountdown READ autoNextCountdown NOTIFY autoNextCountdownChanged)
    Q_PROPERTY(QString nextEpisodeName READ nextEpisodeName NOTIFY nextEpisodeNameChanged)
    Q_PROPERTY(QString epgChannelId READ epgChannelId NOTIFY epgChannelIdChanged)

public:
    explicit PlayerViewModel(QObject *parent = nullptr);
    ~PlayerViewModel() override;

    bool playing() const;
    bool paused() const;
    bool stopped() const;
    bool loading() const;
    int64_t channelId() const;
    int volume() const;
    void setVolume(int vol);
    bool muted() const;
    void setMuted(bool m);
    double duration() const;
    double position() const;
    double cacheDuration() const;
    QString channelName() const;
    QString channelLogo() const;
    iptvxs::MpvPlayer *mpvPlayer() const;
    Q_INVOKABLE QString currentUrl() const;

    Q_INVOKABLE void play(const QString &url, const QString &name = {},
                          const QString &logo = {}, int64_t channelId = 0,
                          const QString &epgChannelId = {});
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void volumeUp();
    Q_INVOKABLE void volumeDown();
    Q_INVOKABLE void toggleMute();
    Q_INVOKABLE void setBufferSeconds(int seconds);
    Q_INVOKABLE void startStreamRecord(const QString &filePath);
    Q_INVOKABLE void stopStreamRecord();

    Q_INVOKABLE void loadSubtitleFile(const QString &filePath);
    Q_INVOKABLE void setSubtitleDelay(double seconds);
    Q_INVOKABLE double subtitleDelay() const;
    Q_INVOKABLE void setSubtitleVisibility(bool visible);
    Q_INVOKABLE bool subtitleVisible() const;
    Q_INVOKABLE void adjustSubtitleDelay(double deltaSecs);
    Q_INVOKABLE void selectSubtitleTrack(int trackId);
    Q_INVOKABLE void refreshSubtitleTracks();
    Q_INVOKABLE void selectAudioTrack(int trackId);
    Q_INVOKABLE void refreshAudioTracks();
    Q_INVOKABLE void toggleStretch();
    Q_INVOKABLE void cancelAutoNext();
    Q_INVOKABLE void setNextEpisode(const QString &url, const QString &name,
                                     const QString &logo, int64_t channelId);

    bool isLive() const;
    QVariantList subtitleTracks() const;
    QVariantList audioTracks() const;
    bool recording() const;
    QString recordingPath() const;
    qint64 recordingStartTime() const;
    bool stretched() const;
    bool autoNextEnabled() const;
    int autoNextCountdown() const;
    QString nextEpisodeName() const;
    QString epgChannelId() const;
    void setEpgChannelId(const QString &id);

    Q_INVOKABLE QString formatTime(double seconds) const;

signals:
    void stateChanged();
    void volumeChanged();
    void mutedChanged();
    void durationChanged();
    void positionChanged();
    void cacheDurationChanged();
    void channelNameChanged();
    void channelLogoChanged();
    void channelIdChanged();
    void isLiveChanged();
    void subtitleTracksChanged();
    void audioTracksChanged();
    void recordingChanged();
    void streamRecordingStopped(const QString &filePath, qint64 startTime);
    void errorOccurred(const QString &message);
    void stretchedChanged();
    void autoNextEnabledChanged();
    void autoNextCountdownChanged();
    void nextEpisodeNameChanged();
    void autoNextTriggered();
    void epgChannelIdChanged();

private:
    iptvxs::MpvPlayer *player_;
    QString currentUrl_;
    QString channelName_;
    QString channelLogo_;
    int64_t channelId_{0};
    QString epgChannelId_;
    bool isLive_{false};
    QVariantList subtitleTracks_;
    QVariantList audioTracks_;
    bool recording_{false};
    QString recordingPath_;
    qint64 recordingStartTime_{0};
    uint32_t screenSaverCookie_{0};
    bool stretched_{false};

    // Auto-next episode
    QString nextEpisodeUrl_;
    QString nextEpisodeName_;
    QString nextEpisodeLogo_;
    int64_t nextEpisodeChannelId_{0};
    bool autoNextEnabled_{false};
    int autoNextCountdown_{0};
    QTimer *autoNextTimer_{nullptr};
    void checkAutoNext();
    void resetAutoNext();

    void inhibitScreenSaver();
    void uninhibitScreenSaver();
};
