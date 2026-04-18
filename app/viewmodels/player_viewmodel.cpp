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
                           const QString &logo) {
    channelName_ = name;
    channelLogo_ = logo;
    emit channelNameChanged();
    emit channelLogoChanged();

    player_->play(QUrl(url));
}

void PlayerViewModel::togglePause() { player_->togglePause(); }

void PlayerViewModel::stop() {
    player_->stop();
    channelName_.clear();
    channelLogo_.clear();
    emit channelNameChanged();
    emit channelLogoChanged();
}

void PlayerViewModel::seek(double seconds) { player_->seek(seconds); }

void PlayerViewModel::volumeUp() {
    player_->setVolume(qMin(player_->volume() + 5, 100));
}

void PlayerViewModel::volumeDown() {
    player_->setVolume(qMax(player_->volume() - 5, 0));
}

void PlayerViewModel::toggleMute() { player_->setMuted(!player_->muted()); }

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
