// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
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
#include <QTimer>

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
                Q_UNUSED(dur);
            });
    connect(player_, &iptvxs::MpvPlayer::positionChanged, this,
            [this](double) {
                if (player_->position() > 0.0) {
                    lastPosition_ = player_->position();
                }
                emit positionChanged();
                checkAutoNext();
            });
    connect(player_, &iptvxs::MpvPlayer::cacheDurationChanged, this,
            [this](double) { emit cacheDurationChanged(); });
    connect(player_, &iptvxs::MpvPlayer::cacheSpeedChanged, this,
            [this](double) { emit cacheSpeedChanged(); });
    connect(player_, &iptvxs::MpvPlayer::videoBitrateChanged, this,
            [this](double) { emit videoBitrateChanged(); });
    connect(player_, &iptvxs::MpvPlayer::videoHeightChanged, this,
            [this](int) { emit videoHeightChanged(); });
    connect(player_, &iptvxs::MpvPlayer::mediaLoaded, this, [this]() {
        if (reconnecting_) {
            reconnecting_ = false;
            emit reconnectingChanged();
        }
        if (pendingSeekSeconds_ > 0) {
            const auto seekSeconds = pendingSeekSeconds_;
            pendingSeekSeconds_ = 0;
            QTimer::singleShot(0, this, [this, seekSeconds]() {
                if (player_ && seekSeconds > 0) {
                    player_->seek(seekSeconds);
                }
            });
        }
        // mpv can populate subtitle/audio track metadata a moment after FILE_LOADED,
        // especially on slower devices and some Steam Deck paths.
        QTimer::singleShot(150, this, [this]() {
            if (!player_) return;
            refreshSubtitleTracks();
            refreshAudioTracks();
        });
    });
    connect(player_, &iptvxs::MpvPlayer::endOfFile, this, [this]() {
        if (!nextEpisodeUrl_.isEmpty()) {
            auto url = nextEpisodeUrl_;
            auto name = nextEpisodeName_;
            auto logo = nextEpisodeLogo_;
            auto chId = nextEpisodeChannelId_;
            resetAutoNext();
            play(url, name, logo, chId);
            emit autoNextTriggered();
            return;
        }

        if (isLive_ && !manualStop_ && !currentUrl_.isEmpty() && !channelName_.isEmpty()) {
            if (liveReconnectAttempts_ < kMaxLiveReconnectAttempts) {
                const int attempt = ++liveReconnectAttempts_;
                const int delayMs = qMin(5000, 750 * attempt);
                if (!reconnecting_) {
                    reconnecting_ = true;
                    emit reconnectingChanged();
                }
                qWarning("Live stream ended prematurely, reconnecting attempt %d/%d in %d ms",
                         attempt, kMaxLiveReconnectAttempts, delayMs);
                QTimer::singleShot(delayMs, this, [this]() {
                    if (manualStop_ || currentUrl_.isEmpty()) return;
                    auto url = currentUrl_;
                    auto name = channelName_;
                    auto logo = channelLogo_;
                    auto chId = channelId_;
                    auto epgId = epgChannelId_;
                    if (!url.isEmpty()) {
                        play(url, name, logo, chId, epgId,
                             lastPosition_ > 0.0 ? static_cast<int>(lastPosition_) : 0,
                             false);
                    }
                });
                return;
            }
            emit liveReconnectFailed(QStringLiteral("Live stream reconnect failed after %1 attempts").arg(kMaxLiveReconnectAttempts));
        }
    });
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

double PlayerViewModel::cacheDuration() const { return player_->cacheDuration(); }

double PlayerViewModel::cacheSpeed() const { return player_->cacheSpeed(); }

double PlayerViewModel::videoBitrate() const { return player_->videoBitrate(); }

int PlayerViewModel::videoHeight() const { return player_->videoHeight(); }

double PlayerViewModel::lastPosition() const { return lastPosition_; }

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
                           const QString &logo, int64_t channelId,
                           const QString &epgChannelId,
                           int startPositionSecs,
                           bool resetReconnectAttempts,
                           bool forceLive) {
    // Idempotent: if the same URL is already loaded and playing, do not reload.
    // Reloading would issue `loadfile` in mpv, which resets file-local
    // properties including `stream-record` — stopping any active recording.
    const bool sameUrl = (url == currentUrl_) && !url.isEmpty();
    const bool alreadyActive =
        sameUrl && (player_->state() == iptvxs::MpvPlayer::State::Playing ||
                    player_->state() == iptvxs::MpvPlayer::State::Paused ||
                    player_->state() == iptvxs::MpvPlayer::State::Loading);
    if (alreadyActive) {
        if (reconnecting_) {
            reconnecting_ = false;
            emit reconnectingChanged();
        }
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
        if (startPositionSecs > 0) {
            player_->seek(startPositionSecs);
            lastPosition_ = startPositionSecs;
            pendingSeekSeconds_ = 0;
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

    // Reset auto-next and stretch when switching streams
    resetAutoNext();
    nextEpisodeUrl_.clear();
    nextEpisodeName_.clear();
    nextEpisodeLogo_.clear();
    nextEpisodeChannelId_ = 0;
    emit nextEpisodeNameChanged();
    if (stretched_) {
        stretched_ = false;
        player_->setProperty(QStringLiteral("video-aspect-override"),
                             QVariant(QStringLiteral("-1")));
        emit stretchedChanged();
    }

    currentUrl_ = url;
    channelName_ = name;
    channelLogo_ = logo;
    channelId_ = channelId;
    if (epgChannelId_ != epgChannelId) {
        epgChannelId_ = epgChannelId;
        emit epgChannelIdChanged();
    }
    manualStop_ = false;
    isLive_ = forceLive;
    // Detect Xtream Codes catchup/timeshift URLs so the UI can keep the rewind
    // controls visible while in catchup mode (and remain accessible when the
    // catchup URL is later replayed from history with isLive=false).
    const bool wasCatchup = isCatchup_;
    isCatchup_ = url.contains(QStringLiteral("/streaming/timeshift.php"));
    subtitleTracks_.clear();
    audioTracks_.clear();
    emit channelNameChanged();
    emit channelLogoChanged();
    emit channelIdChanged();
    emit isLiveChanged();
    if (wasCatchup != isCatchup_) emit isCatchupChanged();
    emit subtitleTracksChanged();
    emit audioTracksChanged();

    lastPosition_ = startPositionSecs > 0 ? startPositionSecs : 0.0;
    if (resetReconnectAttempts) {
        liveReconnectAttempts_ = 0;
    }
    pendingSeekSeconds_ = startPositionSecs > 0 ? startPositionSecs : 0;
    if (isLive_) {
        player_->setProperty(QStringLiteral("sid"), QVariant(QStringLiteral("no")));
        player_->setProperty(QStringLiteral("secondary-sid"), QVariant(QStringLiteral("no")));
        player_->setProperty(QStringLiteral("sub-visibility"), QVariant(false));
    }

    inhibitScreenSaver();
    player_->play(url);
}

void PlayerViewModel::togglePause() { player_->togglePause(); }

void PlayerViewModel::stop() {
    if (recording_) {
        stopStreamRecord();
    }
    resetAutoNext();
    if (!nextEpisodeUrl_.isEmpty() || !nextEpisodeName_.isEmpty() ||
        !nextEpisodeLogo_.isEmpty() || nextEpisodeChannelId_ != 0) {
        nextEpisodeUrl_.clear();
        nextEpisodeName_.clear();
        nextEpisodeLogo_.clear();
        nextEpisodeChannelId_ = 0;
        emit nextEpisodeNameChanged();
    }
    uninhibitScreenSaver();
    manualStop_ = true;
    pendingSeekSeconds_ = 0;
    liveReconnectAttempts_ = 0;
    if (reconnecting_) {
        reconnecting_ = false;
        emit reconnectingChanged();
    }
    player_->stop();
    channelName_.clear();
    channelLogo_.clear();
    channelId_ = 0;
    if (!epgChannelId_.isEmpty()) {
        epgChannelId_.clear();
        emit epgChannelIdChanged();
    }
    if (isCatchup_) {
        isCatchup_ = false;
        emit isCatchupChanged();
    }
    emit channelNameChanged();
    emit channelLogoChanged();
    emit channelIdChanged();
}

bool PlayerViewModel::reconnecting() const { return reconnecting_; }

void PlayerViewModel::setReconnecting(bool reconnecting) {
    if (reconnecting_ == reconnecting) return;
    reconnecting_ = reconnecting;
    emit reconnectingChanged();
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
    player_->setProperty(QStringLiteral("sub-visibility"), QVariant(true));
    QTimer::singleShot(150, this, [this]() {
        if (player_) refreshSubtitleTracks();
    });
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
bool PlayerViewModel::isCatchup() const { return isCatchup_; }

QVariantList PlayerViewModel::subtitleTracks() const { return subtitleTracks_; }

void PlayerViewModel::refreshSubtitleTracks() {
    subtitleTracks_.clear();

    auto primarySid = player_->getProperty(QStringLiteral("sid")).toInt();
    auto trackCount = player_->getProperty(QStringLiteral("track-list/count")).toInt();
    for (int i = 0; i < trackCount; ++i) {
        auto prefix = QStringLiteral("track-list/%1/").arg(i);
        auto type = player_->getProperty(prefix + QStringLiteral("type")).toString();
        if (type != QStringLiteral("sub")) continue;

        auto trackId = player_->getProperty(prefix + QStringLiteral("id")).toInt();
        QVariantMap track;
        track[QStringLiteral("id")] = trackId;
        track[QStringLiteral("title")] = player_->getProperty(prefix + QStringLiteral("title")).toString();
        track[QStringLiteral("lang")] = player_->getProperty(prefix + QStringLiteral("lang")).toString();
        track[QStringLiteral("selected")] = (trackId == primarySid);
        track[QStringLiteral("external")] = player_->getProperty(prefix + QStringLiteral("external")).toBool();
        subtitleTracks_.append(track);
    }

    emit subtitleTracksChanged();
}

void PlayerViewModel::selectSubtitleTrack(int trackId) {
    player_->setProperty(QStringLiteral("sid"), QVariant(trackId));
    player_->setProperty(QStringLiteral("sub-visibility"), QVariant(true));
    QTimer::singleShot(0, this, [this]() {
        if (player_) refreshSubtitleTracks();
    });
}

QVariantList PlayerViewModel::audioTracks() const { return audioTracks_; }

void PlayerViewModel::refreshAudioTracks() {
    audioTracks_.clear();

    auto primaryAid = player_->getProperty(QStringLiteral("aid")).toInt();
    auto trackCount = player_->getProperty(QStringLiteral("track-list/count")).toInt();
    for (int i = 0; i < trackCount; ++i) {
        auto prefix = QStringLiteral("track-list/%1/").arg(i);
        auto type = player_->getProperty(prefix + QStringLiteral("type")).toString();
        if (type != QStringLiteral("audio")) continue;

        auto trackId = player_->getProperty(prefix + QStringLiteral("id")).toInt();
        QVariantMap track;
        track[QStringLiteral("id")] = trackId;
        track[QStringLiteral("title")] = player_->getProperty(prefix + QStringLiteral("title")).toString();
        track[QStringLiteral("lang")] = player_->getProperty(prefix + QStringLiteral("lang")).toString();
        track[QStringLiteral("selected")] = (trackId == primaryAid);
        audioTracks_.append(track);
    }

    emit audioTracksChanged();
}

void PlayerViewModel::selectAudioTrack(int trackId) {
    player_->setProperty(QStringLiteral("aid"), QVariant(trackId));
    refreshAudioTracks();
}

bool PlayerViewModel::stretched() const { return stretched_; }

void PlayerViewModel::toggleStretch() {
    stretched_ = !stretched_;
    if (stretched_) {
        player_->setProperty(QStringLiteral("video-aspect-override"),
                             QVariant(QStringLiteral("16:9")));
    } else {
        player_->setProperty(QStringLiteral("video-aspect-override"),
                             QVariant(QStringLiteral("-1")));
    }
    emit stretchedChanged();
}

bool PlayerViewModel::autoNextEnabled() const { return autoNextEnabled_; }

int PlayerViewModel::autoNextCountdown() const { return autoNextCountdown_; }

QString PlayerViewModel::nextEpisodeName() const { return nextEpisodeName_; }

void PlayerViewModel::setNextEpisode(const QString &url, const QString &name,
                                      const QString &logo, int64_t channelId) {
    nextEpisodeUrl_ = url;
    nextEpisodeLogo_ = logo;
    nextEpisodeChannelId_ = channelId;
    if (nextEpisodeName_ != name) {
        nextEpisodeName_ = name;
        emit nextEpisodeNameChanged();
    }
}

void PlayerViewModel::cancelAutoNext() {
    resetAutoNext();
}

void PlayerViewModel::checkAutoNext() {
    if (nextEpisodeUrl_.isEmpty()) return;
    auto dur = player_->duration();
    auto pos = player_->position();
    if (dur <= 0.0 || pos <= 0.0) return;

    auto remaining = dur - pos;
    if (remaining <= 15.0 && remaining > 0.0 && !autoNextEnabled_) {
        // Start the countdown
        autoNextEnabled_ = true;
        autoNextCountdown_ = static_cast<int>(remaining);
        emit autoNextEnabledChanged();
        emit autoNextCountdownChanged();

        if (!autoNextTimer_) {
            autoNextTimer_ = new QTimer(this);
            autoNextTimer_->setInterval(1000);
            connect(autoNextTimer_, &QTimer::timeout, this, [this]() {
                if (autoNextCountdown_ > 0) {
                    --autoNextCountdown_;
                    emit autoNextCountdownChanged();
                }
                if (autoNextCountdown_ <= 0) {
                    autoNextTimer_->stop();
                    // Play next episode
                    auto url = nextEpisodeUrl_;
                    auto name = nextEpisodeName_;
                    auto logo = nextEpisodeLogo_;
                    auto chId = nextEpisodeChannelId_;
                    resetAutoNext();
                    play(url, name, logo, chId);
                    emit autoNextTriggered();
                }
            });
        }
        autoNextTimer_->start();
    }
}

QString PlayerViewModel::epgChannelId() const { return epgChannelId_; }

void PlayerViewModel::setEpgChannelId(const QString &id) {
    if (epgChannelId_ != id) {
        epgChannelId_ = id;
        emit epgChannelIdChanged();
    }
}

void PlayerViewModel::resetAutoNext() {
    if (autoNextTimer_) {
        autoNextTimer_->stop();
    }
    if (autoNextEnabled_) {
        autoNextEnabled_ = false;
        autoNextCountdown_ = 0;
        emit autoNextEnabledChanged();
        emit autoNextCountdownChanged();
    }
}
