#include "iptvxs/db/server_repository.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }
} // namespace

namespace iptvxs {

ServerRepository::ServerRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

QVector<Server> ServerRepository::findAll() const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, name, type, url, username, password, user_agent, "
                  "epg_url, last_synced_at, created_at, enabled, is_primary "
                  "FROM servers ORDER BY name");
    if (!query.exec()) {
        return {};
    }

    QVector<Server> servers;
    while (query.next()) {
        servers.append(fromQuery(query));
    }
    return servers;
}

std::optional<Server> ServerRepository::findById(int64_t id) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, name, type, url, username, password, user_agent, "
                  "epg_url, last_synced_at, created_at, enabled, is_primary "
                  "FROM servers WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }
    return fromQuery(query);
}

int64_t ServerRepository::create(const Server &server) {
    QSqlQuery query(db_);
    query.prepare("INSERT INTO servers (name, type, url, username, password, user_agent, epg_url) "
                  "VALUES (?, ?, ?, ?, ?, ?, ?)");
    query.addBindValue(server.name);
    query.addBindValue(server.type);
    query.addBindValue(server.url);
    query.addBindValue(server.username);
    query.addBindValue(server.password);
    query.addBindValue(server.userAgent);
    query.addBindValue(server.epgUrl);
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to create server: %1")
                               .arg(query.lastError().text()));
        return -1;
    }
    return query.lastInsertId().toLongLong();
}

bool ServerRepository::update(const Server &server) {
    QSqlQuery query(db_);
    query.prepare("UPDATE servers SET name = ?, type = ?, url = ?, username = ?, "
                  "password = ?, user_agent = ?, epg_url = ? WHERE id = ?");
    query.addBindValue(server.name);
    query.addBindValue(server.type);
    query.addBindValue(server.url);
    query.addBindValue(server.username);
    query.addBindValue(server.password);
    query.addBindValue(server.userAgent);
    query.addBindValue(server.epgUrl);
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
    s.lastSyncedAt = query.value(8).toLongLong();
    s.createdAt = query.value(9).toLongLong();
    s.enabled = query.value(10).toInt() != 0;
    s.isPrimary = query.value(11).toInt() != 0;
    return s;
}

} // namespace iptvxs
