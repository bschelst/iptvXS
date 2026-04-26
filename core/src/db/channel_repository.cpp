// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/channel_repository.h"

#include <QCoreApplication>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }
} // namespace

namespace iptvxs {

ChannelRepository::ChannelRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

QVector<Channel> ChannelRepository::findByServer(int64_t serverId, int limit, int offset) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at, first_seen_at "
                  "FROM channels WHERE server_id = ? ORDER BY name COLLATE NOCASE "
                  "LIMIT ? OFFSET ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(limit);
    query.addBindValue(offset);

    if (!query.exec()) {
        return {};
    }

    QVector<Channel> channels;
    channels.reserve(limit);
    while (query.next()) {
        channels.append(fromQuery(query));
    }
    return channels;
}

QVector<Channel> ChannelRepository::findByCategory(int64_t categoryId, int limit, int offset) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at, first_seen_at "
                  "FROM channels WHERE category_id = ? ORDER BY name COLLATE NOCASE "
                  "LIMIT ? OFFSET ?");
    query.addBindValue(toVariant(categoryId));
    query.addBindValue(limit);
    query.addBindValue(offset);

    if (!query.exec()) {
        return {};
    }

    QVector<Channel> channels;
    channels.reserve(limit);
    while (query.next()) {
        channels.append(fromQuery(query));
    }
    return channels;
}

QVector<Channel> ChannelRepository::findByServerAndType(int64_t serverId, const QString &type,
                                                         int limit, int offset) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at, first_seen_at "
                  "FROM channels WHERE server_id = ? AND type = ? "
                  "ORDER BY name COLLATE NOCASE LIMIT ? OFFSET ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(type);
    query.addBindValue(limit > 0 ? limit : -1);
    query.addBindValue(offset);

    if (!query.exec()) {
        return {};
    }

    QVector<Channel> channels;
    while (query.next()) {
        channels.append(fromQuery(query));
    }
    return channels;
}

QVector<Channel> ChannelRepository::search(int64_t serverId, const QString &searchQuery,
                                            int limit, int offset) const {
    QSqlQuery query(db_);
    query.prepare("SELECT c.id, c.server_id, c.category_id, c.external_id, c.name, c.stream_url, "
                  "c.logo_url, c.epg_channel_id, c.type, c.added_at, c.first_seen_at "
                  "FROM channels c LEFT JOIN categories cat ON c.category_id = cat.id "
                  "WHERE c.server_id = ? AND (c.name LIKE ? COLLATE NOCASE OR cat.name LIKE ? COLLATE NOCASE) "
                  "ORDER BY c.name COLLATE NOCASE LIMIT ? OFFSET ?");
    auto pattern = QStringLiteral("%%%1%%").arg(searchQuery);
    query.addBindValue(toVariant(serverId));
    query.addBindValue(pattern);
    query.addBindValue(pattern);
    query.addBindValue(limit);
    query.addBindValue(offset);

    if (!query.exec()) {
        return {};
    }

    QVector<Channel> channels;
    channels.reserve(limit);
    while (query.next()) {
        channels.append(fromQuery(query));
    }
    return channels;
}

QVector<Channel> ChannelRepository::searchWithType(int64_t serverId, const QString &searchQuery,
                                                    const QString &type, int limit, int offset) const {
    QSqlQuery query(db_);
    query.prepare("SELECT c.id, c.server_id, c.category_id, c.external_id, c.name, c.stream_url, "
                  "c.logo_url, c.epg_channel_id, c.type, c.added_at, c.first_seen_at "
                  "FROM channels c LEFT JOIN categories cat ON c.category_id = cat.id "
                  "WHERE c.server_id = ? AND c.type = ? AND (c.name LIKE ? COLLATE NOCASE OR cat.name LIKE ? COLLATE NOCASE) "
                  "ORDER BY c.name COLLATE NOCASE LIMIT ? OFFSET ?");
    auto pattern = QStringLiteral("%%%1%%").arg(searchQuery);
    query.addBindValue(toVariant(serverId));
    query.addBindValue(type);
    query.addBindValue(pattern);
    query.addBindValue(pattern);
    query.addBindValue(limit);
    query.addBindValue(offset);

    if (!query.exec()) {
        return {};
    }

    QVector<Channel> channels;
    channels.reserve(limit);
    while (query.next()) {
        channels.append(fromQuery(query));
    }
    return channels;
}

std::optional<Channel> ChannelRepository::findById(int64_t id) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at, first_seen_at "
                  "FROM channels WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }
    return fromQuery(query);
}

QVector<Channel> ChannelRepository::searchAll(const QString &searchQuery, int limit) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at, first_seen_at "
                  "FROM channels WHERE name LIKE ? COLLATE NOCASE "
                  "ORDER BY name COLLATE NOCASE LIMIT ?");
    auto pattern = QStringLiteral("%%%1%%").arg(searchQuery);
    query.addBindValue(pattern);
    query.addBindValue(limit);

    if (!query.exec()) {
        return {};
    }

    QVector<Channel> channels;
    channels.reserve(limit);
    while (query.next()) {
        channels.append(fromQuery(query));
    }
    return channels;
}

void ChannelRepository::batchUpsert(const QVector<Channel> &channels) {
    if (channels.isEmpty()) {
        return;
    }

    db_.transaction();
    QSqlQuery query(db_);
    query.prepare("INSERT INTO channels "
                  "(server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at, first_seen_at) "
                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, strftime('%s', 'now')) "
                  "ON CONFLICT(server_id, external_id, type) DO UPDATE SET "
                  "category_id = excluded.category_id, "
                  "name = excluded.name, "
                  "stream_url = excluded.stream_url, "
                  "logo_url = excluded.logo_url, "
                  "epg_channel_id = excluded.epg_channel_id, "
                  "added_at = excluded.added_at");

    int processed = 0;
    for (const auto &ch : channels) {
        query.addBindValue(toVariant(ch.serverId));
        query.addBindValue(ch.categoryId > 0 ? toVariant(ch.categoryId) : QVariant());
        query.addBindValue(ch.externalId);
        query.addBindValue(ch.name);
        query.addBindValue(ch.streamUrl);
        query.addBindValue(ch.logoUrl);
        query.addBindValue(ch.epgChannelId);
        query.addBindValue(ch.type);
        query.addBindValue(ch.addedAt > 0 ? toVariant(ch.addedAt) : QVariant());
        if (!query.exec()) {
            db_.rollback();
            emit errorOccurred(QStringLiteral("Batch channel upsert failed at %1: %2")
                                   .arg(processed)
                                   .arg(query.lastError().text()));
            return;
        }
        ++processed;

        if (processed % kBatchSize == 0) {
            if (!db_.commit()) {
                emit errorOccurred(QStringLiteral("Failed to commit channel batch at %1").arg(processed));
                return;
            }
            QCoreApplication::processEvents();
            db_.transaction();
        }
    }

    if (!db_.commit()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to commit final channel batch"));
    }
}

bool ChannelRepository::deleteByServer(int64_t serverId) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM channels WHERE server_id = ?");
    query.addBindValue(toVariant(serverId));
    return query.exec();
}

void ChannelRepository::deleteByServerAndTypeWithEmptyExternalId(
    int64_t serverId, const QString &type) {
    QSqlQuery query(db_);
    query.prepare(
        "DELETE FROM channels WHERE server_id = ? AND type = ? "
        "AND (external_id IS NULL OR external_id = '')");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(type);
    query.exec();
}

int ChannelRepository::count(int64_t serverId) const {
    QSqlQuery query(db_);
    query.prepare("SELECT COUNT(*) FROM channels WHERE server_id = ?");
    query.addBindValue(toVariant(serverId));
    if (!query.exec() || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

int ChannelRepository::countByCategory(int64_t categoryId) const {
    QSqlQuery query(db_);
    query.prepare("SELECT COUNT(*) FROM channels WHERE category_id = ?");
    query.addBindValue(toVariant(categoryId));
    if (!query.exec() || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

int ChannelRepository::countBySearch(int64_t serverId, const QString &searchQuery) const {
    QSqlQuery query(db_);
    auto pattern = QStringLiteral("%%%1%%").arg(searchQuery);
    query.prepare("SELECT COUNT(*) FROM channels c LEFT JOIN categories cat ON c.category_id = cat.id "
                  "WHERE c.server_id = ? AND (c.name LIKE ? COLLATE NOCASE OR cat.name LIKE ? COLLATE NOCASE)");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(pattern);
    query.addBindValue(pattern);
    if (!query.exec() || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

int ChannelRepository::countBySearchWithType(int64_t serverId, const QString &searchQuery,
                                              const QString &type) const {
    QSqlQuery query(db_);
    auto pattern = QStringLiteral("%%%1%%").arg(searchQuery);
    query.prepare("SELECT COUNT(*) FROM channels c LEFT JOIN categories cat ON c.category_id = cat.id "
                  "WHERE c.server_id = ? AND c.type = ? AND (c.name LIKE ? COLLATE NOCASE OR cat.name LIKE ? COLLATE NOCASE)");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(type);
    query.addBindValue(pattern);
    query.addBindValue(pattern);
    if (!query.exec() || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

int ChannelRepository::countByServerAndType(int64_t serverId, const QString &type) const {
    QSqlQuery query(db_);
    query.prepare("SELECT COUNT(*) FROM channels WHERE server_id = ? AND type = ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(type);
    if (!query.exec() || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

QVector<Channel> ChannelRepository::findRecentlyAdded(int64_t serverId, int64_t sinceSecs,
                                                       int limit, int offset) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at, first_seen_at "
                  "FROM channels WHERE server_id = ? AND first_seen_at > ? "
                  "ORDER BY first_seen_at DESC LIMIT ? OFFSET ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(toVariant(sinceSecs));
    query.addBindValue(limit);
    query.addBindValue(offset);

    if (!query.exec()) {
        return {};
    }

    QVector<Channel> channels;
    channels.reserve(limit);
    while (query.next()) {
        channels.append(fromQuery(query));
    }
    return channels;
}

int ChannelRepository::countRecentlyAdded(int64_t serverId, int64_t sinceSecs) const {
    QSqlQuery query(db_);
    query.prepare("SELECT COUNT(*) FROM channels WHERE server_id = ? AND first_seen_at > ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(toVariant(sinceSecs));
    if (!query.exec() || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

Channel ChannelRepository::fromQuery(const QSqlQuery &query) {
    Channel ch;
    ch.id = query.value(0).toLongLong();
    ch.serverId = query.value(1).toLongLong();
    ch.categoryId = query.value(2).toLongLong();
    ch.externalId = query.value(3).toString();
    ch.name = query.value(4).toString();
    ch.streamUrl = query.value(5).toString();
    ch.logoUrl = query.value(6).toString();
    ch.epgChannelId = query.value(7).toString();
    ch.type = query.value(8).toString();
    ch.addedAt = query.value(9).toLongLong();
    ch.firstSeenAt = query.value(10).toLongLong();
    return ch;
}

} // namespace iptvxs
