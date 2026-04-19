#include "player_viewmodel.h"

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
            [this](double) { emit durationChanged(); });
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

void PlayerViewModel::play(const QString &url, const QString &name,
                           const QString &logo, int64_t channelId) {
    channelName_ = name;
    channelLogo_ = logo;
    channelId_ = channelId;
    emit channelNameChanged();
    emit channelLogoChanged();
    emit channelIdChanged();

    player_->play(url);
}

void PlayerViewModel::togglePause() { player_->togglePause(); }

void PlayerViewModel::stop() {
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
    player_->setProperty(QStringLiteral("stream-record"), QVariant(filePath));
}

void PlayerViewModel::stopStreamRecord() {
    player_->setProperty(QStringLiteral("stream-record"), QVariant(QString()));
}

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
