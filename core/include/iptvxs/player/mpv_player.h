// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariant>

struct mpv_handle;

namespace iptvxs {

class MpvPlayer : public QObject {
    Q_OBJECT

public:
    enum class State { Stopped, Loading, Playing, Paused };
    Q_ENUM(State)

    explicit MpvPlayer(QObject *parent = nullptr);
    ~MpvPlayer() override;

    MpvPlayer(const MpvPlayer &) = delete;
    MpvPlayer &operator=(const MpvPlayer &) = delete;

    bool initialize();

    void play(const QString &url);
    void setHttpHeaders(const QStringList &headers);
    void clearHttpHeaders();
    void pause();
    void resume();
    void stop();
    void togglePause();

    void setVolume(int volume);
    int volume() const;
    void setMuted(bool muted);
    bool muted() const;

    State state() const;
    double duration() const;
    double position() const;
    double cacheDuration() const;
    double cacheSpeed() const;
    double videoBitrate() const;
    int videoHeight() const;
    void seek(double seconds);

    mpv_handle *handle() const;

    void command(const QStringList &args);
    void setProperty(const QString &name, const QVariant &value);
    int setOptionString(const QString &name, const QString &value);
    QVariant getProperty(const QString &name) const;

signals:
    void stateChanged(iptvxs::MpvPlayer::State state);
    void volumeChanged(int volume);
    void mutedChanged(bool muted);
    void durationChanged(double duration);
    void positionChanged(double position);
    void cacheDurationChanged(double cacheDuration);
    void cacheSpeedChanged(double cacheSpeed);
    void videoBitrateChanged(double videoBitrate);
    void videoHeightChanged(int videoHeight);
    void mediaLoaded();
    void endOfFile();
    void errorOccurred(const QString &message);

private slots:
    void processEvents();

private:
    void handlePropertyChange(const QString &name, const QVariant &value);

    mpv_handle *mpv_{nullptr};
    State state_{State::Stopped};
    int volume_{100};
    bool muted_{false};
    double duration_{0.0};
    double position_{0.0};
    double cacheDuration_{0.0};
    double cacheSpeed_{0.0};
    double videoBitrate_{0.0};
    int videoHeight_{0};
};

} // namespace iptvxs
