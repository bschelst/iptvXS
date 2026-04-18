#include "speed_test_viewmodel.h"

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
                hasResult_ = true;
                emit resultMbpsChanged();
                emit bytesReceivedChanged();
                emit elapsedChanged();
                emit runningChanged();
                emit hasResultChanged();
            });

    connect(runner_, &iptvxs::SpeedTestRunner::errorOccurred, this,
            [this](const QString &msg) {
                errorMessage_ = msg;
                running_ = false;
                emit errorMessageChanged();
                emit runningChanged();
            });
}

void SpeedTestViewModel::setChannelRepository(iptvxs::ChannelRepository *repo) {
    channelRepo_ = repo;
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
    if (secs > 60) secs = 60;
    if (duration_ != secs) {
        duration_ = secs;
        emit durationChanged();
    }
}

void SpeedTestViewModel::startTest(const QString &streamUrl) {
    if (!runner_ || streamUrl.isEmpty()) {
        return;
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

void SpeedTestViewModel::stopTest() {
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
