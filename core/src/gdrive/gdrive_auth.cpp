#include "iptvxs/gdrive/gdrive_auth.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTcpSocket>
#include <QUrl>
#include <QUrlQuery>

namespace iptvxs {

GDriveAuth::GDriveAuth(SettingsRepository *settings, QObject *parent)
    : QObject(parent), settings_(settings) {
    loadTokens();
}

void GDriveAuth::setCredentials(const QString &clientId, const QString &clientSecret) {
    clientId_ = clientId;
    clientSecret_ = clientSecret;
}

bool GDriveAuth::isAuthenticated() const {
    return !refreshToken_.isEmpty();
}

QString GDriveAuth::accessToken() const {
    return accessToken_;
}

void GDriveAuth::startAuthFlow() {
    if (clientId_.isEmpty()) {
        emit authenticationFailed(QStringLiteral("Client ID not configured"));
        return;
    }

    if (redirectServer_) {
        redirectServer_->close();
        redirectServer_->deleteLater();
    }

    redirectServer_ = new QTcpServer(this);
    connect(redirectServer_, &QTcpServer::newConnection, this, &GDriveAuth::onNewConnection);

    if (!redirectServer_->listen(QHostAddress::LocalHost, kRedirectPort)) {
        emit authenticationFailed(QStringLiteral("Failed to start redirect server"));
        return;
    }

    QUrl authUrl(QString::fromUtf8(kAuthUrl));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("client_id"), clientId_);
    query.addQueryItem(QStringLiteral("redirect_uri"),
                       QStringLiteral("http://localhost:%1").arg(kRedirectPort));
    query.addQueryItem(QStringLiteral("response_type"), QStringLiteral("code"));
    query.addQueryItem(QStringLiteral("scope"), QString::fromUtf8(kScope));
    query.addQueryItem(QStringLiteral("access_type"), QStringLiteral("offline"));
    query.addQueryItem(QStringLiteral("prompt"), QStringLiteral("consent"));
    authUrl.setQuery(query);

    emit openUrlRequested(authUrl);
}

void GDriveAuth::logout() {
    accessToken_.clear();
    refreshToken_.clear();
    tokenExpiresAt_ = 0;

    if (settings_) {
        settings_->remove(QStringLiteral("gdrive_access_token"));
        settings_->remove(QStringLiteral("gdrive_refresh_token"));
        settings_->remove(QStringLiteral("gdrive_token_expires_at"));
    }

    emit loggedOut();
}

void GDriveAuth::refreshTokenIfNeeded() {
    if (!isAuthenticated()) {
        return;
    }

    if (isTokenExpired()) {
        refreshAccessToken();
    }
}

void GDriveAuth::onNewConnection() {
    auto *socket = redirectServer_->nextPendingConnection();
    if (!socket) {
        return;
    }

    connect(socket, &QTcpSocket::readyRead, this, [this, socket]() {
        auto data = socket->readAll();
        auto requestLine = QString::fromUtf8(data).split(QStringLiteral("\r\n")).first();
        auto path = requestLine.split(QStringLiteral(" ")).value(1);
        QUrlQuery query(QUrl(path).query());
        auto code = query.queryItemValue(QStringLiteral("code"));

        auto response = QStringLiteral(
            "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
            "<html><body><h2>Authentication successful!</h2>"
            "<p>You can close this window and return to iptvxs.</p></body></html>");
        socket->write(response.toUtf8());
        socket->flush();
        socket->disconnectFromHost();

        redirectServer_->close();

        if (!code.isEmpty()) {
            exchangeCodeForToken(code);
        } else {
            auto error = query.queryItemValue(QStringLiteral("error"));
            emit authenticationFailed(error.isEmpty() ? QStringLiteral("No auth code received") : error);
        }
    });
}

void GDriveAuth::exchangeCodeForToken(const QString &code) {
    auto *nam = new QNetworkAccessManager(this);

    QUrlQuery postData;
    postData.addQueryItem(QStringLiteral("code"), code);
    postData.addQueryItem(QStringLiteral("client_id"), clientId_);
    postData.addQueryItem(QStringLiteral("client_secret"), clientSecret_);
    postData.addQueryItem(QStringLiteral("redirect_uri"),
                          QStringLiteral("http://localhost:%1").arg(kRedirectPort));
    postData.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("authorization_code"));

    QNetworkRequest request{QUrl{QString::fromUtf8(kTokenUrl)}};
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/x-www-form-urlencoded"));

    auto *reply = nam->post(request, postData.toString(QUrl::FullyEncoded).toUtf8());

    connect(reply, &QNetworkReply::finished, this, [this, reply, nam]() {
        reply->deleteLater();
        nam->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit authenticationFailed(reply->errorString());
            return;
        }

        auto doc = QJsonDocument::fromJson(reply->readAll());
        auto obj = doc.object();

        accessToken_ = obj.value(QStringLiteral("access_token")).toString();
        refreshToken_ = obj.value(QStringLiteral("refresh_token")).toString();
        auto expiresIn = obj.value(QStringLiteral("expires_in")).toInt();
        tokenExpiresAt_ = QDateTime::currentSecsSinceEpoch() + expiresIn - 60;

        saveTokens();
        emit authenticated();
    });
}

void GDriveAuth::refreshAccessToken() {
    if (refreshToken_.isEmpty()) {
        return;
    }

    auto *nam = new QNetworkAccessManager(this);

    QUrlQuery postData;
    postData.addQueryItem(QStringLiteral("client_id"), clientId_);
    postData.addQueryItem(QStringLiteral("client_secret"), clientSecret_);
    postData.addQueryItem(QStringLiteral("refresh_token"), refreshToken_);
    postData.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("refresh_token"));

    QNetworkRequest request{QUrl{QString::fromUtf8(kTokenUrl)}};
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/x-www-form-urlencoded"));

    auto *reply = nam->post(request, postData.toString(QUrl::FullyEncoded).toUtf8());

    connect(reply, &QNetworkReply::finished, this, [this, reply, nam]() {
        reply->deleteLater();
        nam->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit authenticationFailed(reply->errorString());
            return;
        }

        auto doc = QJsonDocument::fromJson(reply->readAll());
        auto obj = doc.object();

        accessToken_ = obj.value(QStringLiteral("access_token")).toString();
        auto expiresIn = obj.value(QStringLiteral("expires_in")).toInt();
        tokenExpiresAt_ = QDateTime::currentSecsSinceEpoch() + expiresIn - 60;

        if (obj.contains(QStringLiteral("refresh_token"))) {
            refreshToken_ = obj.value(QStringLiteral("refresh_token")).toString();
        }

        saveTokens();
        emit tokenRefreshed();
    });
}

void GDriveAuth::saveTokens() {
    if (!settings_) {
        return;
    }
    settings_->set(QStringLiteral("gdrive_access_token"), accessToken_);
    settings_->set(QStringLiteral("gdrive_refresh_token"), refreshToken_);
    settings_->set(QStringLiteral("gdrive_token_expires_at"),
                   static_cast<int>(tokenExpiresAt_));
}

void GDriveAuth::loadTokens() {
    if (!settings_) {
        return;
    }
    accessToken_ = settings_->getString(QStringLiteral("gdrive_access_token"));
    refreshToken_ = settings_->getString(QStringLiteral("gdrive_refresh_token"));
    tokenExpiresAt_ = settings_->getInt(QStringLiteral("gdrive_token_expires_at"));
}

bool GDriveAuth::isTokenExpired() const {
    return QDateTime::currentSecsSinceEpoch() >= tokenExpiresAt_;
}

} // namespace iptvxs
