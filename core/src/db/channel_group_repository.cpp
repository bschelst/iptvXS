#include "iptvxs/db/channel_group_repository.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>

namespace iptvxs {

ChannelGroupRepository::ChannelGroupRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(db) {}

QVector<ChannelGroup> ChannelGroupRepository::findAllGroups() const {
    QVector<ChannelGroup> results;
    QSqlQuery q(db_);
    if (!q.exec("SELECT id, name, position, created_at FROM channel_groups ORDER BY position ASC")) {
        return results;
    }
    while (q.next()) {
        ChannelGroup g;
        g.id = q.value(0).toLongLong();
        g.name = q.value(1).toString();
        g.position = q.value(2).toInt();
        g.createdAt = q.value(3).toLongLong();
        results.append(g);
    }
    return results;
}

bool ChannelGroupRepository::createGroup(const QString &name) {
    QSqlQuery q(db_);
    q.prepare("INSERT INTO channel_groups (name, position, created_at) VALUES (?, ?, ?)");
    q.addBindValue(name);
    q.addBindValue(nextGroupPosition());
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to create group: %1").arg(q.lastError().text()));
        return false;
    }
    emit groupsChanged();
    return true;
}

bool ChannelGroupRepository::renameGroup(int64_t id, const QString &name) {
    QSqlQuery q(db_);
    q.prepare("UPDATE channel_groups SET name = ? WHERE id = ?");
    q.addBindValue(name);
    q.addBindValue(static_cast<qlonglong>(id));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to rename group: %1").arg(q.lastError().text()));
        return false;
    }
    emit groupsChanged();
    return true;
}

bool ChannelGroupRepository::deleteGroup(int64_t id) {
    QSqlQuery q(db_);
    q.prepare("DELETE FROM channel_groups WHERE id = ?");
    q.addBindValue(static_cast<qlonglong>(id));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to delete group: %1").arg(q.lastError().text()));
        return false;
    }
    emit groupsChanged();
    return true;
}

bool ChannelGroupRepository::reorderGroup(int64_t id, int newPosition) {
    QSqlQuery q(db_);
    q.prepare("UPDATE channel_groups SET position = ? WHERE id = ?");
    q.addBindValue(newPosition);
    q.addBindValue(static_cast<qlonglong>(id));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to reorder group: %1").arg(q.lastError().text()));
        return false;
    }
    emit groupsChanged();
    return true;
}

int ChannelGroupRepository::groupCount() const {
    QSqlQuery q(db_);
    if (!q.exec("SELECT COUNT(*) FROM channel_groups")) {
        return 0;
    }
    return q.next() ? q.value(0).toInt() : 0;
}

QVector<GroupMember> ChannelGroupRepository::findMembers(int64_t groupId) const {
    QVector<GroupMember> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT gm.id, gm.group_id, gm.channel_id, gm.position,
               c.id, c.server_id, c.category_id, c.external_id,
               c.name, c.stream_url, c.logo_url, c.epg_channel_id,
               c.type, c.added_at, c.first_seen_at
        FROM group_members gm
        JOIN channels c ON c.id = gm.channel_id
        WHERE gm.group_id = ?
        ORDER BY gm.position ASC
    )");
    q.addBindValue(static_cast<qlonglong>(groupId));
    if (!q.exec()) {
        return results;
    }
    while (q.next()) {
        GroupMember m;
        m.id = q.value(0).toLongLong();
        m.groupId = q.value(1).toLongLong();
        m.channelId = q.value(2).toLongLong();
        m.position = q.value(3).toInt();
        m.channel.id = q.value(4).toLongLong();
        m.channel.serverId = q.value(5).toLongLong();
        m.channel.categoryId = q.value(6).toLongLong();
        m.channel.externalId = q.value(7).toString();
        m.channel.name = q.value(8).toString();
        m.channel.streamUrl = q.value(9).toString();
        m.channel.logoUrl = q.value(10).toString();
        m.channel.epgChannelId = q.value(11).toString();
        m.channel.type = q.value(12).toString();
        m.channel.addedAt = q.value(13).toLongLong();
        m.channel.firstSeenAt = q.value(14).toLongLong();
        results.append(m);
    }
    return results;
}

bool ChannelGroupRepository::addMember(int64_t groupId, int64_t channelId) {
    if (isMember(groupId, channelId)) {
        return true;
    }
    QSqlQuery q(db_);
    q.prepare("INSERT INTO group_members (group_id, channel_id, position) VALUES (?, ?, ?)");
    q.addBindValue(static_cast<qlonglong>(groupId));
    q.addBindValue(static_cast<qlonglong>(channelId));
    q.addBindValue(nextMemberPosition(groupId));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to add member: %1").arg(q.lastError().text()));
        return false;
    }
    emit groupsChanged();
    return true;
}

bool ChannelGroupRepository::removeMember(int64_t groupId, int64_t channelId) {
    QSqlQuery q(db_);
    q.prepare("DELETE FROM group_members WHERE group_id = ? AND channel_id = ?");
    q.addBindValue(static_cast<qlonglong>(groupId));
    q.addBindValue(static_cast<qlonglong>(channelId));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to remove member: %1").arg(q.lastError().text()));
        return false;
    }
    if (q.numRowsAffected() > 0) {
        emit groupsChanged();
    }
    return true;
}

bool ChannelGroupRepository::reorderMember(int64_t groupId, int64_t channelId, int newPosition) {
    QSqlQuery q(db_);
    q.prepare("UPDATE group_members SET position = ? WHERE group_id = ? AND channel_id = ?");
    q.addBindValue(newPosition);
    q.addBindValue(static_cast<qlonglong>(groupId));
    q.addBindValue(static_cast<qlonglong>(channelId));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to reorder member: %1").arg(q.lastError().text()));
        return false;
    }
    emit groupsChanged();
    return true;
}

bool ChannelGroupRepository::isMember(int64_t groupId, int64_t channelId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT 1 FROM group_members WHERE group_id = ? AND channel_id = ?");
    q.addBindValue(static_cast<qlonglong>(groupId));
    q.addBindValue(static_cast<qlonglong>(channelId));
    if (!q.exec()) {
        return false;
    }
    return q.next();
}

int ChannelGroupRepository::memberCount(int64_t groupId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT COUNT(*) FROM group_members WHERE group_id = ?");
    q.addBindValue(static_cast<qlonglong>(groupId));
    if (!q.exec()) {
        return 0;
    }
    return q.next() ? q.value(0).toInt() : 0;
}

int ChannelGroupRepository::nextGroupPosition() const {
    QSqlQuery q(db_);
    if (!q.exec("SELECT COALESCE(MAX(position), -1) + 1 FROM channel_groups")) {
        return 0;
    }
    return q.next() ? q.value(0).toInt() : 0;
}

int ChannelGroupRepository::nextMemberPosition(int64_t groupId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT COALESCE(MAX(position), -1) + 1 FROM group_members WHERE group_id = ?");
    q.addBindValue(static_cast<qlonglong>(groupId));
    if (!q.exec()) {
        return 0;
    }
    return q.next() ? q.value(0).toInt() : 0;
}

} // namespace iptvxs
