// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/sync/snapshot.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace iptvxs {

namespace {

constexpr int kSnapshotSchemaVersion = 1;

QString protectString(CredentialVault *vault, const QString &value, const QString &purpose) {
    if (value.isEmpty() || !vault || !vault->isReady()) {
        return value;
    }
    const auto encoded = vault->encrypt(value, purpose);
    return encoded.isEmpty() ? value : encoded;
}

QString revealString(CredentialVault *vault, const QString &value, const QString &purpose) {
    if (value.isEmpty() || !vault || !vault->isReady()) {
        return value;
    }
    const auto decoded = vault->decrypt(value, purpose);
    return decoded.isEmpty() ? value : decoded;
}

QJsonArray exportFavorites(QSqlDatabase &db) {
    QJsonArray arr;
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT c.external_id, s.name, f.position, f.added_at,
               f.updated_at, f.deleted_at
        FROM favorites f
        JOIN channels c ON c.id = f.channel_id
        JOIN servers  s ON s.id = c.server_id
    )");
    if (!q.exec()) return arr;
    while (q.next()) {
        const auto externalId = q.value(0).toString();
        const auto serverName = q.value(1).toString();
        if (externalId.isEmpty() || serverName.isEmpty()) continue;
        QJsonObject row;
        row["channel_external_id"] = externalId;
        row["server_name"] = serverName;
        row["position"] = q.value(2).toInt();
        row["added_at"] = static_cast<qint64>(q.value(3).toLongLong());
        row["updated_at"] = static_cast<qint64>(q.value(4).toLongLong());
        if (!q.value(5).isNull()) {
            row["deleted_at"] = static_cast<qint64>(q.value(5).toLongLong());
        }
        arr.append(row);
    }
    return arr;
}

QJsonArray exportHistory(QSqlDatabase &db) {
    QJsonArray arr;
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT c.external_id, s.name, h.watched_at, h.duration_secs,
               h.position_secs, h.total_duration_secs,
               h.updated_at, h.deleted_at,
               h.name, h.logo_url, h.type
        FROM history h
        LEFT JOIN channels c ON c.id = h.channel_id AND h.channel_id > 0
        LEFT JOIN servers  s ON s.id = c.server_id
    )");
    if (!q.exec()) return arr;
    while (q.next()) {
        const auto externalId = q.value(0).toString();
        const auto serverName = q.value(1).toString();
        if (externalId.isEmpty() || serverName.isEmpty()) continue;
        QJsonObject row;
        row["channel_external_id"] = externalId;
        row["server_name"] = serverName;
        row["watched_at"] = static_cast<qint64>(q.value(2).toLongLong());
        row["duration_secs"] = q.value(3).toInt();
        row["position_secs"] = q.value(4).toInt();
        row["total_duration_secs"] = q.value(5).toInt();
        row["updated_at"] = static_cast<qint64>(q.value(6).toLongLong());
        if (!q.value(7).isNull()) {
            row["deleted_at"] = static_cast<qint64>(q.value(7).toLongLong());
        }
        row["name"] = q.value(8).toString();
        row["logo_url"] = q.value(9).toString();
        row["type"] = q.value(10).toString();
        arr.append(row);
    }
    return arr;
}

QJsonArray exportChannelGroups(QSqlDatabase &db) {
    QJsonArray arr;
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT name, kind, filter_scope, filter_field, filter_operator,
               filter_value, position, created_at, updated_at, deleted_at
        FROM channel_groups
    )");
    if (!q.exec()) return arr;
    while (q.next()) {
        QJsonObject row;
        row["name"] = q.value(0).toString();
        row["kind"] = q.value(1).toString();
        row["filter_scope"] = q.value(2).toString();
        row["filter_field"] = q.value(3).toString();
        row["filter_operator"] = q.value(4).toString();
        row["filter_value"] = q.value(5).toString();
        row["position"] = q.value(6).toInt();
        row["created_at"] = static_cast<qint64>(q.value(7).toLongLong());
        row["updated_at"] = static_cast<qint64>(q.value(8).toLongLong());
        if (!q.value(9).isNull()) {
            row["deleted_at"] = static_cast<qint64>(q.value(9).toLongLong());
        }
        arr.append(row);
    }
    return arr;
}

QJsonArray exportGroupMembers(QSqlDatabase &db) {
    QJsonArray arr;
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT g.name, c.external_id, s.name, gm.position,
               gm.updated_at, gm.deleted_at
        FROM group_members gm
        JOIN channel_groups g ON g.id = gm.group_id
        JOIN channels       c ON c.id = gm.channel_id
        JOIN servers        s ON s.id = c.server_id
    )");
    if (!q.exec()) return arr;
    while (q.next()) {
        QJsonObject row;
        row["group_name"] = q.value(0).toString();
        row["channel_external_id"] = q.value(1).toString();
        row["server_name"] = q.value(2).toString();
        row["position"] = q.value(3).toInt();
        row["updated_at"] = static_cast<qint64>(q.value(4).toLongLong());
        if (!q.value(5).isNull()) {
            row["deleted_at"] = static_cast<qint64>(q.value(5).toLongLong());
        }
        arr.append(row);
    }
    return arr;
}

QJsonArray exportServers(QSqlDatabase &db, CredentialVault *vault) {
    QJsonArray arr;
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT name, type, url, username, password, user_agent, epg_url,
               updated_at, deleted_at
        FROM servers
        WHERE COALESCE(is_builtin_free, 0) = 0
    )");
    if (!q.exec()) return arr;
    while (q.next()) {
        const auto name = q.value(0).toString();
        if (name.isEmpty()) continue;
        QJsonObject row;
        row["name"] = name;
        row["type"] = q.value(1).toString();
        row["url"] = q.value(2).toString();
        const auto username = revealString(vault, q.value(3).toString(),
                                           QStringLiteral("server_credentials"));
        const auto password = revealString(vault, q.value(4).toString(),
                                           QStringLiteral("server_credentials"));
        row["username_enc"] = protectString(vault, username,
                                            QStringLiteral("sync_server_credentials"));
        row["password_enc"] = protectString(vault, password,
                                            QStringLiteral("sync_server_credentials"));
        row["user_agent"] = q.value(5).toString();
        row["epg_url"] = q.value(6).toString();
        row["updated_at"] = static_cast<qint64>(q.value(7).toLongLong());
        if (!q.value(8).isNull()) {
            row["deleted_at"] = static_cast<qint64>(q.value(8).toLongLong());
        }
        arr.append(row);
    }
    return arr;
}

int64_t lookupChannelId(QSqlDatabase &db, const QString &serverName,
                        const QString &channelExternalId) {
    QSqlQuery q(db);
    q.prepare(R"(
        SELECT c.id FROM channels c
        JOIN servers s ON s.id = c.server_id AND s.name = ?
        WHERE c.external_id = ?
        LIMIT 1
    )");
    q.addBindValue(serverName);
    q.addBindValue(channelExternalId);
    if (!q.exec() || !q.next()) return 0;
    return q.value(0).toLongLong();
}

int64_t lookupGroupId(QSqlDatabase &db, const QString &name) {
    QSqlQuery q(db);
    q.prepare("SELECT id FROM channel_groups WHERE name = ? LIMIT 1");
    q.addBindValue(name);
    if (!q.exec() || !q.next()) return 0;
    return q.value(0).toLongLong();
}

bool importFavorite(QSqlDatabase &db, const QJsonObject &row,
                    SnapshotMergeStats &stats) {
    const auto serverName = row.value("server_name").toString();
    const auto channelExternalId = row.value("channel_external_id").toString();
    if (serverName.isEmpty() || channelExternalId.isEmpty()) return false;
    const auto channelId = lookupChannelId(db, serverName, channelExternalId);
    if (channelId == 0) return false;

    const auto remoteUpdated = row.value("updated_at").toVariant().toLongLong();
    const auto remoteDeleted = row.contains("deleted_at")
                                   ? row.value("deleted_at").toVariant().toLongLong()
                                   : 0;
    const auto remotePosition = row.value("position").toInt();
    const auto remoteAddedAt = row.value("added_at").toVariant().toLongLong();

    QSqlQuery probe(db);
    probe.prepare("SELECT id, updated_at FROM favorites WHERE channel_id = ?");
    probe.addBindValue(static_cast<qlonglong>(channelId));
    bool exists = probe.exec() && probe.next();

    if (exists) {
        const auto localUpdated = probe.value(1).toLongLong();
        if (remoteUpdated <= localUpdated) return false;
        QSqlQuery upd(db);
        upd.prepare("UPDATE favorites SET position = ?, added_at = ?, "
                    "updated_at = ?, deleted_at = ? WHERE id = ?");
        upd.addBindValue(remotePosition);
        upd.addBindValue(static_cast<qlonglong>(remoteAddedAt));
        upd.addBindValue(static_cast<qlonglong>(remoteUpdated));
        upd.addBindValue(remoteDeleted == 0 ? QVariant() : QVariant(static_cast<qlonglong>(remoteDeleted)));
        upd.addBindValue(probe.value(0));
        if (!upd.exec()) return false;
        if (remoteDeleted != 0) stats.tombstonesApplied++;
        else stats.favoritesPulled++;
        return true;
    }
    if (remoteDeleted != 0) return false;
    QSqlQuery ins(db);
    ins.prepare("INSERT INTO favorites (channel_id, position, added_at, updated_at) "
                "VALUES (?, ?, ?, ?)");
    ins.addBindValue(static_cast<qlonglong>(channelId));
    ins.addBindValue(remotePosition);
    ins.addBindValue(static_cast<qlonglong>(remoteAddedAt));
    ins.addBindValue(static_cast<qlonglong>(remoteUpdated));
    if (!ins.exec()) return false;
    stats.favoritesPulled++;
    return true;
}

bool importHistory(QSqlDatabase &db, const QJsonObject &row,
                   SnapshotMergeStats &stats) {
    const auto serverName = row.value("server_name").toString();
    const auto channelExternalId = row.value("channel_external_id").toString();
    if (serverName.isEmpty() || channelExternalId.isEmpty()) return false;
    const auto channelId = lookupChannelId(db, serverName, channelExternalId);
    if (channelId == 0) return false;

    const auto remoteUpdated = row.value("updated_at").toVariant().toLongLong();
    const auto remoteDeleted = row.contains("deleted_at")
                                   ? row.value("deleted_at").toVariant().toLongLong()
                                   : 0;
    const auto watchedAt = row.value("watched_at").toVariant().toLongLong();
    const auto durationSecs = row.value("duration_secs").toInt();
    const auto positionSecs = row.value("position_secs").toInt();
    const auto totalDurationSecs = row.value("total_duration_secs").toInt();
    const auto cachedName = row.value("name").toString();
    const auto cachedLogo = row.value("logo_url").toString();
    const auto cachedType = row.value("type").toString();

    QSqlQuery probe(db);
    probe.prepare("SELECT id, updated_at FROM history "
                  "WHERE channel_id = ? ORDER BY watched_at DESC LIMIT 1");
    probe.addBindValue(static_cast<qlonglong>(channelId));
    bool exists = probe.exec() && probe.next();

    if (exists) {
        const auto localUpdated = probe.value(1).toLongLong();
        if (remoteUpdated <= localUpdated) return false;
        QSqlQuery upd(db);
        upd.prepare("UPDATE history SET watched_at = ?, duration_secs = ?, "
                    "position_secs = ?, total_duration_secs = ?, "
                    "name = ?, logo_url = ?, type = ?, "
                    "updated_at = ?, deleted_at = ? "
                    "WHERE id = ?");
        upd.addBindValue(static_cast<qlonglong>(watchedAt));
        upd.addBindValue(durationSecs);
        upd.addBindValue(positionSecs);
        upd.addBindValue(totalDurationSecs);
        upd.addBindValue(cachedName);
        upd.addBindValue(cachedLogo);
        upd.addBindValue(cachedType);
        upd.addBindValue(static_cast<qlonglong>(remoteUpdated));
        upd.addBindValue(remoteDeleted == 0 ? QVariant() : QVariant(static_cast<qlonglong>(remoteDeleted)));
        upd.addBindValue(probe.value(0));
        if (!upd.exec()) return false;
        if (remoteDeleted != 0) stats.tombstonesApplied++;
        else stats.historyPulled++;
        return true;
    }
    if (remoteDeleted != 0) return false;
    QSqlQuery ins(db);
    ins.prepare("INSERT INTO history (channel_id, name, logo_url, type, "
                "watched_at, duration_secs, position_secs, total_duration_secs, "
                "updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
    ins.addBindValue(static_cast<qlonglong>(channelId));
    ins.addBindValue(cachedName);
    ins.addBindValue(cachedLogo);
    ins.addBindValue(cachedType);
    ins.addBindValue(static_cast<qlonglong>(watchedAt));
    ins.addBindValue(durationSecs);
    ins.addBindValue(positionSecs);
    ins.addBindValue(totalDurationSecs);
    ins.addBindValue(static_cast<qlonglong>(remoteUpdated));
    if (!ins.exec()) return false;
    stats.historyPulled++;
    return true;
}

bool importServer(QSqlDatabase &db, CredentialVault *vault,
                  const QJsonObject &row, SnapshotMergeStats &stats) {
    const auto name = row.value("name").toString();
    if (name.isEmpty()) return false;
    const auto remoteUpdated = row.value("updated_at").toVariant().toLongLong();
    const auto remoteDeleted = row.contains("deleted_at")
                                   ? row.value("deleted_at").toVariant().toLongLong()
                                   : 0;
    const auto type = row.value("type").toString();
    const auto url = row.value("url").toString();
    const auto userAgent = row.value("user_agent").toString();
    const auto epgUrl = row.value("epg_url").toString();
    const auto username = revealString(vault, row.value("username_enc").toString(),
                                       QStringLiteral("sync_server_credentials"));
    const auto password = revealString(vault, row.value("password_enc").toString(),
                                       QStringLiteral("sync_server_credentials"));
    const auto storedUsername = protectString(vault, username,
                                              QStringLiteral("server_credentials"));
    const auto storedPassword = protectString(vault, password,
                                              QStringLiteral("server_credentials"));

    QSqlQuery probe(db);
    probe.prepare("SELECT id, updated_at FROM servers WHERE name = ?");
    probe.addBindValue(name);
    bool exists = probe.exec() && probe.next();

    if (exists) {
        const auto localUpdated = probe.value(1).toLongLong();
        if (remoteUpdated <= localUpdated) return false;
        QSqlQuery upd(db);
        upd.prepare("UPDATE servers SET type = ?, url = ?, username = ?, "
                    "password = ?, user_agent = ?, epg_url = ?, "
                    "updated_at = ?, deleted_at = ? WHERE id = ?");
        upd.addBindValue(type);
        upd.addBindValue(url);
        upd.addBindValue(storedUsername);
        upd.addBindValue(storedPassword);
        upd.addBindValue(userAgent);
        upd.addBindValue(epgUrl);
        upd.addBindValue(static_cast<qlonglong>(remoteUpdated));
        upd.addBindValue(remoteDeleted == 0 ? QVariant() : QVariant(static_cast<qlonglong>(remoteDeleted)));
        upd.addBindValue(probe.value(0));
        if (!upd.exec()) return false;
        if (remoteDeleted != 0) stats.tombstonesApplied++;
        else stats.serversPulled++;
        return true;
    }
    if (remoteDeleted != 0) return false;
    QSqlQuery ins(db);
    ins.prepare("INSERT INTO servers (name, type, url, username, password, "
                "user_agent, epg_url, is_builtin_free, updated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)");
    ins.addBindValue(name);
    ins.addBindValue(type);
    ins.addBindValue(url);
    ins.addBindValue(storedUsername);
    ins.addBindValue(storedPassword);
    ins.addBindValue(userAgent);
    ins.addBindValue(epgUrl);
    ins.addBindValue(static_cast<qlonglong>(remoteUpdated));
    if (!ins.exec()) return false;
    stats.serversPulled++;
    return true;
}

bool importChannelGroup(QSqlDatabase &db, const QJsonObject &row,
                        SnapshotMergeStats &stats) {
    const auto name = row.value("name").toString();
    if (name.isEmpty()) return false;
    const auto remoteUpdated = row.value("updated_at").toVariant().toLongLong();
    const auto remoteDeleted = row.contains("deleted_at")
                                   ? row.value("deleted_at").toVariant().toLongLong()
                                   : 0;
    const auto kind = row.value("kind").toString();
    const auto filterScope = row.value("filter_scope").toString();
    const auto filterField = row.value("filter_field").toString();
    const auto filterOperator = row.value("filter_operator").toString();
    const auto filterValue = row.value("filter_value").toString();
    const auto position = row.value("position").toInt();
    const auto createdAt = row.value("created_at").toVariant().toLongLong();

    QSqlQuery probe(db);
    probe.prepare("SELECT id, updated_at FROM channel_groups WHERE name = ?");
    probe.addBindValue(name);
    bool exists = probe.exec() && probe.next();

    if (exists) {
        const auto localUpdated = probe.value(1).toLongLong();
        if (remoteUpdated <= localUpdated) return false;
        QSqlQuery upd(db);
        upd.prepare("UPDATE channel_groups SET kind = ?, filter_scope = ?, "
                    "filter_field = ?, filter_operator = ?, filter_value = ?, "
                    "position = ?, updated_at = ?, deleted_at = ? WHERE id = ?");
        upd.addBindValue(kind);
        upd.addBindValue(filterScope);
        upd.addBindValue(filterField);
        upd.addBindValue(filterOperator);
        upd.addBindValue(filterValue);
        upd.addBindValue(position);
        upd.addBindValue(static_cast<qlonglong>(remoteUpdated));
        upd.addBindValue(remoteDeleted == 0 ? QVariant() : QVariant(static_cast<qlonglong>(remoteDeleted)));
        upd.addBindValue(probe.value(0));
        if (!upd.exec()) return false;
        if (remoteDeleted != 0) stats.tombstonesApplied++;
        else stats.channelGroupsPulled++;
        return true;
    }
    if (remoteDeleted != 0) return false;
    QSqlQuery ins(db);
    ins.prepare("INSERT INTO channel_groups (name, kind, filter_scope, filter_field, "
                "filter_operator, filter_value, position, created_at, updated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
    ins.addBindValue(name);
    ins.addBindValue(kind);
    ins.addBindValue(filterScope);
    ins.addBindValue(filterField);
    ins.addBindValue(filterOperator);
    ins.addBindValue(filterValue);
    ins.addBindValue(position);
    ins.addBindValue(static_cast<qlonglong>(createdAt > 0 ? createdAt : remoteUpdated));
    ins.addBindValue(static_cast<qlonglong>(remoteUpdated));
    if (!ins.exec()) return false;
    stats.channelGroupsPulled++;
    return true;
}

bool importGroupMember(QSqlDatabase &db, const QJsonObject &row,
                       SnapshotMergeStats &stats) {
    const auto groupName = row.value("group_name").toString();
    const auto serverName = row.value("server_name").toString();
    const auto channelExternalId = row.value("channel_external_id").toString();
    if (groupName.isEmpty() || serverName.isEmpty() || channelExternalId.isEmpty()) {
        return false;
    }
    const auto groupId = lookupGroupId(db, groupName);
    const auto channelId = lookupChannelId(db, serverName, channelExternalId);
    if (groupId == 0 || channelId == 0) return false;

    const auto remoteUpdated = row.value("updated_at").toVariant().toLongLong();
    const auto remoteDeleted = row.contains("deleted_at")
                                   ? row.value("deleted_at").toVariant().toLongLong()
                                   : 0;
    const auto position = row.value("position").toInt();

    QSqlQuery probe(db);
    probe.prepare("SELECT id, updated_at FROM group_members "
                  "WHERE group_id = ? AND channel_id = ?");
    probe.addBindValue(static_cast<qlonglong>(groupId));
    probe.addBindValue(static_cast<qlonglong>(channelId));
    bool exists = probe.exec() && probe.next();

    if (exists) {
        const auto localUpdated = probe.value(1).toLongLong();
        if (remoteUpdated <= localUpdated) return false;
        QSqlQuery upd(db);
        upd.prepare("UPDATE group_members SET position = ?, updated_at = ?, "
                    "deleted_at = ? WHERE id = ?");
        upd.addBindValue(position);
        upd.addBindValue(static_cast<qlonglong>(remoteUpdated));
        upd.addBindValue(remoteDeleted == 0 ? QVariant() : QVariant(static_cast<qlonglong>(remoteDeleted)));
        upd.addBindValue(probe.value(0));
        if (!upd.exec()) return false;
        if (remoteDeleted != 0) stats.tombstonesApplied++;
        else stats.groupMembersPulled++;
        return true;
    }
    if (remoteDeleted != 0) return false;
    QSqlQuery ins(db);
    ins.prepare("INSERT INTO group_members (group_id, channel_id, position, updated_at) "
                "VALUES (?, ?, ?, ?)");
    ins.addBindValue(static_cast<qlonglong>(groupId));
    ins.addBindValue(static_cast<qlonglong>(channelId));
    ins.addBindValue(position);
    ins.addBindValue(static_cast<qlonglong>(remoteUpdated));
    if (!ins.exec()) return false;
    stats.groupMembersPulled++;
    return true;
}

} // namespace

QByteArray exportSnapshot(QSqlDatabase &db, CredentialVault *vault,
                          const QString &deviceUuid) {
    QJsonObject root;
    root["schema_version"] = kSnapshotSchemaVersion;
    root["device_uuid"] = deviceUuid;
    root["exported_at"] = static_cast<qint64>(QDateTime::currentSecsSinceEpoch());
    root["favorites"] = exportFavorites(db);
    root["history"] = exportHistory(db);
    root["channel_groups"] = exportChannelGroups(db);
    root["group_members"] = exportGroupMembers(db);
    root["servers"] = exportServers(db, vault);
    return QJsonDocument(root).toJson(QJsonDocument::Compact);
}

SnapshotMergeStats importSnapshot(QSqlDatabase &db, CredentialVault *vault,
                                  const QByteArray &json) {
    SnapshotMergeStats stats;
    QJsonParseError err;
    const auto doc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning("snapshot import: JSON parse failed: %s", qPrintable(err.errorString()));
        return stats;
    }
    const auto root = doc.object();

    if (!db.transaction()) return stats;

    for (const auto &v : root.value("servers").toArray()) {
        if (v.isObject()) importServer(db, vault, v.toObject(), stats);
    }
    for (const auto &v : root.value("channel_groups").toArray()) {
        if (v.isObject()) importChannelGroup(db, v.toObject(), stats);
    }
    for (const auto &v : root.value("favorites").toArray()) {
        if (v.isObject()) importFavorite(db, v.toObject(), stats);
    }
    for (const auto &v : root.value("history").toArray()) {
        if (v.isObject()) importHistory(db, v.toObject(), stats);
    }
    for (const auto &v : root.value("group_members").toArray()) {
        if (v.isObject()) importGroupMember(db, v.toObject(), stats);
    }

    if (!db.commit()) {
        db.rollback();
        qWarning("snapshot import: commit failed, rolling back");
        return SnapshotMergeStats{};
    }
    return stats;
}

} // namespace iptvxs
