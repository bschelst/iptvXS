// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/history_repository.h"

#include <QDateTime>
#include <QSet>
#include <QSqlQuery>
#include <QUrl>
#include <QVariant>

namespace iptvxs {

namespace {
QString sanitizeRemoteUrl(const QString &input) {
    QUrl url(input.trimmed());
    if (!url.isValid() ||
        (url.scheme() != QStringLiteral("http") && url.scheme() != QStringLiteral("https"))) {
        return {};
    }
    auto path = url.path();
    while (path.startsWith(QStringLiteral("//"))) {
        path.remove(0, 1);
    }
    url.setPath(path);
    return url.toString(QUrl::FullyEncoded);
}
} // namespace

HistoryRepository::HistoryRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

void HistoryRepository::addEntry(int64_t channelId, int durationSecs) {
    QSqlQuery query(db_);
    query.prepare(
        "INSERT INTO history (channel_id, watched_at, duration_secs) VALUES (?, ?, ?)");
    query.addBindValue(QVariant::fromValue(channelId));
    query.addBindValue(QVariant::fromValue(QDateTime::currentSecsSinceEpoch()));
    query.addBindValue(durationSecs);
    query.exec();
}

void HistoryRepository::addEntry(const QString &name, const QString &logo,
                                  const QString &type, const QString &streamUrl,
                                  int durationSecs, int64_t channelId) {
    QSqlQuery query(db_);
    query.prepare(
        "INSERT INTO history (channel_id, name, logo_url, type, stream_url, watched_at, duration_secs) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)");
    query.addBindValue(QVariant::fromValue(channelId));
    query.addBindValue(name);
    query.addBindValue(logo);
    query.addBindValue(type);
    query.addBindValue(streamUrl);
    query.addBindValue(QVariant::fromValue(QDateTime::currentSecsSinceEpoch()));
    query.addBindValue(durationSecs);
    query.exec();
}

void HistoryRepository::updatePosition(int64_t id, int positionSecs, int totalDurationSecs) {
    QSqlQuery query(db_);
    query.prepare("UPDATE history SET position_secs = ?, total_duration_secs = ?, watched_at = ? WHERE id = ?");
    query.addBindValue(positionSecs);
    query.addBindValue(totalDurationSecs);
    query.addBindValue(QVariant::fromValue(QDateTime::currentSecsSinceEpoch()));
    query.addBindValue(QVariant::fromValue(id));
    query.exec();
}

void HistoryRepository::touchEntry(int64_t id) {
    QSqlQuery query(db_);
    query.prepare("UPDATE history SET watched_at = ? WHERE id = ?");
    query.addBindValue(QVariant::fromValue(QDateTime::currentSecsSinceEpoch()));
    query.addBindValue(QVariant::fromValue(id));
    query.exec();
}

void HistoryRepository::markFinished(int64_t id) {
    QSqlQuery query(db_);
    query.prepare("UPDATE history SET position_secs = CASE WHEN total_duration_secs > 0 THEN total_duration_secs ELSE 1 END, "
                  "total_duration_secs = CASE WHEN total_duration_secs > 0 THEN total_duration_secs ELSE 1 END "
                  "WHERE id = ?");
    query.addBindValue(QVariant::fromValue(id));
    query.exec();
}

std::optional<HistoryEntry> HistoryRepository::findById(int64_t id) const {
    QSqlQuery query(db_);
    query.prepare(
        "SELECT h.id, h.channel_id, "
        "COALESCE(NULLIF(h.name, ''), c.name, 'Unknown'), "
        "COALESCE(NULLIF(h.logo_url, ''), c.logo_url, ''), "
        "COALESCE(NULLIF(h.type, ''), c.type, 'live'), "
        "h.watched_at, h.duration_secs, "
        "COALESCE(h.stream_url, c.stream_url, ''), "
        "h.position_secs, h.total_duration_secs "
        "FROM history h "
        "LEFT JOIN channels c ON c.id = h.channel_id AND h.channel_id > 0 "
        "LEFT JOIN servers s ON s.id = c.server_id "
        "WHERE h.id = ? AND h.deleted_at IS NULL AND (h.channel_id = 0 OR COALESCE(s.enabled, 1) = 1) "
        "LIMIT 1");
    query.addBindValue(QVariant::fromValue(id));

    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }

    HistoryEntry e;
    e.id = query.value(0).toLongLong();
    e.channelId = query.value(1).toLongLong();
    e.channelName = query.value(2).toString();
    e.channelLogo = sanitizeRemoteUrl(query.value(3).toString());
    e.channelType = query.value(4).toString();
    e.watchedAt = query.value(5).toLongLong();
    e.durationSecs = query.value(6).toInt();
    e.streamUrl = sanitizeRemoteUrl(query.value(7).toString());
    e.positionSecs = query.value(8).toInt();
    e.totalDurationSecs = query.value(9).toInt();
    return e;
}

QVector<HistoryEntry> HistoryRepository::findRecent(int limit, int offset) const {
    QSqlQuery query(db_);
    query.prepare(
        "SELECT h.id, h.channel_id, "
        "COALESCE(NULLIF(h.name, ''), c.name, 'Unknown'), "
        "COALESCE(NULLIF(h.logo_url, ''), c.logo_url, ''), "
        "COALESCE(NULLIF(h.type, ''), c.type, 'live'), "
        "h.watched_at, h.duration_secs, "
        "COALESCE(h.stream_url, c.stream_url, ''), "
        "h.position_secs, h.total_duration_secs "
        "FROM history h "
        "LEFT JOIN channels c ON c.id = h.channel_id AND h.channel_id > 0 "
        "LEFT JOIN servers s ON s.id = c.server_id "
        "WHERE h.deleted_at IS NULL AND (h.channel_id = 0 OR COALESCE(s.enabled, 1) = 1) "
        "ORDER BY h.watched_at DESC "
        "LIMIT ? OFFSET ?");
    query.addBindValue(limit);
    query.addBindValue(offset);

    QVector<HistoryEntry> entries;
    if (query.exec()) {
        while (query.next()) {
            HistoryEntry e;
            e.id = query.value(0).toLongLong();
            e.channelId = query.value(1).toLongLong();
            e.channelName = query.value(2).toString();
            e.channelLogo = sanitizeRemoteUrl(query.value(3).toString());
            e.channelType = query.value(4).toString();
            e.watchedAt = query.value(5).toLongLong();
            e.durationSecs = query.value(6).toInt();
            e.streamUrl = sanitizeRemoteUrl(query.value(7).toString());
            e.positionSecs = query.value(8).toInt();
            e.totalDurationSecs = query.value(9).toInt();
            entries.append(e);
        }
    }
    return entries;
}

QVector<HistoryEntry> HistoryRepository::search(const QString &query, int limit, int offset) const {
    const auto trimmed = query.trimmed();
    if (trimmed.isEmpty()) {
        return {};
    }

    QSqlQuery sql(db_);
    sql.prepare(
        "SELECT h.id, h.channel_id, "
        "COALESCE(NULLIF(h.name, ''), c.name, 'Unknown'), "
        "COALESCE(NULLIF(h.logo_url, ''), c.logo_url, ''), "
        "COALESCE(NULLIF(h.type, ''), c.type, 'live'), "
        "h.watched_at, h.duration_secs, "
        "COALESCE(h.stream_url, c.stream_url, ''), "
        "h.position_secs, h.total_duration_secs "
        "FROM history h "
        "LEFT JOIN channels c ON c.id = h.channel_id AND h.channel_id > 0 "
        "LEFT JOIN servers s ON s.id = c.server_id "
        "WHERE h.deleted_at IS NULL AND (h.channel_id = 0 OR COALESCE(s.enabled, 1) = 1) "
        "AND (COALESCE(NULLIF(h.name, ''), c.name, '') LIKE ? COLLATE NOCASE "
        "OR COALESCE(h.stream_url, c.stream_url, '') LIKE ? COLLATE NOCASE "
        "OR COALESCE(NULLIF(h.type, ''), c.type, '') LIKE ? COLLATE NOCASE "
        "OR COALESCE(NULLIF(c.name, ''), '') LIKE ? COLLATE NOCASE) "
        "ORDER BY h.watched_at DESC "
        "LIMIT ? OFFSET ?");
    const auto pattern = QStringLiteral("%%%1%%").arg(trimmed);
    sql.addBindValue(pattern);
    sql.addBindValue(pattern);
    sql.addBindValue(pattern);
    sql.addBindValue(pattern);
    sql.addBindValue(limit);
    sql.addBindValue(offset);

    QVector<HistoryEntry> entries;
    if (sql.exec()) {
        while (sql.next()) {
            HistoryEntry e;
            e.id = sql.value(0).toLongLong();
            e.channelId = sql.value(1).toLongLong();
            e.channelName = sql.value(2).toString();
            e.channelLogo = sanitizeRemoteUrl(sql.value(3).toString());
            e.channelType = sql.value(4).toString();
            e.watchedAt = sql.value(5).toLongLong();
            e.durationSecs = sql.value(6).toInt();
            e.streamUrl = sanitizeRemoteUrl(sql.value(7).toString());
            e.positionSecs = sql.value(8).toInt();
            e.totalDurationSecs = sql.value(9).toInt();
            entries.append(e);
        }
    }

    QVector<HistoryEntry> deduped;
    deduped.reserve(entries.size());
    QSet<QString> seen;
    for (const auto &entry : entries) {
        const QString key = entry.channelId > 0
            ? QStringLiteral("channel:%1").arg(entry.channelId)
            : QStringLiteral("anon:%1|%2").arg(entry.channelName, entry.streamUrl);
        if (seen.contains(key)) {
            continue;
        }
        seen.insert(key);
        deduped.append(entry);
        if (limit > 0 && deduped.size() >= limit) {
            break;
        }
    }
    return deduped;
}

int HistoryRepository::count() const {
    QSqlQuery query(db_);
    query.exec(
        "SELECT COUNT(*) "
        "FROM history h "
        "LEFT JOIN channels c ON c.id = h.channel_id AND h.channel_id > 0 "
        "LEFT JOIN servers s ON s.id = c.server_id "
        "WHERE h.deleted_at IS NULL AND (h.channel_id = 0 OR COALESCE(s.enabled, 1) = 1)");
    return query.next() ? query.value(0).toInt() : 0;
}

void HistoryRepository::removeEntry(int64_t id) {
    // Tombstone instead of physical delete so the change syncs to other devices.
    QSqlQuery query(db_);
    query.prepare("UPDATE history "
                  "SET deleted_at = strftime('%s', 'now'), updated_at = strftime('%s', 'now') "
                  "WHERE id = ? AND deleted_at IS NULL");
    query.addBindValue(QVariant::fromValue(id));
    query.exec();
}

void HistoryRepository::clear() {
    QSqlQuery query(db_);
    query.exec("UPDATE history "
               "SET deleted_at = strftime('%s', 'now'), updated_at = strftime('%s', 'now') "
               "WHERE deleted_at IS NULL");
}

bool HistoryRepository::hasWatched(int64_t channelId) const {
    QSqlQuery query(db_);
    query.prepare("SELECT 1 FROM history WHERE channel_id = ? AND deleted_at IS NULL LIMIT 1");
    query.addBindValue(QVariant::fromValue(channelId));

    if (!query.exec()) {
        return false;
    }

    return query.next();
}

} // namespace iptvxs
