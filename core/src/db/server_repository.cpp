// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/server_repository.h"

#include <QPair>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

#include <utility>

#include "iptvxs/security/credential_vault.h"

#include <QDebug>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }
} // namespace

namespace iptvxs {

ServerRepository::ServerRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {
    ownedCredentialVault_ = std::make_unique<CredentialVault>();
    credentialVaultPtr_ = ownedCredentialVault_.get();
    migrateCredentialStorage();
}

ServerRepository::ServerRepository(QSqlDatabase db, CredentialVault *credentialVault, QObject *parent)
    : QObject(parent), db_(std::move(db)) {
    if (credentialVault) {
        credentialVaultPtr_ = credentialVault;
    } else {
        ownedCredentialVault_ = std::make_unique<CredentialVault>();
        credentialVaultPtr_ = ownedCredentialVault_.get();
    }
    migrateCredentialStorage();
}

QVector<Server> ServerRepository::findAll() const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, name, type, url, username, password, user_agent, "
                  "epg_url, epg_source_id, last_synced_at, created_at, enabled, is_primary, is_builtin_free "
                  "FROM servers ORDER BY is_primary DESC, enabled DESC, name");
    if (!query.exec()) {
        return {};
    }

    QVector<Server> servers;
    while (query.next()) {
        servers.append(withDecryptedCredentials(fromQuery(query)));
    }
    return servers;
}

std::optional<Server> ServerRepository::findById(int64_t id) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, name, type, url, username, password, user_agent, "
                  "epg_url, epg_source_id, last_synced_at, created_at, enabled, is_primary, is_builtin_free "
                  "FROM servers WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }
    return withDecryptedCredentials(fromQuery(query));
}

int64_t ServerRepository::create(const Server &server) {
    if (!credentialVaultPtr_ || !credentialVaultPtr_->isReady()) {
        emit errorOccurred(QStringLiteral("Credential vault unavailable; cannot store server credentials securely"));
        return -1;
    }

    QSqlQuery query(db_);
    query.prepare("INSERT INTO servers (name, type, url, username, password, user_agent, epg_url, epg_source_id, is_builtin_free) "
                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
    query.addBindValue(server.name);
    query.addBindValue(server.type);
    query.addBindValue(server.url);
    const auto protectedServer = withProtectedCredentials(server);
    if (( !server.username.isEmpty() && protectedServer.username.isEmpty())
        || (!server.password.isEmpty() && protectedServer.password.isEmpty())) {
        emit errorOccurred(QStringLiteral("Failed to encrypt server credentials"));
        return -1;
    }
    query.addBindValue(protectedServer.username);
    query.addBindValue(protectedServer.password);
    query.addBindValue(server.userAgent);
    query.addBindValue(server.epgUrl);
    query.addBindValue(server.epgSourceId > 0 ? QVariant(static_cast<qlonglong>(server.epgSourceId)) : QVariant());
    query.addBindValue(server.isBuiltinFree ? 1 : 0);
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to create server: %1")
                               .arg(query.lastError().text()));
        return -1;
    }
    return query.lastInsertId().toLongLong();
}

bool ServerRepository::update(const Server &server) {
    if (!credentialVaultPtr_ || !credentialVaultPtr_->isReady()) {
        emit errorOccurred(QStringLiteral("Credential vault unavailable; cannot update server credentials securely"));
        return false;
    }

    QSqlQuery query(db_);
    query.prepare("UPDATE servers SET name = ?, type = ?, url = ?, username = ?, "
                  "password = ?, user_agent = ?, epg_url = ?, epg_source_id = ?, is_builtin_free = ? WHERE id = ?");
    query.addBindValue(server.name);
    query.addBindValue(server.type);
    query.addBindValue(server.url);
    const auto protectedServer = withProtectedCredentials(server);
    if (( !server.username.isEmpty() && protectedServer.username.isEmpty())
        || (!server.password.isEmpty() && protectedServer.password.isEmpty())) {
        emit errorOccurred(QStringLiteral("Failed to encrypt server credentials"));
        return false;
    }
    query.addBindValue(protectedServer.username);
    query.addBindValue(protectedServer.password);
    query.addBindValue(server.userAgent);
    query.addBindValue(server.epgUrl);
    query.addBindValue(server.epgSourceId > 0 ? QVariant(static_cast<qlonglong>(server.epgSourceId)) : QVariant());
    query.addBindValue(server.isBuiltinFree ? 1 : 0);
    query.addBindValue(toVariant(server.id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to update server: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool ServerRepository::remove(int64_t id) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM servers WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to remove server: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool ServerRepository::updateLastSynced(int64_t id, int64_t timestamp) {
    QSqlQuery query(db_);
    query.prepare("UPDATE servers SET last_synced_at = ? WHERE id = ?");
    query.addBindValue(toVariant(timestamp));
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to update last_synced_at: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool ServerRepository::setEnabled(int64_t id, bool enabled) {
    QSqlQuery query(db_);
    query.prepare("UPDATE servers SET enabled = ? WHERE id = ?");
    query.addBindValue(enabled ? 1 : 0);
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set enabled: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool ServerRepository::setPrimary(int64_t id) {
    QSqlQuery query(db_);
    // Clear primary from all servers first
    if (!query.exec("UPDATE servers SET is_primary = 0")) {
        emit errorOccurred(QStringLiteral("Failed to clear primary: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    query.prepare("UPDATE servers SET is_primary = 1 WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set primary: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

int ServerRepository::count() const {
    QSqlQuery query(db_);
    if (!query.exec("SELECT COUNT(*) FROM servers") || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

Server ServerRepository::fromQuery(const QSqlQuery &query) {
    Server s;
    s.id = query.value(0).toLongLong();
    s.name = query.value(1).toString();
    s.type = query.value(2).toString();
    s.url = query.value(3).toString();
    s.username = query.value(4).toString();
    s.password = query.value(5).toString();
    s.userAgent = query.value(6).toString();
    s.epgUrl = query.value(7).toString();
    s.epgSourceId = query.value(8).toLongLong();
    s.lastSyncedAt = query.value(9).toLongLong();
    s.createdAt = query.value(10).toLongLong();
    s.enabled = query.value(11).toInt() != 0;
    s.isPrimary = query.value(12).toInt() != 0;
    s.isBuiltinFree = query.value(13).toInt() != 0;
    return s;
}

Server ServerRepository::withProtectedCredentials(Server server) const {
    if (server.username.isEmpty() && server.password.isEmpty()) {
        return server;
    }
    server.username = credentialVaultPtr_->encrypt(server.username, QStringLiteral("username"));
    server.password = credentialVaultPtr_->encrypt(server.password, QStringLiteral("password"));
    return server;
}

Server ServerRepository::withDecryptedCredentials(Server server) const {
    if (!credentialVaultPtr_ || !credentialVaultPtr_->isReady()) {
        return server;
    }
    server.username = credentialVaultPtr_->decrypt(server.username, QStringLiteral("username"));
    server.password = credentialVaultPtr_->decrypt(server.password, QStringLiteral("password"));
    return server;
}

bool ServerRepository::migrateCredentialStorage() {
    if (!credentialVaultPtr_ || !credentialVaultPtr_->isReady()) {
        return false;
    }

    QSqlQuery query(db_);
    if (!query.exec("SELECT id, username, password FROM servers")) {
        return false;
    }

    QVector<QPair<qlonglong, QString>> usernameUpdates;
    QVector<QPair<qlonglong, QString>> passwordUpdates;
    while (query.next()) {
        const auto id = query.value(0).toLongLong();
        const auto username = query.value(1).toString();
        const auto password = query.value(2).toString();

        const auto encryptedUsername = credentialVaultPtr_->isEncryptedValue(username)
            ? username
            : credentialVaultPtr_->encrypt(username, QStringLiteral("username"));
        const auto encryptedPassword = credentialVaultPtr_->isEncryptedValue(password)
            ? password
            : credentialVaultPtr_->encrypt(password, QStringLiteral("password"));

        if (!encryptedUsername.isEmpty() && encryptedUsername != username) {
            usernameUpdates.append({id, encryptedUsername});
        }
        if (!encryptedPassword.isEmpty() && encryptedPassword != password) {
            passwordUpdates.append({id, encryptedPassword});
        }
    }

    if (usernameUpdates.isEmpty() && passwordUpdates.isEmpty()) {
        return true;
    }

    qInfo("Migrating plaintext server credentials to encrypted storage");
    if (!db_.transaction()) {
        return false;
    }

    QSqlQuery update(db_);
    update.prepare("UPDATE servers SET username = ? WHERE id = ?");
    for (const auto &row : usernameUpdates) {
        update.bindValue(0, row.second);
        update.bindValue(1, row.first);
        if (!update.exec()) {
            db_.rollback();
            return false;
        }
    }

    update.prepare("UPDATE servers SET password = ? WHERE id = ?");
    for (const auto &row : passwordUpdates) {
        update.bindValue(0, row.second);
        update.bindValue(1, row.first);
        if (!update.exec()) {
            db_.rollback();
            return false;
        }
    }

    if (!db_.commit()) {
        db_.rollback();
        return false;
    }
    return true;
}

bool ServerRepository::setEpgSource(int64_t id, int64_t epgSourceId) {
    QSqlQuery query(db_);
    query.prepare("UPDATE servers SET epg_source_id = ? WHERE id = ?");
    query.addBindValue(epgSourceId > 0 ? QVariant(static_cast<qlonglong>(epgSourceId)) : QVariant());
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set EPG source: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

} // namespace iptvxs
