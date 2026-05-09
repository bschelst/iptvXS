// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>
#include <QSet>

#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/favorite_repository.h"
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
    Q_PROPERTY(QString typeFilter READ typeFilter WRITE setTypeFilter NOTIFY typeFilterChanged)
    Q_PROPERTY(bool recentlyAddedFilter READ recentlyAddedFilter WRITE setRecentlyAddedFilter NOTIFY recentlyAddedFilterChanged)

    Q_INVOKABLE QString streamUrlAt(int index) const;
    Q_INVOKABLE QString nameAt(int index) const;
    Q_INVOKABLE QString logoUrlAt(int index) const;
    Q_INVOKABLE int64_t channelIdAt(int index) const;
    Q_INVOKABLE QString typeAt(int index) const;
    Q_INVOKABLE QString externalIdAt(int index) const;
    Q_INVOKABLE int64_t serverIdAt(int index) const;
    Q_INVOKABLE QString epgChannelIdAt(int index) const;

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        StreamUrlRole,
        LogoUrlRole,
        TypeRole,
        CategoryIdRole,
        EpgChannelIdRole,
        ExternalIdRole,
        ServerIdRole,
        TvArchiveRole,
        TvArchiveDurationRole
    };

    explicit ChannelListViewModel(QObject *parent = nullptr);

    void setRepository(iptvxs::ChannelRepository *repo);
    void setFavoriteRepository(iptvxs::FavoriteRepository *favRepo);
    void invalidateFavCache() { favIds_.clear(); }

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
    QString typeFilter() const;
    void setTypeFilter(const QString &type);
    bool recentlyAddedFilter() const;
    void setRecentlyAddedFilter(bool enabled);

    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setBrowseContext(int64_t serverId, const QString &type,
                                      int64_t categoryId = 0);
    Q_INVOKABLE QString channelUrlAt(int index) const;
    Q_INVOKABLE QString channelNameAt(int index) const;
    Q_INVOKABLE QVariantList channelsForCategory(int64_t categoryId, int limit = 20) const;
    Q_INVOKABLE QVariantList channelsForServerAndType(int64_t serverId, const QString &type) const;

signals:
    void serverIdChanged();
    void categoryIdChanged();
    void searchQueryChanged();
    void countChanged();
    void totalCountChanged();
    void hasMoreChanged();
    void loadingChanged();
    void typeFilterChanged();
    void recentlyAddedFilterChanged();

private:
    void loadChannels(bool append = false);
    void updateTotalCount();

    iptvxs::ChannelRepository *repo_{nullptr};
    iptvxs::FavoriteRepository *favRepo_{nullptr};
    QSet<int64_t> favIds_;
    QVector<iptvxs::Channel> channels_;
    int64_t serverId_{0};
    int64_t categoryId_{0};
    QString searchQuery_;
    QString typeFilter_;
    int totalCount_{0};
    bool loading_{false};
    bool recentlyAddedFilter_{false};

    static constexpr int kPageSize = 200;
};
