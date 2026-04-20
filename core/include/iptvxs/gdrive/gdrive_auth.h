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

    // Legacy signature kept so existing callers still compile; secret is ignored
    // under the PKCE flow but stored for backward compatibility if present.
    void setCredentials(const QString &clientId, const QString &clientSecret = {});
    void setClientId(const QString &clientId);

    bool isAuthenticated() const;
    QString accessToken() const;

    void startAuthFlow();
    void logout();

    void refreshTokenIfNeeded();
    bool needsRefresh() const;

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
    QString pkceVerifier_;
    int listenPort_{0};

    static constexpr const char *kTokenUrl = "https://oauth2.googleapis.com/token";
    static constexpr const char *kAuthUrl = "https://accounts.google.com/o/oauth2/v2/auth";
    static constexpr const char *kScope = "https://www.googleapis.com/auth/drive.file";

    // Default bundled OAuth client ID for the iptvXS desktop app. Desktop OAuth
    // clients are public — the ID ships with the binary and is paired per-flow
    // with a PKCE verifier, so no user configuration is required. Override at
    // build time with -DIPTVXS_GDRIVE_CLIENT_ID="..." if forking the project.
#ifndef IPTVXS_GDRIVE_CLIENT_ID
#define IPTVXS_GDRIVE_CLIENT_ID ""
#endif
    static constexpr const char *kDefaultClientId = IPTVXS_GDRIVE_CLIENT_ID;

    // Google's token endpoint requires client_secret even for Desktop clients
    // using PKCE. Google explicitly notes it is "not treated as a secret" for
    // installed apps — the real protection comes from PKCE's code_verifier.
#ifndef IPTVXS_GDRIVE_CLIENT_SECRET
#define IPTVXS_GDRIVE_CLIENT_SECRET ""
#endif
    static constexpr const char *kDefaultClientSecret = IPTVXS_GDRIVE_CLIENT_SECRET;
};

} // namespace iptvxs
