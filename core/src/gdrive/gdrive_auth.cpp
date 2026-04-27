// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/gdrive/gdrive_auth.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRandomGenerator>
#include <QTcpSocket>
#include <QUrl>
#include <QUrlQuery>

namespace {

// RFC 7636 §4.1 — PKCE code_verifier: 43-128 chars of unreserved URL-safe chars.
QString makeRandomVerifier(int len = 64) {
    static const char alphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
    const int alphaLen = static_cast<int>(sizeof(alphabet) - 1);
    QString out;
    out.reserve(len);
    for (int i = 0; i < len; ++i) {
        out.append(QLatin1Char(alphabet[QRandomGenerator::system()->bounded(alphaLen)]));
    }
    return out;
}

// RFC 7636 §4.2 — Base64URL(SHA-256(verifier)) without padding.
QString makeS256Challenge(const QString &verifier) {
    auto sha = QCryptographicHash::hash(verifier.toUtf8(), QCryptographicHash::Sha256);
    auto b64 = sha.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    return QString::fromLatin1(b64);
}

} // namespace

namespace iptvxs {

GDriveAuth::GDriveAuth(SettingsRepository *settings, QObject *parent)
    : QObject(parent), settings_(settings) {
    clientId_ = QString::fromUtf8(kDefaultClientId);
    clientSecret_ = QString::fromUtf8(kDefaultClientSecret);
    gatewayUrl_ = QString::fromUtf8(kDefaultGatewayUrl);
    gatewayApiKey_ = QString::fromUtf8(kDefaultGatewayApiKey);
    useGateway_ = !gatewayUrl_.isEmpty() && !gatewayApiKey_.isEmpty();
    loadTokens();
}

void GDriveAuth::setCredentials(const QString &clientId, const QString &clientSecret) {
    clientId_ = clientId;
    if (!clientSecret.isEmpty()) {
        clientSecret_ = clientSecret;
    }
}

void GDriveAuth::setClientId(const QString &clientId) {
    clientId_ = clientId;
}

bool GDriveAuth::isAuthenticated() const {
    return !refreshToken_.isEmpty();
}

QString GDriveAuth::accessToken() const {
    return accessToken_;
}

void GDriveAuth::startAuthFlow() {
    if (!useGateway_ && clientId_.isEmpty()) {
        emit authenticationFailed(QStringLiteral(
            "Google Drive OAuth not configured. Please update the app."));
        return;
    }

    if (redirectServer_) {
        redirectServer_->close();
        redirectServer_->deleteLater();
    }

    redirectServer_ = new QTcpServer(this);
    connect(redirectServer_, &QTcpServer::newConnection, this, &GDriveAuth::onNewConnection);

    if (!redirectServer_->listen(QHostAddress::LocalHost, 0)) {
        emit authenticationFailed(QStringLiteral("Failed to start redirect server"));
        return;
    }
    listenPort_ = redirectServer_->serverPort();

    if (useGateway_) {
        QUrl url(gatewayUrl_ + QStringLiteral("/api/oauth/start"));
        QUrlQuery q;
        q.addQueryItem(QStringLiteral("redirect_port"), QString::number(listenPort_));
        url.setQuery(q);

        QNetworkRequest req(url);
        req.setRawHeader("User-Agent", "IPTVXs/1.0");
        auto *reply = nam_.get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                qWarning("Gateway OAuth start failed: %s — falling back to direct",
                         qPrintable(reply->errorString()));
                startAuthFlowDirect();
                return;
            }
            auto doc = QJsonDocument::fromJson(reply->readAll());
            auto obj = doc.object();
            auto authUrl = obj.value("auth_url").toString();
            pkceVerifier_ = obj.value("code_verifier").toString();
            if (authUrl.isEmpty() || pkceVerifier_.isEmpty()) {
                qWarning("Gateway OAuth start: empty response — falling back");
                startAuthFlowDirect();
                return;
            }
            qInfo("OAuth via gateway: auth URL received");
            emit openUrlRequested(QUrl(authUrl));
        });
    } else {
        startAuthFlowDirect();
    }
}

void GDriveAuth::startAuthFlowDirect() {
    pkceVerifier_ = makeRandomVerifier(64);
    const QString challenge = makeS256Challenge(pkceVerifier_);

    QUrl authUrl(QString::fromUtf8(kAuthUrl));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("client_id"), clientId_);
    query.addQueryItem(QStringLiteral("redirect_uri"),
                       QStringLiteral("http://localhost:%1").arg(listenPort_));
    query.addQueryItem(QStringLiteral("response_type"), QStringLiteral("code"));
    query.addQueryItem(QStringLiteral("scope"), QString::fromUtf8(kScope));
    query.addQueryItem(QStringLiteral("access_type"), QStringLiteral("offline"));
    query.addQueryItem(QStringLiteral("prompt"), QStringLiteral("consent"));
    query.addQueryItem(QStringLiteral("code_challenge"), challenge);
    query.addQueryItem(QStringLiteral("code_challenge_method"), QStringLiteral("S256"));
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

bool GDriveAuth::needsRefresh() const {
    return isAuthenticated() && isTokenExpired();
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

void GDriveAuth::exchangeCodeViaGateway(const QString &code) {
    QJsonObject body;
    body["code"] = code;
    body["code_verifier"] = pkceVerifier_;
    body["redirect_uri"] = QStringLiteral("http://localhost:%1").arg(listenPort_);

    QNetworkRequest req(QUrl(gatewayUrl_ + QStringLiteral("/api/oauth/token")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("X-API-Key", gatewayApiKey_.toUtf8());
    req.setRawHeader("User-Agent", "IPTVXs/1.0");

    auto *reply = nam_.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, code]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning("Gateway token exchange failed: %s — falling back to direct",
                     qPrintable(reply->errorString()));
            exchangeCodeForToken(code);
            return;
        }
        auto doc = QJsonDocument::fromJson(reply->readAll());
        auto obj = doc.object();
        accessToken_ = obj.value("access_token").toString();
        refreshToken_ = obj.value("refresh_token").toString();
        auto expiresIn = obj.value("expires_in").toInt();
        tokenExpiresAt_ = QDateTime::currentSecsSinceEpoch() + expiresIn - 60;
        if (accessToken_.isEmpty()) {
            emit authenticationFailed(QStringLiteral("Gateway returned empty access_token"));
            return;
        }
        qInfo("OAuth token exchange via gateway successful");
        saveTokens();
        emit authenticated();
    });
}

void GDriveAuth::exchangeCodeForToken(const QString &code) {
    if (useGateway_) {
        exchangeCodeViaGateway(code);
        return;
    }

    QUrlQuery postData;
    postData.addQueryItem(QStringLiteral("code"), code);
    postData.addQueryItem(QStringLiteral("client_id"), clientId_);
    if (!clientSecret_.isEmpty()) {
        postData.addQueryItem(QStringLiteral("client_secret"), clientSecret_);
    }
    postData.addQueryItem(QStringLiteral("code_verifier"), pkceVerifier_);
    postData.addQueryItem(QStringLiteral("redirect_uri"),
                          QStringLiteral("http://localhost:%1").arg(listenPort_));
    postData.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("authorization_code"));

    QNetworkRequest request{QUrl{QString::fromUtf8(kTokenUrl)}};
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/x-www-form-urlencoded"));

    auto *reply = nam_.post(request, postData.toString(QUrl::FullyEncoded).toUtf8());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        auto body = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning("GDrive token exchange failed: %s — body: %s",
                     qPrintable(reply->errorString()), body.constData());
            emit authenticationFailed(
                QStringLiteral("%1 — %2").arg(reply->errorString(),
                                              QString::fromUtf8(body)));
            return;
        }

        auto doc = QJsonDocument::fromJson(body);
        auto obj = doc.object();

        accessToken_ = obj.value(QStringLiteral("access_token")).toString();
        refreshToken_ = obj.value(QStringLiteral("refresh_token")).toString();
        auto expiresIn = obj.value(QStringLiteral("expires_in")).toInt();
        tokenExpiresAt_ = QDateTime::currentSecsSinceEpoch() + expiresIn - 60;

        if (accessToken_.isEmpty()) {
            qWarning("GDrive token response missing access_token: %s",
                     body.constData());
            emit authenticationFailed(QString::fromUtf8(body));
            return;
        }

        saveTokens();
        emit authenticated();
    });
}

void GDriveAuth::refreshViaGateway() {
    QJsonObject body;
    body["refresh_token"] = refreshToken_;

    QNetworkRequest req(QUrl(gatewayUrl_ + QStringLiteral("/api/oauth/refresh")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("X-API-Key", gatewayApiKey_.toUtf8());
    req.setRawHeader("User-Agent", "IPTVXs/1.0");

    auto *reply = nam_.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning("Gateway token refresh failed: %s", qPrintable(reply->errorString()));
            emit authenticationFailed(reply->errorString());
            return;
        }
        auto doc = QJsonDocument::fromJson(reply->readAll());
        auto obj = doc.object();
        accessToken_ = obj.value("access_token").toString();
        auto expiresIn = obj.value("expires_in").toInt();
        tokenExpiresAt_ = QDateTime::currentSecsSinceEpoch() + expiresIn - 60;
        if (obj.contains("refresh_token"))
            refreshToken_ = obj.value("refresh_token").toString();
        saveTokens();
        emit tokenRefreshed();
    });
}

void GDriveAuth::refreshAccessToken() {
    if (refreshToken_.isEmpty()) {
        return;
    }

    if (useGateway_) {
        refreshViaGateway();
        return;
    }

    QUrlQuery postData;
    postData.addQueryItem(QStringLiteral("client_id"), clientId_);
    if (!clientSecret_.isEmpty()) {
        postData.addQueryItem(QStringLiteral("client_secret"), clientSecret_);
    }
    postData.addQueryItem(QStringLiteral("refresh_token"), refreshToken_);
    postData.addQueryItem(QStringLiteral("grant_type"), QStringLiteral("refresh_token"));

    QNetworkRequest request{QUrl{QString::fromUtf8(kTokenUrl)}};
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/x-www-form-urlencoded"));

    auto *reply = nam_.post(request, postData.toString(QUrl::FullyEncoded).toUtf8());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

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
