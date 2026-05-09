// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/favorite_repository.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QUrl>

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

FavoriteRepository::FavoriteRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(db) {}

QVector<Favorite> FavoriteRepository::findAll() const {
    QVector<Favorite> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT f.id, f.channel_id, f.position, f.added_at,
               c.id, c.server_id, c.category_id, c.external_id,
               c.name, c.stream_url, c.logo_url, c.epg_channel_id,
               c.type, c.added_at, c.first_seen_at,
               c.tv_archive, c.tv_archive_duration
        FROM favorites f
        JOIN channels c ON c.id = f.channel_id
        JOIN servers s ON s.id = c.server_id AND s.enabled = 1
        WHERE f.deleted_at IS NULL
        ORDER BY f.position ASC
    )");

    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        Favorite fav;
        fav.id = q.value(0).toLongLong();
        fav.channelId = q.value(1).toLongLong();
        fav.position = q.value(2).toInt();
        fav.addedAt = q.value(3).toLongLong();

        fav.channel.id = q.value(4).toLongLong();
        fav.channel.serverId = q.value(5).toLongLong();
        fav.channel.categoryId = q.value(6).toLongLong();
        fav.channel.externalId = q.value(7).toString();
        fav.channel.name = q.value(8).toString();
        fav.channel.streamUrl = sanitizeRemoteUrl(q.value(9).toString());
        fav.channel.logoUrl = sanitizeRemoteUrl(q.value(10).toString());
        fav.channel.epgChannelId = q.value(11).toString();
        fav.channel.type = q.value(12).toString();
        fav.channel.addedAt = q.value(13).toLongLong();
        fav.channel.firstSeenAt = q.value(14).toLongLong();
        fav.channel.tvArchive = q.value(15).toInt();
        fav.channel.tvArchiveDuration = q.value(16).toInt();

        results.append(fav);
    }

    return results;
}

bool FavoriteRepository::isFavorite(int64_t channelId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT 1 FROM favorites WHERE channel_id = ? AND deleted_at IS NULL");
    q.addBindValue(static_cast<qlonglong>(channelId));

    if (!q.exec()) {
        return false;
    }

    return q.next();
}

bool FavoriteRepository::add(int64_t channelId) {
    if (isFavorite(channelId)) {
        return true;
    }

    if (!db_.transaction()) {
        emit errorOccurred(QStringLiteral("Failed to start favorite insert transaction"));
        return false;
    }

    QSqlQuery shift(db_);
    if (!shift.exec("UPDATE favorites "
                    "SET position = position + 1, updated_at = strftime('%s', 'now') "
                    "WHERE deleted_at IS NULL")) {
        db_.rollback();
        emit errorOccurred(
            QStringLiteral("Failed to shift favorite positions: %1").arg(shift.lastError().text()));
        return false;
    }

    // Revive a tombstoned row if one exists, else INSERT new.
    QSqlQuery revive(db_);
    revive.prepare("UPDATE favorites SET position = 0, deleted_at = NULL, "
                   "added_at = strftime('%s', 'now'), updated_at = strftime('%s', 'now') "
                   "WHERE channel_id = ? AND deleted_at IS NOT NULL");
    revive.addBindValue(static_cast<qlonglong>(channelId));
    if (!revive.exec()) {
        db_.rollback();
        emit errorOccurred(
            QStringLiteral("Failed to revive favorite: %1").arg(revive.lastError().text()));
        return false;
    }
    if (revive.numRowsAffected() == 0) {
        QSqlQuery q(db_);
        q.prepare("INSERT INTO favorites (channel_id, position, added_at, updated_at) "
                  "VALUES (?, 0, strftime('%s', 'now'), strftime('%s', 'now'))");
        q.addBindValue(static_cast<qlonglong>(channelId));
        if (!q.exec()) {
            db_.rollback();
            emit errorOccurred(
                QStringLiteral("Failed to add favorite: %1").arg(q.lastError().text()));
            return false;
        }
    }

    if (!db_.commit()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to commit favorite insert"));
        return false;
    }

    emit favoritesChanged();
    return true;
}

bool FavoriteRepository::remove(int64_t channelId) {
    // Tombstone instead of physical delete so the change syncs to other
    // devices. GC sweeps very-old tombstones periodically.
    QSqlQuery q(db_);
    q.prepare("UPDATE favorites "
              "SET deleted_at = strftime('%s', 'now'), updated_at = strftime('%s', 'now') "
              "WHERE channel_id = ? AND deleted_at IS NULL");
    q.addBindValue(static_cast<qlonglong>(channelId));

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to remove favorite: %1").arg(q.lastError().text()));
        return false;
    }

    if (q.numRowsAffected() > 0) {
        emit favoritesChanged();
    }

    return true;
}

bool FavoriteRepository::toggle(int64_t channelId) {
    if (isFavorite(channelId)) {
        return remove(channelId);
    }
    return add(channelId);
}

bool FavoriteRepository::reorder(int64_t channelId, int newPosition) {
    QSqlQuery q(db_);
    q.prepare("UPDATE favorites "
              "SET position = ?, updated_at = strftime('%s', 'now') "
              "WHERE channel_id = ? AND deleted_at IS NULL");
    q.addBindValue(newPosition);
    q.addBindValue(static_cast<qlonglong>(channelId));

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to reorder favorite: %1").arg(q.lastError().text()));
        return false;
    }

    emit favoritesChanged();
    return true;
}

int FavoriteRepository::count() const {
    QSqlQuery q(db_);
    if (!q.exec(
            "SELECT COUNT(*) "
            "FROM favorites f "
            "JOIN channels c ON c.id = f.channel_id "
            "JOIN servers s ON s.id = c.server_id AND s.enabled = 1 "
            "WHERE f.deleted_at IS NULL")) {
        return 0;
    }
    if (q.next()) {
        return q.value(0).toInt();
    }
    return 0;
}

int FavoriteRepository::nextPosition() const {
    QSqlQuery q(db_);
    if (!q.exec("SELECT COALESCE(MAX(position), -1) + 1 FROM favorites")) {
        return 0;
    }
    if (q.next()) {
        return q.value(0).toInt();
    }
    return 0;
}

} // namespace iptvxs
