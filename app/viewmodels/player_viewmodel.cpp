#include "player_viewmodel.h"

#ifdef Q_OS_LINUX
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#elif defined(Q_OS_WIN)
#include <windows.h>
#endif
#include <QDateTime>
#include <QDir>
#include <QFileInfo>

PlayerViewModel::PlayerViewModel(QObject *parent)
    : QObject(parent), player_(new iptvxs::MpvPlayer(this)) {
    player_->initialize();

    connect(player_, &iptvxs::MpvPlayer::stateChanged, this,
            &PlayerViewModel::stateChanged);
    connect(player_, &iptvxs::MpvPlayer::volumeChanged, this,
            [this](int) { emit volumeChanged(); });
    connect(player_, &iptvxs::MpvPlayer::mutedChanged, this,
            [this](bool) { emit mutedChanged(); });
    connect(player_, &iptvxs::MpvPlayer::durationChanged, this,
            [this](double dur) {
                emit durationChanged();
                if (dur <= 0.0 && !isLive_) {
                    isLive_ = true;
                    emit isLiveChanged();
                }
            });
    connect(player_, &iptvxs::MpvPlayer::positionChanged, this,
            [this](double) { emit positionChanged(); });
    connect(player_, &iptvxs::MpvPlayer::errorOccurred, this,
            &PlayerViewModel::errorOccurred);
}

PlayerViewModel::~PlayerViewModel() = default;

bool PlayerViewModel::playing() const {
    return player_->state() == iptvxs::MpvPlayer::State::Playing;
}

bool PlayerViewModel::paused() const {
    return player_->state() == iptvxs::MpvPlayer::State::Paused;
}

bool PlayerViewModel::stopped() const {
    return player_->state() == iptvxs::MpvPlayer::State::Stopped;
}

bool PlayerViewModel::loading() const {
    return player_->state() == iptvxs::MpvPlayer::State::Loading;
}

int64_t PlayerViewModel::channelId() const { return channelId_; }

int PlayerViewModel::volume() const { return player_->volume(); }

void PlayerViewModel::setVolume(int vol) { player_->setVolume(vol); }

bool PlayerViewModel::muted() const { return player_->muted(); }

void PlayerViewModel::setMuted(bool m) { player_->setMuted(m); }

double PlayerViewModel::duration() const { return player_->duration(); }

double PlayerViewModel::position() const { return player_->position(); }

QString PlayerViewModel::channelName() const { return channelName_; }

QString PlayerViewModel::channelLogo() const { return channelLogo_; }

iptvxs::MpvPlayer *PlayerViewModel::mpvPlayer() const { return player_; }
QString PlayerViewModel::currentUrl() const { return currentUrl_; }

void PlayerViewModel::inhibitScreenSaver() {
#ifdef Q_OS_LINUX
    if (screenSaverCookie_ != 0) return;
    QDBusInterface iface(QStringLiteral("org.freedesktop.ScreenSaver"),
                         QStringLiteral("/org/freedesktop/ScreenSaver"),
                         QStringLiteral("org.freedesktop.ScreenSaver"),
                         QDBusConnection::sessionBus());
    if (iface.isValid()) {
        QDBusReply<uint32_t> reply = iface.call(QStringLiteral("Inhibit"),
                                                 QStringLiteral("iptvXS"),
                                                 QStringLiteral("Video playback"));
        if (reply.isValid()) {
            screenSaverCookie_ = reply.value();
        }
    }
#elif defined(Q_OS_WIN)
    SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED | ES_SYSTEM_REQUIRED);
#endif
}

void PlayerViewModel::uninhibitScreenSaver() {
#ifdef Q_OS_LINUX
    if (screenSaverCookie_ == 0) return;
    QDBusInterface iface(QStringLiteral("org.freedesktop.ScreenSaver"),
                         QStringLiteral("/org/freedesktop/ScreenSaver"),
                         QStringLiteral("org.freedesktop.ScreenSaver"),
                         QDBusConnection::sessionBus());
    if (iface.isValid()) {
        iface.call(QStringLiteral("UnInhibit"), screenSaverCookie_);
    }
    screenSaverCookie_ = 0;
#elif defined(Q_OS_WIN)
    SetThreadExecutionState(ES_CONTINUOUS);
#endif
}

void PlayerViewModel::play(const QString &url, const QString &name,
                           const QString &logo, int64_t channelId) {
    // Idempotent: if the same URL is already loaded and playing, do not reload.
    // Reloading would issue `loadfile` in mpv, which resets file-local
    // properties including `stream-record` — stopping any active recording.
    const bool sameUrl = (url == currentUrl_) && !url.isEmpty();
    const bool alreadyActive =
        sameUrl && (player_->state() == iptvxs::MpvPlayer::State::Playing ||
                    player_->state() == iptvxs::MpvPlayer::State::Paused ||
                    player_->state() == iptvxs::MpvPlayer::State::Loading);
    if (alreadyActive) {
        // Metadata may still need refreshing (e.g. logo) but skip the reload.
        if (channelName_ != name) {
            channelName_ = name;
            emit channelNameChanged();
        }
        if (channelLogo_ != logo) {
            channelLogo_ = logo;
            emit channelLogoChanged();
        }
        if (channelId_ != channelId) {
            channelId_ = channelId;
            emit channelIdChanged();
        }
        qInfo("PlayerViewModel::play skipped reload — same URL already active "
              "(recording=%s)", recording_ ? "on" : "off");
        return;
    }

    // Switching streams drops any active recording; mpv's loadfile wipes
    // stream-record anyway, so reflect that in our state.
    if (recording_) {
        recording_ = false;
        recordingPath_.clear();
        recordingStartTime_ = 0;
        emit recordingChanged();
    }

    currentUrl_ = url;
    channelName_ = name;
    channelLogo_ = logo;
    channelId_ = channelId;
    isLive_ = url.contains(QStringLiteral("/live/"))
              || url.endsWith(QStringLiteral(".ts"))
              || url.endsWith(QStringLiteral(".m3u8"));
    subtitleTracks_.clear();
    audioTracks_.clear();
    emit channelNameChanged();
    emit channelLogoChanged();
    emit channelIdChanged();
    emit isLiveChanged();
    emit subtitleTracksChanged();
    emit audioTracksChanged();

    inhibitScreenSaver();
    player_->play(url);
}

void PlayerViewModel::togglePause() { player_->togglePause(); }

void PlayerViewModel::stop() {
    if (recording_) {
        stopStreamRecord();
    }
    uninhibitScreenSaver();
    player_->stop();
    channelName_.clear();
    channelLogo_.clear();
    channelId_ = 0;
    emit channelNameChanged();
    emit channelLogoChanged();
    emit channelIdChanged();
}

void PlayerViewModel::seek(double seconds) { player_->seek(seconds); }

void PlayerViewModel::volumeUp() {
    player_->setVolume(qMin(player_->volume() + 5, 100));
}

void PlayerViewModel::volumeDown() {
    player_->setVolume(qMax(player_->volume() - 5, 0));
}

void PlayerViewModel::toggleMute() { player_->setMuted(!player_->muted()); }

void PlayerViewModel::startStreamRecord(const QString &filePath) {
    QDir().mkpath(QFileInfo(filePath).absolutePath());
    player_->setProperty(QStringLiteral("stream-record"), QVariant(filePath));
    recording_ = true;
    recordingPath_ = filePath;
    recordingStartTime_ =
        static_cast<qint64>(QDateTime::currentSecsSinceEpoch());
    emit recordingChanged();
}

void PlayerViewModel::stopStreamRecord() {
    player_->setProperty(QStringLiteral("stream-record"), QVariant(QString()));
    if (recording_) {
        auto path = recordingPath_;
        auto startTime = recordingStartTime_;
        recording_ = false;
        recordingPath_.clear();
        recordingStartTime_ = 0;
        emit recordingChanged();
        emit streamRecordingStopped(path, startTime);
    }
}

bool PlayerViewModel::recording() const { return recording_; }
QString PlayerViewModel::recordingPath() const { return recordingPath_; }
qint64 PlayerViewModel::recordingStartTime() const { return recordingStartTime_; }

void PlayerViewModel::loadSubtitleFile(const QString &filePath) {
    player_->command({QStringLiteral("sub-add"), filePath, QStringLiteral("select")});
}

void PlayerViewModel::setSubtitleDelay(double seconds) {
    player_->setProperty(QStringLiteral("sub-delay"), QVariant(seconds));
}

double PlayerViewModel::subtitleDelay() const {
    auto val = player_->getProperty(QStringLiteral("sub-delay"));
    return val.toDouble();
}

void PlayerViewModel::setSubtitleVisibility(bool visible) {
    player_->setProperty(QStringLiteral("sub-visibility"), QVariant(visible));
}

bool PlayerViewModel::subtitleVisible() const {
    auto val = player_->getProperty(QStringLiteral("sub-visibility"));
    return val.toBool();
}

void PlayerViewModel::adjustSubtitleDelay(double deltaSecs) {
    auto current = subtitleDelay();
    setSubtitleDelay(current + deltaSecs);
}

void PlayerViewModel::setBufferSeconds(int seconds) {
    player_->setProperty(QStringLiteral("cache-secs"),
                         QVariant(qMax(0, seconds)));
    player_->setProperty(QStringLiteral("demuxer-readahead-secs"),
                         QVariant(qMax(0, seconds)));
}

QString PlayerViewModel::formatTime(double seconds) const {
    if (seconds < 0) return QStringLiteral("--:--");
    auto totalSecs = static_cast<int>(seconds);
    auto h = totalSecs / 3600;
    auto m = (totalSecs % 3600) / 60;
    auto s = totalSecs % 60;
    if (h > 0) {
        return QStringLiteral("%1:%2:%3")
            .arg(h)
            .arg(m, 2, 10, QLatin1Char('0'))
            .arg(s, 2, 10, QLatin1Char('0'));
    }
    return QStringLiteral("%1:%2")
        .arg(m, 2, 10, QLatin1Char('0'))
        .arg(s, 2, 10, QLatin1Char('0'));
}

bool PlayerViewModel::isLive() const { return isLive_; }

QVariantList PlayerViewModel::subtitleTracks() const { return subtitleTracks_; }

void PlayerViewModel::refreshSubtitleTracks() {
    subtitleTracks_.clear();

    auto trackCount = player_->getProperty(QStringLiteral("track-list/count")).toInt();
    for (int i = 0; i < trackCount; ++i) {
        auto prefix = QStringLiteral("track-list/%1/").arg(i);
        auto type = player_->getProperty(prefix + QStringLiteral("type")).toString();
        if (type != QStringLiteral("sub")) continue;

        QVariantMap track;
        track[QStringLiteral("id")] = player_->getProperty(prefix + QStringLiteral("id")).toInt();
        track[QStringLiteral("title")] = player_->getProperty(prefix + QStringLiteral("title")).toString();
        track[QStringLiteral("lang")] = player_->getProperty(prefix + QStringLiteral("lang")).toString();
        track[QStringLiteral("selected")] = player_->getProperty(prefix + QStringLiteral("selected")).toBool();
        track[QStringLiteral("external")] = player_->getProperty(prefix + QStringLiteral("external")).toBool();
        subtitleTracks_.append(track);
    }

    emit subtitleTracksChanged();
}

void PlayerViewModel::selectSubtitleTrack(int trackId) {
    player_->setProperty(QStringLiteral("sid"), QVariant(trackId));
    player_->setProperty(QStringLiteral("sub-visibility"), QVariant(true));
    refreshSubtitleTracks();
}

QVariantList PlayerViewModel::audioTracks() const { return audioTracks_; }

void PlayerViewModel::refreshAudioTracks() {
    audioTracks_.clear();

    auto trackCount = player_->getProperty(QStringLiteral("track-list/count")).toInt();
    for (int i = 0; i < trackCount; ++i) {
        auto prefix = QStringLiteral("track-list/%1/").arg(i);
        auto type = player_->getProperty(prefix + QStringLiteral("type")).toString();
        if (type != QStringLiteral("audio")) continue;

        QVariantMap track;
        track[QStringLiteral("id")] = player_->getProperty(prefix + QStringLiteral("id")).toInt();
        track[QStringLiteral("title")] = player_->getProperty(prefix + QStringLiteral("title")).toString();
        track[QStringLiteral("lang")] = player_->getProperty(prefix + QStringLiteral("lang")).toString();
        track[QStringLiteral("selected")] = player_->getProperty(prefix + QStringLiteral("selected")).toBool();
        audioTracks_.append(track);
    }

    emit audioTracksChanged();
}

void PlayerViewModel::selectAudioTrack(int trackId) {
    player_->setProperty(QStringLiteral("aid"), QVariant(trackId));
    refreshAudioTracks();
}
