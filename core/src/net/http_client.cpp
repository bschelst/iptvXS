#include "iptvxs/net/http_client.h"

#include <QCoreApplication>
#include <QNetworkRequest>

namespace iptvxs {

HttpClient::HttpClient(QObject *parent)
    : QObject(parent) {}

QNetworkReply *HttpClient::get(const QUrl &url) {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, buildUserAgent());
    request.setTransferTimeout(timeoutMs_);
    return nam_.get(request);
}

void HttpClient::setCustomUserAgent(const QString &suffix) {
    userAgentSuffix_ = suffix;
}

void HttpClient::setTimeoutMs(int ms) {
    timeoutMs_ = ms;
}

QByteArray HttpClient::buildUserAgent() const {
    auto version = QCoreApplication::applicationVersion();
    auto agent = QStringLiteral("IPTVXs/%1").arg(version.isEmpty() ? QStringLiteral("0.1.0") : version);
    if (!userAgentSuffix_.isEmpty()) {
        agent += QStringLiteral(" %1").arg(userAgentSuffix_);
    }
    return agent.toUtf8();
}

} // namespace iptvxs
