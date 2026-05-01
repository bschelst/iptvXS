// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "speed_test_viewmodel.h"

#include <QRandomGenerator>
#include <QTimer>
#include <algorithm>
#include <numeric>

SpeedTestViewModel::SpeedTestViewModel(QObject *parent)
    : QObject(parent) {}

void SpeedTestViewModel::setRunner(iptvxs::SpeedTestRunner *runner) {
    runner_ = runner;

    connect(runner_, &iptvxs::SpeedTestRunner::progressUpdated, this,
            [this](double mbps, qint64 bytes, qint64 ms) {
                currentMbps_ = mbps;
                bytesReceived_ = bytes;
                elapsedMs_ = ms;
                emit currentMbpsChanged();
                emit bytesReceivedChanged();
                emit elapsedChanged();
            });

    connect(runner_, &iptvxs::SpeedTestRunner::finished, this,
            [this](const iptvxs::SpeedTestResult &result) {
                resultMbps_ = result.downloadMbps;
                bytesReceived_ = result.bytesReceived;
                elapsedMs_ = result.elapsedMs;
                running_ = false;
                internetTestActive_ = false;
                hasResult_ = true;
                emit resultMbpsChanged();
                emit bytesReceivedChanged();
                emit elapsedChanged();
                emit runningChanged();
                emit hasResultChanged();
            });

    connect(runner_, &iptvxs::SpeedTestRunner::errorOccurred, this,
            [this](const QString &msg) {
                if (internetTestActive_ && internetTestIndex_ + 1 < internetTestUrls_.size()
                        && shouldRetryInternetError(msg)) {
                    internetTestIndex_++;
                    QTimer::singleShot(250, this, [this]() {
                        startInternetTestAttempt();
                    });
                    return;
                }

                internetTestActive_ = false;
                errorMessage_ = msg;
                running_ = false;
                emit errorMessageChanged();
                emit runningChanged();
            });
}

void SpeedTestViewModel::setChannelRepository(iptvxs::ChannelRepository *repo) {
    channelRepo_ = repo;
}

void SpeedTestViewModel::setFavoriteRepository(iptvxs::FavoriteRepository *repo) {
    favoriteRepo_ = repo;
}

void SpeedTestViewModel::setHistoryRepository(iptvxs::HistoryRepository *repo) {
    historyRepo_ = repo;
}

QVariantList SpeedTestViewModel::quickTestChannels(int serverId) {
    if (!channelRepo_) return {};

    auto allLive = channelRepo_->findByServerAndType(serverId, QStringLiteral("live"), 0, 0);
    if (allLive.isEmpty()) return {};

    QSet<int64_t> usedIds;
    QVariantList result;

    auto addChannel = [&](const iptvxs::Channel &ch) {
        if (usedIds.contains(ch.id) || ch.streamUrl.isEmpty()) return;
        usedIds.insert(ch.id);
        QVariantMap m;
        m["channelId"] = QVariant::fromValue(static_cast<qlonglong>(ch.id));
        m["name"] = ch.name;
        m["streamUrl"] = ch.streamUrl;
        result.append(m);
    };

    if (favoriteRepo_) {
        auto favs = favoriteRepo_->findAll();
        for (const auto &fav : favs) {
            if (result.size() >= 5) break;
            for (const auto &ch : allLive) {
                if (ch.id == fav.channelId) { addChannel(ch); break; }
            }
        }
    }

    if (historyRepo_ && result.size() < 8) {
        auto history = historyRepo_->findRecent(20);
        for (const auto &h : history) {
            if (result.size() >= 5) break;
            for (const auto &ch : allLive) {
                if (ch.id == h.channelId) { addChannel(ch); break; }
            }
        }
    }

    if (result.size() < 8) {
        QVector<int> indices(allLive.size());
        std::iota(indices.begin(), indices.end(), 0);
        std::shuffle(indices.begin(), indices.end(), *QRandomGenerator::global());
        for (int idx : indices) {
            if (result.size() >= 5) break;
            addChannel(allLive.at(idx));
        }
    }

    return result;
}

bool SpeedTestViewModel::running() const { return running_; }
double SpeedTestViewModel::currentMbps() const { return currentMbps_; }
double SpeedTestViewModel::resultMbps() const { return resultMbps_; }

QString SpeedTestViewModel::bytesReceived() const {
    return formatBytes(bytesReceived_);
}

QString SpeedTestViewModel::elapsed() const {
    auto secs = elapsedMs_ / 1000.0;
    return QStringLiteral("%1s").arg(secs, 0, 'f', 1);
}

QString SpeedTestViewModel::errorMessage() const { return errorMessage_; }
bool SpeedTestViewModel::hasResult() const { return hasResult_; }
int SpeedTestViewModel::duration() const { return duration_; }

void SpeedTestViewModel::setDuration(int secs) {
    if (secs < 3) secs = 3;
    if (secs > 120) secs = 120;
    if (duration_ != secs) {
        duration_ = secs;
        emit durationChanged();
    }
}

void SpeedTestViewModel::startTest(const QString &streamUrl) {
    startTestInternal(streamUrl, false);
}

void SpeedTestViewModel::startTestInternal(const QString &streamUrl, bool internetTest) {
    if (!runner_ || streamUrl.isEmpty()) {
        return;
    }

    if (!internetTest) {
        internetTestActive_ = false;
    }
    errorMessage_.clear();
    currentMbps_ = 0.0;
    resultMbps_ = 0.0;
    bytesReceived_ = 0;
    elapsedMs_ = 0;
    hasResult_ = false;
    running_ = true;

    emit errorMessageChanged();
    emit currentMbpsChanged();
    emit resultMbpsChanged();
    emit bytesReceivedChanged();
    emit elapsedChanged();
    emit hasResultChanged();
    emit runningChanged();

    runner_->start(QUrl(streamUrl), duration_);
}

void SpeedTestViewModel::startTestForChannel(qint64 channelId) {
    if (!channelRepo_) {
        return;
    }

    auto channel = channelRepo_->findById(channelId);
    if (!channel || channel->streamUrl.isEmpty()) {
        errorMessage_ = QStringLiteral("Channel not found or has no stream URL");
        emit errorMessageChanged();
        return;
    }

    startTest(channel->streamUrl);
}

void SpeedTestViewModel::startInternetTest() {
    internetTestUrls_ = {
        QStringLiteral("https://ash-speed.hetzner.com/100MB.bin"),
        QStringLiteral("https://proof.ovh.net/files/100Mb.dat"),
        QStringLiteral("https://speedtest.tele2.net/100MB.zip"),
    };
    std::shuffle(internetTestUrls_.begin(), internetTestUrls_.end(), *QRandomGenerator::global());
    internetTestIndex_ = 0;
    internetTestActive_ = true;
    startInternetTestAttempt();
}

void SpeedTestViewModel::stopTest() {
    internetTestActive_ = false;
    if (runner_) {
        runner_->stop();
    }
}

QString SpeedTestViewModel::formatBytes(qint64 bytes) {
    if (bytes < 1024) {
        return QStringLiteral("%1 B").arg(bytes);
    }
    if (bytes < 1024 * 1024) {
        return QStringLiteral("%1 KB").arg(bytes / 1024.0, 0, 'f', 1);
    }
    return QStringLiteral("%1 MB").arg(bytes / (1024.0 * 1024.0), 0, 'f', 1);
}

void SpeedTestViewModel::startInternetTestAttempt() {
    if (internetTestIndex_ < 0 || internetTestIndex_ >= internetTestUrls_.size()) {
        internetTestActive_ = false;
        return;
    }
    startTestInternal(internetTestUrls_.at(internetTestIndex_), true);
}

bool SpeedTestViewModel::shouldRetryInternetError(const QString &message) const {
    const auto msg = message.toLower();
    return msg.contains(QStringLiteral("connection refused"))
        || msg.contains(QStringLiteral("timeout"))
        || msg.contains(QStringLiteral("temporarily"))
        || msg.contains(QStringLiteral("network"));
}
