#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>

#include "iptvxs/player/mpv_player.h"

class PlayerViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool playing READ playing NOTIFY stateChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY stateChanged)
    Q_PROPERTY(bool stopped READ stopped NOTIFY stateChanged)
    Q_PROPERTY(int volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY mutedChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(QString channelName READ channelName NOTIFY channelNameChanged)
    Q_PROPERTY(QString channelLogo READ channelLogo NOTIFY channelLogoChanged)
    Q_PROPERTY(iptvxs::MpvPlayer *mpvPlayer READ mpvPlayer CONSTANT)

public:
    explicit PlayerViewModel(QObject *parent = nullptr);
    ~PlayerViewModel() override;

    bool playing() const;
    bool paused() const;
    bool stopped() const;
    int volume() const;
    void setVolume(int vol);
    bool muted() const;
    void setMuted(bool m);
    double duration() const;
    double position() const;
    QString channelName() const;
    QString channelLogo() const;
    iptvxs::MpvPlayer *mpvPlayer() const;

    Q_INVOKABLE void play(const QString &url, const QString &name = {},
                          const QString &logo = {});
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void volumeUp();
    Q_INVOKABLE void volumeDown();
    Q_INVOKABLE void toggleMute();

    Q_INVOKABLE QString formatTime(double seconds) const;

signals:
    void stateChanged();
    void volumeChanged();
    void mutedChanged();
    void durationChanged();
    void positionChanged();
    void channelNameChanged();
    void channelLogoChanged();
    void errorOccurred(const QString &message);

private:
    iptvxs::MpvPlayer *player_;
    QString channelName_;
    QString channelLogo_;
};
