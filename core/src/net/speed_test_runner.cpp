// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
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
    testUrl_ = streamUrl;
    activeConnections_ = 0;

    elapsed_.start();
    timer_.start(durationSecs * 1000);

    for (int i = 0; i < kParallelConnections; ++i) {
        startConnection(streamUrl);
    }
}

void SpeedTestRunner::startConnection(const QUrl &url) {
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setRawHeader("User-Agent", "iptvXS/1.0 (Speed Test)");
    req.setTransferTimeout(30000);

    auto *reply = nam_.get(req);
    replies_.append(reply);
    activeConnections_++;

    connect(reply, &QNetworkReply::readyRead, this, &SpeedTestRunner::onReadyRead);
    connect(reply, &QNetworkReply::finished, this, &SpeedTestRunner::onReplyFinished);
    connect(reply, &QNetworkReply::errorOccurred, this, &SpeedTestRunner::onReplyError);
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
    auto *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply || !running_) {
        return;
    }

    auto data = reply->readAll();
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
    auto *reply = qobject_cast<QNetworkReply *>(sender());
    if (!running_ || !reply) {
        return;
    }

    replies_.removeOne(reply);
    reply->deleteLater();
    activeConnections_--;

    if (running_ && timer_.isActive()) {
        startConnection(testUrl_);
    }
}

void SpeedTestRunner::onReplyError(QNetworkReply::NetworkError code) {
    auto *reply = qobject_cast<QNetworkReply *>(sender());
    if (!running_) {
        return;
    }

    if (activeConnections_ <= 1 && totalBytes_ == 0) {
        auto errorStr = reply ? reply->errorString() : QStringLiteral("Unknown network error");
        auto httpStatus = reply ? reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() : 0;

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
        return;
    }

    if (reply) {
        replies_.removeOne(reply);
        reply->deleteLater();
        activeConnections_--;
    }
}

void SpeedTestRunner::cleanup() {
    running_ = false;
    timer_.stop();

    for (auto *reply : replies_) {
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }
    replies_.clear();
    activeConnections_ = 0;
}

double SpeedTestRunner::calculateMbps(qint64 bytes, qint64 ms) const {
    if (ms <= 0) {
        return 0.0;
    }
    return (static_cast<double>(bytes) * 8.0) / (static_cast<double>(ms) * 1000.0);
}

} // namespace iptvxs
