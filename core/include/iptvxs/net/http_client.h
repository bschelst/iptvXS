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
