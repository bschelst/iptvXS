#include "iptvxs/db/favorite_repository.h"

#include <QSqlError>
#include <QSqlQuery>

namespace iptvxs {

FavoriteRepository::FavoriteRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(db) {}

QVector<Favorite> FavoriteRepository::findAll() const {
    QVector<Favorite> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT f.id, f.channel_id, f.position, f.added_at,
               c.id, c.server_id, c.category_id, c.external_id,
               c.name, c.stream_url, c.logo_url, c.epg_channel_id,
               c.type, c.added_at
        FROM favorites f
        JOIN channels c ON c.id = f.channel_id
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
        fav.channel.streamUrl = q.value(9).toString();
        fav.channel.logoUrl = q.value(10).toString();
        fav.channel.epgChannelId = q.value(11).toString();
        fav.channel.type = q.value(12).toString();
        fav.channel.addedAt = q.value(13).toLongLong();

        results.append(fav);
    }

    return results;
}

bool FavoriteRepository::isFavorite(int64_t channelId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT 1 FROM favorites WHERE channel_id = ?");
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

    QSqlQuery q(db_);
    q.prepare(R"(
        INSERT INTO favorites (channel_id, position)
        VALUES (?, ?)
    )");
    q.addBindValue(static_cast<qlonglong>(channelId));
    q.addBindValue(nextPosition());

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to add favorite: %1").arg(q.lastError().text()));
        return false;
    }

    emit favoritesChanged();
    return true;
}

bool FavoriteRepository::remove(int64_t channelId) {
    QSqlQuery q(db_);
    q.prepare("DELETE FROM favorites WHERE channel_id = ?");
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
    q.prepare("UPDATE favorites SET position = ? WHERE channel_id = ?");
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
    if (!q.exec("SELECT COUNT(*) FROM favorites")) {
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
