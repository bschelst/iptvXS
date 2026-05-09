// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/channel_group_repository.h"

#include <QDateTime>
#include <QSqlError>
#include <QSqlQuery>
#include <QUrl>
#include <QVariant>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }

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

QString normalizeKind(const QString &kind) {
    return kind == QLatin1String("dynamic") ? QStringLiteral("dynamic") : QStringLiteral("static");
}

QString normalizeScope(const QString &scope) {
    if (scope == QLatin1String("live") || scope == QLatin1String("vod")
        || scope == QLatin1String("series")) {
        return scope;
    }
    return QStringLiteral("any");
}

QString normalizeField(const QString &field) {
    if (field == QLatin1String("category") || field == QLatin1String("server")) {
        return field;
    }
    return QStringLiteral("name");
}

QString normalizeOperator(const QString &op) {
    if (op == QLatin1String("not_contains") || op == QLatin1String("starts_with")
        || op == QLatin1String("equals")) {
        return op;
    }
    return QStringLiteral("contains");
}

QString fieldExpression(const QString &field) {
    if (field == QLatin1String("category")) {
        return QStringLiteral("COALESCE(cat.name, '')");
    }
    if (field == QLatin1String("server")) {
        return QStringLiteral("COALESCE(s.name, '')");
    }
    return QStringLiteral("COALESCE(c.name, '')");
}

struct DynamicQuery {
    QString sql;
    QVector<QVariant> binds;
};

DynamicQuery buildDynamicQuery(const iptvxs::ChannelGroup &group, bool countOnly) {
    DynamicQuery result;
    result.sql = countOnly ? QStringLiteral("SELECT COUNT(*)") :
                             QStringLiteral("SELECT c.id, c.server_id, c.category_id, c.external_id, "
                                            "c.name, c.stream_url, c.logo_url, c.epg_channel_id, "
                                            "c.type, c.added_at, c.first_seen_at");
    result.sql += R"( FROM channels c
                      LEFT JOIN categories cat ON c.category_id = cat.id
                      LEFT JOIN servers s ON c.server_id = s.id
                      WHERE 1=1)";

    const QString scope = normalizeScope(group.filterScope);
    const QString field = normalizeField(group.filterField);
    const QString op = normalizeOperator(group.filterOperator);
    const QString value = group.filterValue.trimmed();

    if (scope != QLatin1String("any")) {
        result.sql += " AND c.type = ?";
        result.binds.append(scope);
    }

    if (!value.isEmpty()) {
        const QString expr = fieldExpression(field);
        if (op == QLatin1String("equals")) {
            result.sql += " AND " + expr + " = ? COLLATE NOCASE";
            result.binds.append(value);
        } else if (op == QLatin1String("starts_with")) {
            result.sql += " AND " + expr + " LIKE ? COLLATE NOCASE";
            result.binds.append(QStringLiteral("%1%%").arg(value));
        } else if (op == QLatin1String("not_contains")) {
            result.sql += " AND " + expr + " NOT LIKE ? COLLATE NOCASE";
            result.binds.append(QStringLiteral("%%%1%%").arg(value));
        } else {
            result.sql += " AND " + expr + " LIKE ? COLLATE NOCASE";
            result.binds.append(QStringLiteral("%%%1%%").arg(value));
        }
    }

    if (!countOnly) {
        result.sql += " ORDER BY c.name COLLATE NOCASE";
    }
    return result;
}
} // namespace

namespace iptvxs {

ChannelGroupRepository::ChannelGroupRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(db) {}

std::optional<ChannelGroup> ChannelGroupRepository::findGroup(int64_t id) const {
    QSqlQuery q(db_);
    q.prepare("SELECT id, name, kind, filter_scope, filter_field, filter_operator, "
              "filter_value, position, created_at FROM channel_groups "
              "WHERE id = ? AND deleted_at IS NULL");
    q.addBindValue(static_cast<qlonglong>(id));
    if (!q.exec() || !q.next()) {
        return std::nullopt;
    }

    ChannelGroup g;
    g.id = q.value(0).toLongLong();
    g.name = q.value(1).toString();
    g.kind = q.value(2).toString();
    g.filterScope = q.value(3).toString();
    g.filterField = q.value(4).toString();
    g.filterOperator = q.value(5).toString();
    g.filterValue = q.value(6).toString();
    g.position = q.value(7).toInt();
    g.createdAt = q.value(8).toLongLong();
    return g;
}

QVector<ChannelGroup> ChannelGroupRepository::findAllGroups() const {
    QVector<ChannelGroup> results;
    QSqlQuery q(db_);
    if (!q.exec("SELECT id, name, kind, filter_scope, filter_field, filter_operator, "
                "filter_value, position, created_at "
                "FROM channel_groups ORDER BY position ASC")) {
        return results;
    }
    while (q.next()) {
        ChannelGroup g;
        g.id = q.value(0).toLongLong();
        g.name = q.value(1).toString();
        g.kind = q.value(2).toString();
        g.filterScope = q.value(3).toString();
        g.filterField = q.value(4).toString();
        g.filterOperator = q.value(5).toString();
        g.filterValue = q.value(6).toString();
        g.position = q.value(7).toInt();
        g.createdAt = q.value(8).toLongLong();
        results.append(g);
    }
    return results;
}

qint64 ChannelGroupRepository::createGroup(const QString &name, const QString &kind,
                                           const QString &filterScope,
                                           const QString &filterField,
                                           const QString &filterOperator,
                                           const QString &filterValue) {
    const auto trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        qWarning("ChannelGroupRepository::createGroup rejected empty name");
        return 0;
    }

    const QString safeKind = normalizeKind(kind);
    const QString safeScope = normalizeScope(filterScope);
    const QString safeField = normalizeField(filterField);
    const QString safeOperator = normalizeOperator(filterOperator);
    const QString safeValue = filterValue.trimmed();

    qInfo("ChannelGroupRepository::createGroup name=%s kind=%s scope=%s field=%s operator=%s value=%s",
          qPrintable(trimmed), qPrintable(safeKind), qPrintable(safeScope),
          qPrintable(safeField), qPrintable(safeOperator), qPrintable(safeValue));

    if (safeKind == QLatin1String("dynamic") && safeValue.isEmpty()) {
        emit errorOccurred(QStringLiteral("Dynamic groups need a filter value."));
        return 0;
    }

    QSqlQuery q(db_);
    q.prepare("INSERT INTO channel_groups "
              "(name, kind, filter_scope, filter_field, filter_operator, filter_value, "
              "position, created_at, updated_at) "
              "VALUES (?, ?, ?, ?, ?, ?, ?, ?, strftime('%s', 'now'))");
    q.addBindValue(trimmed);
    q.addBindValue(safeKind);
    q.addBindValue(safeScope);
    q.addBindValue(safeField);
    q.addBindValue(safeOperator);
    q.addBindValue(safeValue);
    q.addBindValue(nextGroupPosition());
    q.addBindValue(QDateTime::currentSecsSinceEpoch());
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to create group: %1").arg(q.lastError().text()));
        qWarning("ChannelGroupRepository::createGroup failed: %s",
                 qPrintable(q.lastError().text()));
        return 0;
    }
    emit groupsChanged();
    qInfo("ChannelGroupRepository::createGroup inserted id=%lld",
          static_cast<long long>(q.lastInsertId().toLongLong()));
    return q.lastInsertId().toLongLong();
}

bool ChannelGroupRepository::updateGroup(int64_t id, const QString &name, const QString &kind,
                                         const QString &filterScope,
                                         const QString &filterField,
                                         const QString &filterOperator,
                                         const QString &filterValue) {
    const auto trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        qWarning("ChannelGroupRepository::updateGroup rejected empty name");
        return false;
    }

    const QString safeKind = normalizeKind(kind);
    const QString safeScope = normalizeScope(filterScope);
    const QString safeField = normalizeField(filterField);
    const QString safeOperator = normalizeOperator(filterOperator);
    const QString safeValue = filterValue.trimmed();

    qInfo("ChannelGroupRepository::updateGroup id=%lld name=%s kind=%s scope=%s field=%s operator=%s value=%s",
          static_cast<long long>(id), qPrintable(trimmed), qPrintable(safeKind),
          qPrintable(safeScope), qPrintable(safeField), qPrintable(safeOperator),
          qPrintable(safeValue));

    if (safeKind == QLatin1String("dynamic") && safeValue.isEmpty()) {
        emit errorOccurred(QStringLiteral("Dynamic groups need a filter value."));
        return false;
    }

    QSqlQuery q(db_);
    q.prepare("UPDATE channel_groups SET name = ?, kind = ?, filter_scope = ?, filter_field = ?, "
              "filter_operator = ?, filter_value = ?, updated_at = strftime('%s', 'now') "
              "WHERE id = ? AND deleted_at IS NULL");
    q.addBindValue(trimmed);
    q.addBindValue(safeKind);
    q.addBindValue(safeScope);
    q.addBindValue(safeField);
    q.addBindValue(safeOperator);
    q.addBindValue(safeValue);
    q.addBindValue(static_cast<qlonglong>(id));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to update group: %1").arg(q.lastError().text()));
        qWarning("ChannelGroupRepository::updateGroup failed: %s",
                 qPrintable(q.lastError().text()));
        return false;
    }
    emit groupsChanged();
    return true;
}

bool ChannelGroupRepository::renameGroup(int64_t id, const QString &name) {
    QSqlQuery q(db_);
    q.prepare("UPDATE channel_groups SET name = ?, updated_at = strftime('%s', 'now') "
              "WHERE id = ? AND deleted_at IS NULL");
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
    // Tombstone the group AND its members so the delete propagates via sync.
    if (!db_.transaction()) return false;
    QSqlQuery q(db_);
    q.prepare("UPDATE channel_groups "
              "SET deleted_at = strftime('%s', 'now'), updated_at = strftime('%s', 'now') "
              "WHERE id = ? AND deleted_at IS NULL");
    q.addBindValue(static_cast<qlonglong>(id));
    if (!q.exec()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to delete group: %1").arg(q.lastError().text()));
        return false;
    }
    QSqlQuery m(db_);
    m.prepare("UPDATE group_members "
              "SET deleted_at = strftime('%s', 'now'), updated_at = strftime('%s', 'now') "
              "WHERE group_id = ? AND deleted_at IS NULL");
    m.addBindValue(static_cast<qlonglong>(id));
    if (!m.exec()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to tombstone group members: %1").arg(m.lastError().text()));
        return false;
    }
    if (!db_.commit()) {
        db_.rollback();
        return false;
    }
    emit groupsChanged();
    return true;
}

bool ChannelGroupRepository::reorderGroup(int64_t id, int newPosition) {
    QSqlQuery q(db_);
    q.prepare("UPDATE channel_groups SET position = ?, updated_at = strftime('%s', 'now') "
              "WHERE id = ? AND deleted_at IS NULL");
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
    if (!q.exec("SELECT COUNT(*) FROM channel_groups WHERE deleted_at IS NULL")) {
        return 0;
    }
    return q.next() ? q.value(0).toInt() : 0;
}

QVector<GroupMember> ChannelGroupRepository::findStaticMembers(int64_t groupId) const {
    QVector<GroupMember> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT gm.id, gm.group_id, gm.channel_id, gm.position,
               c.id, c.server_id, c.category_id, c.external_id,
               c.name, c.stream_url, c.logo_url, c.epg_channel_id,
               c.type, c.added_at, c.first_seen_at
        FROM group_members gm
        JOIN channels c ON c.id = gm.channel_id
        WHERE gm.group_id = ? AND gm.deleted_at IS NULL
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
        m.channel.streamUrl = sanitizeRemoteUrl(q.value(9).toString());
        m.channel.logoUrl = sanitizeRemoteUrl(q.value(10).toString());
        m.channel.epgChannelId = q.value(11).toString();
        m.channel.type = q.value(12).toString();
        m.channel.addedAt = q.value(13).toLongLong();
        m.channel.firstSeenAt = q.value(14).toLongLong();
        results.append(m);
    }
    return results;
}

QVector<GroupMember> ChannelGroupRepository::findDynamicMembers(const ChannelGroup &group) const {
    QVector<GroupMember> results;
    const auto querySpec = buildDynamicQuery(group, false);
    QSqlQuery q(db_);
    if (!q.prepare(querySpec.sql)) {
        return results;
    }
    for (const auto &bind : querySpec.binds) {
        q.addBindValue(bind);
    }
    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        GroupMember m;
        m.id = 0;
        m.groupId = group.id;
        m.channelId = q.value(0).toLongLong();
        m.position = results.size();
        m.channel.id = q.value(0).toLongLong();
        m.channel.serverId = q.value(1).toLongLong();
        m.channel.categoryId = q.value(2).toLongLong();
        m.channel.externalId = q.value(3).toString();
        m.channel.name = q.value(4).toString();
        m.channel.streamUrl = sanitizeRemoteUrl(q.value(5).toString());
        m.channel.logoUrl = sanitizeRemoteUrl(q.value(6).toString());
        m.channel.epgChannelId = q.value(7).toString();
        m.channel.type = q.value(8).toString();
        m.channel.addedAt = q.value(9).toLongLong();
        m.channel.firstSeenAt = q.value(10).toLongLong();
        results.append(m);
    }
    return results;
}

int ChannelGroupRepository::countDynamicMembers(const ChannelGroup &group) const {
    const auto querySpec = buildDynamicQuery(group, true);
    QSqlQuery q(db_);
    if (!q.prepare(querySpec.sql)) {
        return 0;
    }
    for (const auto &bind : querySpec.binds) {
        q.addBindValue(bind);
    }
    if (!q.exec() || !q.next()) {
        return 0;
    }
    return q.value(0).toInt();
}

QVector<GroupMember> ChannelGroupRepository::findMembers(int64_t groupId) const {
    const auto group = findGroup(groupId);
    if (!group) {
        return {};
    }
    if (group->kind == QLatin1String("dynamic")) {
        return findDynamicMembers(*group);
    }
    return findStaticMembers(groupId);
}

bool ChannelGroupRepository::addMember(int64_t groupId, int64_t channelId) {
    if (groupKind(groupId) == QLatin1String("dynamic")) {
        emit errorOccurred(QStringLiteral("Dynamic groups are read-only."));
        return false;
    }
    if (isMember(groupId, channelId)) {
        return true;
    }
    QSqlQuery q(db_);
    // Revive a tombstoned membership if one exists, else INSERT.
    QSqlQuery revive(db_);
    revive.prepare("UPDATE group_members "
                   "SET deleted_at = NULL, updated_at = strftime('%s', 'now'), position = ? "
                   "WHERE group_id = ? AND channel_id = ? AND deleted_at IS NOT NULL");
    revive.addBindValue(nextMemberPosition(groupId));
    revive.addBindValue(static_cast<qlonglong>(groupId));
    revive.addBindValue(static_cast<qlonglong>(channelId));
    if (revive.exec() && revive.numRowsAffected() > 0) {
        emit groupsChanged();
        return true;
    }
    q.prepare("INSERT INTO group_members (group_id, channel_id, position, updated_at) "
              "VALUES (?, ?, ?, strftime('%s', 'now'))");
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
    if (groupKind(groupId) == QLatin1String("dynamic")) {
        emit errorOccurred(QStringLiteral("Dynamic groups are read-only."));
        return false;
    }
    QSqlQuery q(db_);
    q.prepare("UPDATE group_members "
              "SET deleted_at = strftime('%s', 'now'), updated_at = strftime('%s', 'now') "
              "WHERE group_id = ? AND channel_id = ? AND deleted_at IS NULL");
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
    if (groupKind(groupId) == QLatin1String("dynamic")) {
        return false;
    }
    QSqlQuery q(db_);
    q.prepare("UPDATE group_members "
              "SET position = ?, updated_at = strftime('%s', 'now') "
              "WHERE group_id = ? AND channel_id = ? AND deleted_at IS NULL");
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
    const auto group = findGroup(groupId);
    if (!group) {
        return false;
    }
    if (group->kind == QLatin1String("dynamic")) {
        const auto members = findDynamicMembers(*group);
        for (const auto &member : members) {
            if (member.channelId == channelId) {
                return true;
            }
        }
        return false;
    }

    QSqlQuery q(db_);
    q.prepare("SELECT 1 FROM group_members "
              "WHERE group_id = ? AND channel_id = ? AND deleted_at IS NULL");
    q.addBindValue(static_cast<qlonglong>(groupId));
    q.addBindValue(static_cast<qlonglong>(channelId));
    if (!q.exec()) {
        return false;
    }
    return q.next();
}

int ChannelGroupRepository::memberCount(int64_t groupId) const {
    const auto group = findGroup(groupId);
    if (!group) {
        return 0;
    }
    if (group->kind == QLatin1String("dynamic")) {
        return countDynamicMembers(*group);
    }

    QSqlQuery q(db_);
    q.prepare("SELECT COUNT(*) FROM group_members "
              "WHERE group_id = ? AND deleted_at IS NULL");
    q.addBindValue(static_cast<qlonglong>(groupId));
    if (!q.exec()) {
        return 0;
    }
    return q.next() ? q.value(0).toInt() : 0;
}

QString ChannelGroupRepository::groupKind(int64_t groupId) const {
    const auto group = findGroup(groupId);
    if (!group) {
        return QStringLiteral("static");
    }
    return normalizeKind(group->kind);
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
