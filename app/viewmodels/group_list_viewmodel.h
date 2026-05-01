// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/db/channel_group_repository.h"
#include "iptvxs/db/channel_repository.h"

class GroupListViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool empty READ empty NOTIFY countChanged)
    Q_PROPERTY(int64_t activeGroupId READ activeGroupId WRITE setActiveGroupId NOTIFY activeGroupIdChanged)

public:
    enum GroupRoles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        PositionRole,
        MemberCountRole,
        // Member roles (when viewing a group's channels):
        ChannelIdRole,
        ChannelNameRole,
        StreamUrlRole,
        LogoUrlRole,
        TypeRole
    };

    explicit GroupListViewModel(QObject *parent = nullptr);

    void setRepository(iptvxs::ChannelGroupRepository *repo);
    void setChannelRepository(iptvxs::ChannelRepository *repo);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool empty() const;
    int64_t activeGroupId() const;
    void setActiveGroupId(int64_t id);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE qint64 createGroup(const QString &name,
                                   const QString &kind = QStringLiteral("static"),
                                   const QString &filterScope = QStringLiteral("any"),
                                   const QString &filterField = QStringLiteral("name"),
                                   const QString &filterOperator = QStringLiteral("contains"),
                                   const QString &filterValue = QString());
    Q_INVOKABLE bool updateGroup(int64_t groupId, const QString &name,
                                 const QString &kind = QStringLiteral("static"),
                                 const QString &filterScope = QStringLiteral("any"),
                                 const QString &filterField = QStringLiteral("name"),
                                 const QString &filterOperator = QStringLiteral("contains"),
                                 const QString &filterValue = QString());
    Q_INVOKABLE void renameGroup(int64_t groupId, const QString &name);
    Q_INVOKABLE void deleteGroup(int64_t groupId);
    Q_INVOKABLE void addChannel(int64_t groupId, int64_t channelId);
    Q_INVOKABLE void removeChannel(int64_t groupId, int64_t channelId);
    Q_INVOKABLE bool isInGroup(int64_t groupId, int64_t channelId) const;
    Q_INVOKABLE QString groupNameAt(int index) const;
    Q_INVOKABLE QString groupTypeAt(int index) const;
    Q_INVOKABLE QString groupSummaryAt(int index) const;
    Q_INVOKABLE QString groupFilterScopeAt(int index) const;
    Q_INVOKABLE QString groupFilterFieldAt(int index) const;
    Q_INVOKABLE QString groupFilterOperatorAt(int index) const;
    Q_INVOKABLE QString groupFilterValueAt(int index) const;
    Q_INVOKABLE int64_t groupIdAt(int index) const;
    Q_INVOKABLE QString streamUrlAt(int index) const;
    Q_INVOKABLE QString channelNameAt(int index) const;
    Q_INVOKABLE QString logoUrlAt(int index) const;
    Q_INVOKABLE int64_t channelIdAt(int index) const;
    Q_INVOKABLE QString typeAt(int index) const;
    Q_INVOKABLE QVariantList searchChannels(const QString &query, int limit = 50) const;
    Q_INVOKABLE int memberCount(int64_t groupId) const;

signals:
    void countChanged();
    void activeGroupIdChanged();

private:
    void loadGroups();
    void loadMembers();

    iptvxs::ChannelGroupRepository *repo_{nullptr};
    iptvxs::ChannelRepository *channelRepo_{nullptr};
    QVector<iptvxs::ChannelGroup> groups_;
    QVector<iptvxs::GroupMember> members_;
    int64_t activeGroupId_{0};
};
