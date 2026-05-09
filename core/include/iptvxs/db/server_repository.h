// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QVector>
#include <memory>
#include <optional>

#include "iptvxs/models/server.h"
#include "iptvxs/security/credential_vault.h"

namespace iptvxs {

class ServerRepository : public QObject {
    Q_OBJECT

public:
    explicit ServerRepository(QSqlDatabase db, QObject *parent = nullptr);
    ServerRepository(QSqlDatabase db, CredentialVault *credentialVault, QObject *parent = nullptr);

    QVector<Server> findAll() const;
    std::optional<Server> findById(int64_t id) const;
    int64_t create(const Server &server);
    bool update(const Server &server);
    bool remove(int64_t id);
    bool updateLastSynced(int64_t id, int64_t timestamp);
    bool setEpgSource(int64_t id, int64_t epgSourceId);
    bool setEnabled(int64_t id, bool enabled);
    bool setPrimary(int64_t id);
    int count() const;

    // Vault used to encrypt server credentials. Other subsystems (e.g. the
    // sync service) reuse it so the same key encrypts both at-rest and in-flight.
    CredentialVault *credentialVault() const { return credentialVaultPtr_; }

signals:
    void errorOccurred(const QString &message);

private:
    static Server fromQuery(const QSqlQuery &query);
    Server withProtectedCredentials(Server server) const;
    Server withDecryptedCredentials(Server server) const;
    bool migrateCredentialStorage();

    QSqlDatabase db_;
    std::unique_ptr<CredentialVault> ownedCredentialVault_;
    CredentialVault *credentialVaultPtr_{nullptr};
};

} // namespace iptvxs
