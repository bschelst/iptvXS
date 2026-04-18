#pragma once

#include <QObject>
#include <QString>
#include <QTcpServer>

#include "iptvxs/db/settings_repository.h"

namespace iptvxs {

class GDriveAuth : public QObject {
    Q_OBJECT

public:
    explicit GDriveAuth(SettingsRepository *settings, QObject *parent = nullptr);

    void setCredentials(const QString &clientId, const QString &clientSecret);

    bool isAuthenticated() const;
    QString accessToken() const;

    void startAuthFlow();
    void logout();

    void refreshTokenIfNeeded();

signals:
    void authenticated();
    void authenticationFailed(const QString &error);
    void tokenRefreshed();
    void loggedOut();
    void openUrlRequested(const QUrl &url);

private slots:
    void onNewConnection();

private:
    void exchangeCodeForToken(const QString &code);
    void refreshAccessToken();
    void saveTokens();
    void loadTokens();
    bool isTokenExpired() const;

    SettingsRepository *settings_;
    QString clientId_;
    QString clientSecret_;
    QString accessToken_;
    QString refreshToken_;
    int64_t tokenExpiresAt_{0};
    QTcpServer *redirectServer_{nullptr};

    static constexpr int kRedirectPort = 8085;
    static constexpr const char *kTokenUrl = "https://oauth2.googleapis.com/token";
    static constexpr const char *kAuthUrl = "https://accounts.google.com/o/oauth2/v2/auth";
    static constexpr const char *kScope = "https://www.googleapis.com/auth/drive.file";
};

} // namespace iptvxs
