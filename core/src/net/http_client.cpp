// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/net/http_client.h"

#include <QCoreApplication>
#include <QNetworkRequest>
#include <QSysInfo>

namespace iptvxs {

HttpClient::HttpClient(QObject *parent)
    : QObject(parent) {}

QNetworkReply *HttpClient::get(const QUrl &url) {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, buildUserAgent());
    request.setTransferTimeout(timeoutMs_);
    return nam_.get(request);
}

QNetworkReply *HttpClient::get(const QNetworkRequest &request) {
    auto req = request;
    if (!req.hasRawHeader("User-Agent"))
        req.setHeader(QNetworkRequest::UserAgentHeader, buildUserAgent());
    req.setTransferTimeout(timeoutMs_);
    return nam_.get(req);
}

QNetworkReply *HttpClient::post(const QUrl &url, const QByteArray &data) {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, buildUserAgent());
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setTransferTimeout(timeoutMs_);
    return nam_.post(request, data);
}

QNetworkReply *HttpClient::post(const QNetworkRequest &request,
                                 const QByteArray &data) {
    auto req = request;
    if (!req.hasRawHeader("User-Agent"))
        req.setHeader(QNetworkRequest::UserAgentHeader, buildUserAgent());
    req.setTransferTimeout(timeoutMs_);
    return nam_.post(req, data);
}

void HttpClient::setCustomUserAgent(const QString &suffix) {
    userAgentSuffix_ = suffix;
}

void HttpClient::setTimeoutMs(int ms) {
    timeoutMs_ = ms;
}

QByteArray HttpClient::buildUserAgent() const {
    auto version = QCoreApplication::applicationVersion();
    auto agent = QStringLiteral("IPTVXs/%1 (%2 %3)")
        .arg(version.isEmpty() ? QStringLiteral("0.3.0") : version,
             QSysInfo::productType(),
             QSysInfo::productVersion());
    if (!userAgentSuffix_.isEmpty()) {
        agent += QStringLiteral(" %1").arg(userAgentSuffix_);
    }
    return agent.toUtf8();
}

} // namespace iptvxs
