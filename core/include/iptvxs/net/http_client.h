// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QUrl>

namespace iptvxs {

class HttpClient : public QObject {
    Q_OBJECT

public:
    explicit HttpClient(QObject *parent = nullptr);

    QNetworkReply *get(const QUrl &url);
    QNetworkReply *get(const QNetworkRequest &request);
    QNetworkReply *post(const QUrl &url, const QByteArray &data);
    QNetworkReply *post(const QNetworkRequest &request, const QByteArray &data);

    void setCustomUserAgent(const QString &suffix);
    void setTimeoutMs(int ms);

    static constexpr int kDefaultTimeoutMs = 30000;

private:
    QNetworkAccessManager nam_;
    QString userAgentSuffix_;
    int timeoutMs_{kDefaultTimeoutMs};

    QByteArray buildUserAgent() const;
};

} // namespace iptvxs
