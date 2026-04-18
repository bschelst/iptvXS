#include "iptvxs/db/programme_repository.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

namespace iptvxs {

ProgrammeRepository::ProgrammeRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(db) {}

QVector<Programme> ProgrammeRepository::findByChannel(
    const QString &epgChannelId, int64_t fromTime, int64_t toTime) const {
    QVector<Programme> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, epg_channel_id, title, description, start_time, end_time
        FROM programmes
        WHERE epg_channel_id = ?
          AND end_time > ?
          AND start_time < ?
        ORDER BY start_time ASC
    )");
    q.addBindValue(epgChannelId);
    q.addBindValue(static_cast<qlonglong>(fromTime));
    q.addBindValue(static_cast<qlonglong>(toTime));

    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        Programme p;
        p.id = q.value(0).toLongLong();
        p.epgChannelId = q.value(1).toString();
        p.title = q.value(2).toString();
        p.description = q.value(3).toString();
        p.startTime = q.value(4).toLongLong();
        p.endTime = q.value(5).toLongLong();
        results.append(p);
    }

    return results;
}

QHash<QString, QVector<Programme>> ProgrammeRepository::findByTimeWindow(
    int64_t fromTime, int64_t toTime) const {
    QHash<QString, QVector<Programme>> result;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, epg_channel_id, title, description, start_time, end_time
        FROM programmes
        WHERE end_time > ? AND start_time < ?
        ORDER BY epg_channel_id, start_time ASC
    )");
    q.addBindValue(static_cast<qlonglong>(fromTime));
    q.addBindValue(static_cast<qlonglong>(toTime));

    if (!q.exec()) {
        return result;
    }

    while (q.next()) {
        Programme p;
        p.id = q.value(0).toLongLong();
        p.epgChannelId = q.value(1).toString();
        p.title = q.value(2).toString();
        p.description = q.value(3).toString();
        p.startTime = q.value(4).toLongLong();
        p.endTime = q.value(5).toLongLong();
        result[p.epgChannelId].append(std::move(p));
    }

    return result;
}

QVector<Programme> ProgrammeRepository::findCurrent(
    const QString &epgChannelId) const {
    int64_t now = QDateTime::currentSecsSinceEpoch();
    QVector<Programme> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, epg_channel_id, title, description, start_time, end_time
        FROM programmes
        WHERE epg_channel_id = ?
          AND start_time <= ?
          AND end_time > ?
        ORDER BY start_time ASC
        LIMIT 1
    )");
    q.addBindValue(epgChannelId);
    q.addBindValue(static_cast<qlonglong>(now));
    q.addBindValue(static_cast<qlonglong>(now));

    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        Programme p;
        p.id = q.value(0).toLongLong();
        p.epgChannelId = q.value(1).toString();
        p.title = q.value(2).toString();
        p.description = q.value(3).toString();
        p.startTime = q.value(4).toLongLong();
        p.endTime = q.value(5).toLongLong();
        results.append(p);
    }

    return results;
}

std::optional<Programme> ProgrammeRepository::findById(int64_t id) const {
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, epg_channel_id, title, description, start_time, end_time
        FROM programmes WHERE id = ?
    )");
    q.addBindValue(static_cast<qlonglong>(id));

    if (!q.exec() || !q.next()) {
        return std::nullopt;
    }

    Programme p;
    p.id = q.value(0).toLongLong();
    p.epgChannelId = q.value(1).toString();
    p.title = q.value(2).toString();
    p.description = q.value(3).toString();
    p.startTime = q.value(4).toLongLong();
    p.endTime = q.value(5).toLongLong();
    return p;
}

void ProgrammeRepository::batchUpsert(const QVector<Programme> &programmes) {
    if (programmes.isEmpty()) {
        return;
    }

    db_.transaction();

    QSqlQuery q(db_);
    q.prepare(R"(
        INSERT INTO programmes (epg_channel_id, title, description, start_time, end_time)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(epg_channel_id, start_time)
        DO UPDATE SET
            title = excluded.title,
            description = excluded.description,
            end_time = excluded.end_time
    )");

    int count = 0;
    for (const auto &p : programmes) {
        q.addBindValue(p.epgChannelId);
        q.addBindValue(p.title);
        q.addBindValue(p.description);
        q.addBindValue(static_cast<qlonglong>(p.startTime));
        q.addBindValue(static_cast<qlonglong>(p.endTime));

        if (!q.exec()) {
            emit errorOccurred(
                QStringLiteral("Failed to upsert programme: %1")
                    .arg(q.lastError().text()));
        }

        if (++count % kBatchSize == 0) {
            db_.commit();
            db_.transaction();
        }
    }

    db_.commit();
}

bool ProgrammeRepository::deleteOlderThan(int64_t timestamp) {
    QSqlQuery q(db_);
    q.prepare("DELETE FROM programmes WHERE end_time < ?");
    q.addBindValue(static_cast<qlonglong>(timestamp));

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to delete old programmes: %1")
                .arg(q.lastError().text()));
        return false;
    }

    return true;
}

int ProgrammeRepository::count() const {
    QSqlQuery q(db_);
    if (!q.exec("SELECT COUNT(*) FROM programmes")) {
        return 0;
    }
    if (q.next()) {
        return q.value(0).toInt();
    }
    return 0;
}

} // namespace iptvxs
