// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/channel_group.h"

namespace iptvxs {

class ChannelGroupRepository : public QObject {
    Q_OBJECT

public:
    explicit ChannelGroupRepository(QSqlDatabase db, QObject *parent = nullptr);

    // Group CRUD
    QVector<ChannelGroup> findAllGroups() const;
    qint64 createGroup(const QString &name, const QString &kind = QStringLiteral("static"),
                       const QString &filterScope = QStringLiteral("any"),
                       const QString &filterField = QStringLiteral("name"),
                       const QString &filterOperator = QStringLiteral("contains"),
                       const QString &filterValue = QString());
    bool updateGroup(int64_t id, const QString &name, const QString &kind,
                     const QString &filterScope, const QString &filterField,
                     const QString &filterOperator, const QString &filterValue);
    bool renameGroup(int64_t id, const QString &name);
    bool deleteGroup(int64_t id);
    bool reorderGroup(int64_t id, int newPosition);
    int groupCount() const;

    // Member operations
    QVector<GroupMember> findMembers(int64_t groupId) const;
    bool addMember(int64_t groupId, int64_t channelId);
    bool removeMember(int64_t groupId, int64_t channelId);
    bool reorderMember(int64_t groupId, int64_t channelId, int newPosition);
    bool isMember(int64_t groupId, int64_t channelId) const;
    int memberCount(int64_t groupId) const;

    QString groupKind(int64_t groupId) const;

signals:
    void groupsChanged();
    void errorOccurred(const QString &message);

private:
    std::optional<ChannelGroup> findGroup(int64_t id) const;
    int nextGroupPosition() const;
    int nextMemberPosition(int64_t groupId) const;
    QVector<GroupMember> findStaticMembers(int64_t groupId) const;
    QVector<GroupMember> findDynamicMembers(const ChannelGroup &group) const;
    int countDynamicMembers(const ChannelGroup &group) const;
    QSqlDatabase db_;
};

} // namespace iptvxs
