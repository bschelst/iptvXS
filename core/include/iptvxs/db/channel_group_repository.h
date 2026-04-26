// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>

#include "iptvxs/models/channel_group.h"

namespace iptvxs {

class ChannelGroupRepository : public QObject {
    Q_OBJECT

public:
    explicit ChannelGroupRepository(QSqlDatabase db, QObject *parent = nullptr);

    // Group CRUD
    QVector<ChannelGroup> findAllGroups() const;
    bool createGroup(const QString &name);
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

signals:
    void groupsChanged();
    void errorOccurred(const QString &message);

private:
    int nextGroupPosition() const;
    int nextMemberPosition(int64_t groupId) const;
    QSqlDatabase db_;
};

} // namespace iptvxs
