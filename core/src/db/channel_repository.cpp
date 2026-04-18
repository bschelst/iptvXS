#include "iptvxs/db/channel_repository.h"

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
                  "logo_url, epg_channel_id, type, added_at "
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
                  "logo_url, epg_channel_id, type, added_at "
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
                  "logo_url, epg_channel_id, type, added_at "
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
    query.prepare("SELECT id, server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at "
                  "FROM channels WHERE server_id = ? AND name LIKE ? COLLATE NOCASE "
                  "ORDER BY name COLLATE NOCASE LIMIT ? OFFSET ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(QStringLiteral("%%%1%%").arg(searchQuery));
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
                  "logo_url, epg_channel_id, type, added_at "
                  "FROM channels WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }
    return fromQuery(query);
}

void ChannelRepository::batchUpsert(const QVector<Channel> &channels) {
    if (channels.isEmpty()) {
        return;
    }

    db_.transaction();
    QSqlQuery query(db_);
    query.prepare("INSERT OR REPLACE INTO channels "
                  "(server_id, category_id, external_id, name, stream_url, "
                  "logo_url, epg_channel_id, type, added_at) "
                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");

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
    query.prepare("SELECT COUNT(*) FROM channels WHERE server_id = ? "
                  "AND name LIKE ? COLLATE NOCASE");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(QStringLiteral("%%%1%%").arg(searchQuery));
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
    return ch;
}

} // namespace iptvxs
