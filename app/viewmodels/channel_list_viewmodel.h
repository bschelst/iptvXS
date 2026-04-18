#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/db/channel_repository.h"
#include "iptvxs/models/channel.h"

class ChannelListViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int64_t serverId READ serverId WRITE setServerId NOTIFY serverIdChanged)
    Q_PROPERTY(int64_t categoryId READ categoryId WRITE setCategoryId NOTIFY categoryIdChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY totalCountChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY hasMoreChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        StreamUrlRole,
        LogoUrlRole,
        TypeRole,
        CategoryIdRole,
        EpgChannelIdRole
    };

    explicit ChannelListViewModel(QObject *parent = nullptr);

    void setRepository(iptvxs::ChannelRepository *repo);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int64_t serverId() const;
    void setServerId(int64_t id);
    int64_t categoryId() const;
    void setCategoryId(int64_t id);
    QString searchQuery() const;
    void setSearchQuery(const QString &query);
    int count() const;
    int totalCount() const;
    bool hasMore() const;
    bool loading() const;

    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE QString channelUrlAt(int index) const;
    Q_INVOKABLE QString channelNameAt(int index) const;

signals:
    void serverIdChanged();
    void categoryIdChanged();
    void searchQueryChanged();
    void countChanged();
    void totalCountChanged();
    void hasMoreChanged();
    void loadingChanged();

private:
    void loadChannels(bool append = false);
    void updateTotalCount();

    iptvxs::ChannelRepository *repo_{nullptr};
    QVector<iptvxs::Channel> channels_;
    int64_t serverId_{0};
    int64_t categoryId_{0};
    QString searchQuery_;
    int totalCount_{0};
    bool loading_{false};

    static constexpr int kPageSize = 200;
};
