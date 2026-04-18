#include "iptvxs/net/speed_test_runner.h"

namespace iptvxs {

SpeedTestRunner::SpeedTestRunner(QObject *parent)
    : QObject(parent) {
    timer_.setSingleShot(true);
    connect(&timer_, &QTimer::timeout, this, &SpeedTestRunner::onTimerTimeout);
}

void SpeedTestRunner::start(const QUrl &streamUrl, int durationSecs) {
    if (running_) {
        stop();
    }

    totalBytes_ = 0;
    running_ = true;

    QNetworkRequest req(streamUrl);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setRawHeader("User-Agent", "iptvXS/1.0 (Speed Test)");
    req.setTransferTimeout(30000);

    reply_ = nam_.get(req);
    connect(reply_, &QNetworkReply::readyRead, this, &SpeedTestRunner::onReadyRead);
    connect(reply_, &QNetworkReply::finished, this, &SpeedTestRunner::onReplyFinished);
    connect(reply_, &QNetworkReply::errorOccurred, this, &SpeedTestRunner::onReplyError);

    elapsed_.start();
    timer_.start(durationSecs * 1000);
}

void SpeedTestRunner::stop() {
    if (!running_) {
        return;
    }

    auto ms = elapsed_.elapsed();
    auto result = SpeedTestResult{calculateMbps(totalBytes_, ms), totalBytes_, ms};
    cleanup();
    emit finished(result);
}

bool SpeedTestRunner::isRunning() const {
    return running_;
}

void SpeedTestRunner::onReadyRead() {
    if (!reply_ || !running_) {
        return;
    }

    auto data = reply_->readAll();
    totalBytes_ += data.size();

    auto ms = elapsed_.elapsed();
    if (ms > 0) {
        emit progressUpdated(calculateMbps(totalBytes_, ms), totalBytes_, ms);
    }
}

void SpeedTestRunner::onTimerTimeout() {
    stop();
}

void SpeedTestRunner::onReplyFinished() {
    if (!running_) {
        return;
    }

    auto ms = elapsed_.elapsed();
    auto result = SpeedTestResult{calculateMbps(totalBytes_, ms), totalBytes_, ms};
    cleanup();
    emit finished(result);
}

void SpeedTestRunner::onReplyError(QNetworkReply::NetworkError code) {
    if (!running_) {
        return;
    }

    auto errorStr = reply_ ? reply_->errorString() : QStringLiteral("Unknown network error");
    auto httpStatus = reply_ ? reply_->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() : 0;

    QString msg;
    if (httpStatus > 0) {
        msg = QStringLiteral("HTTP %1: %2 (error code: %3)")
                  .arg(httpStatus)
                  .arg(errorStr)
                  .arg(static_cast<int>(code));
    } else {
        msg = QStringLiteral("%1 (error code: %2)").arg(errorStr).arg(static_cast<int>(code));
    }

    cleanup();
    emit errorOccurred(msg);
}

void SpeedTestRunner::cleanup() {
    running_ = false;
    timer_.stop();

    if (reply_) {
        reply_->abort();
        reply_->deleteLater();
        reply_ = nullptr;
    }
}

double SpeedTestRunner::calculateMbps(qint64 bytes, qint64 ms) const {
    if (ms <= 0) {
        return 0.0;
    }
    return (static_cast<double>(bytes) * 8.0) / (static_cast<double>(ms) * 1000.0);
}

} // namespace iptvxs
