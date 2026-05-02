// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/history_repository.h"

#include <QDateTime>
#include <QSqlQuery>
#include <QVariant>

namespace iptvxs {

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
        "WHERE h.id = ? "
        "LIMIT 1");
    query.addBindValue(QVariant::fromValue(id));

    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }

    HistoryEntry e;
    e.id = query.value(0).toLongLong();
    e.channelId = query.value(1).toLongLong();
    e.channelName = query.value(2).toString();
    e.channelLogo = query.value(3).toString();
    e.channelType = query.value(4).toString();
    e.watchedAt = query.value(5).toLongLong();
    e.durationSecs = query.value(6).toInt();
    e.streamUrl = query.value(7).toString();
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
            e.channelLogo = query.value(3).toString();
            e.channelType = query.value(4).toString();
            e.watchedAt = query.value(5).toLongLong();
            e.durationSecs = query.value(6).toInt();
            e.streamUrl = query.value(7).toString();
            e.positionSecs = query.value(8).toInt();
            e.totalDurationSecs = query.value(9).toInt();
            entries.append(e);
        }
    }
    return entries;
}

int HistoryRepository::count() const {
    QSqlQuery query(db_);
    query.exec("SELECT COUNT(*) FROM history");
    return query.next() ? query.value(0).toInt() : 0;
}

void HistoryRepository::removeEntry(int64_t id) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM history WHERE id = ?");
    query.addBindValue(QVariant::fromValue(id));
    query.exec();
}

void HistoryRepository::clear() {
    QSqlQuery query(db_);
    query.exec("DELETE FROM history");
}

bool HistoryRepository::hasWatched(int64_t channelId) const {
    QSqlQuery query(db_);
    query.prepare("SELECT 1 FROM history WHERE channel_id = ? LIMIT 1");
    query.addBindValue(QVariant::fromValue(channelId));

    if (!query.exec()) {
        return false;
    }

    return query.next();
}

} // namespace iptvxs
