// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/epg_source_repository.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }
} // namespace

namespace iptvxs {

EpgSourceRepository::EpgSourceRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

QVector<EpgSource> EpgSourceRepository::findAll() const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, name, url, last_synced_at, created_at, enabled, is_primary "
                  "FROM epg_sources ORDER BY is_primary DESC, enabled DESC, name");
    if (!query.exec()) {
        return {};
    }

    QVector<EpgSource> sources;
    while (query.next()) {
        sources.append(fromQuery(query));
    }
    return sources;
}

std::optional<EpgSource> EpgSourceRepository::findById(int64_t id) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, name, url, last_synced_at, created_at, enabled, is_primary "
                  "FROM epg_sources WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }
    return fromQuery(query);
}

int64_t EpgSourceRepository::create(const EpgSource &source) {
    QSqlQuery query(db_);
    query.prepare("INSERT INTO epg_sources (name, url, enabled, is_primary) "
                  "VALUES (?, ?, ?, ?)");
    query.addBindValue(source.name);
    query.addBindValue(source.url);
    query.addBindValue(source.enabled ? 1 : 0);
    query.addBindValue(source.isPrimary ? 1 : 0);
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to create EPG source: %1")
                               .arg(query.lastError().text()));
        return -1;
    }
    return query.lastInsertId().toLongLong();
}

bool EpgSourceRepository::update(const EpgSource &source) {
    QSqlQuery query(db_);
    query.prepare("UPDATE epg_sources SET name = ?, url = ?, enabled = ?, is_primary = ? "
                  "WHERE id = ?");
    query.addBindValue(source.name);
    query.addBindValue(source.url);
    query.addBindValue(source.enabled ? 1 : 0);
    query.addBindValue(source.isPrimary ? 1 : 0);
    query.addBindValue(toVariant(source.id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to update EPG source: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool EpgSourceRepository::remove(int64_t id) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM epg_sources WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to remove EPG source: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool EpgSourceRepository::updateLastSynced(int64_t id, int64_t timestamp) {
    QSqlQuery query(db_);
    query.prepare("UPDATE epg_sources SET last_synced_at = ? WHERE id = ?");
    query.addBindValue(toVariant(timestamp));
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to update EPG last_synced_at: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool EpgSourceRepository::setEnabled(int64_t id, bool enabled) {
    QSqlQuery query(db_);
    query.prepare("UPDATE epg_sources SET enabled = ? WHERE id = ?");
    query.addBindValue(enabled ? 1 : 0);
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set EPG source enabled: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

bool EpgSourceRepository::setPrimary(int64_t id) {
    QSqlQuery query(db_);
    if (!query.exec("UPDATE epg_sources SET is_primary = 0")) {
        emit errorOccurred(QStringLiteral("Failed to clear primary EPG source: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    query.prepare("UPDATE epg_sources SET is_primary = 1 WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set primary EPG source: %1")
                               .arg(query.lastError().text()));
        return false;
    }
    return query.numRowsAffected() > 0;
}

int EpgSourceRepository::count() const {
    QSqlQuery query(db_);
    if (!query.exec("SELECT COUNT(*) FROM epg_sources") || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

EpgSource EpgSourceRepository::fromQuery(const QSqlQuery &query) {
    EpgSource s;
    s.id = query.value(0).toLongLong();
    s.name = query.value(1).toString();
    s.url = query.value(2).toString();
    s.lastSyncedAt = query.value(3).toLongLong();
    s.createdAt = query.value(4).toLongLong();
    s.enabled = query.value(5).toInt() != 0;
    s.isPrimary = query.value(6).toInt() != 0;
    return s;
}

} // namespace iptvxs
