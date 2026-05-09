// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "channel_list_viewmodel.h"

#include <QDateTime>
#include <QSet>
#include <algorithm>

ChannelListViewModel::ChannelListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void ChannelListViewModel::setRepository(iptvxs::ChannelRepository *repo) {
    repo_ = repo;
}

void ChannelListViewModel::setFavoriteRepository(iptvxs::FavoriteRepository *favRepo) {
    favRepo_ = favRepo;
    favIds_.clear();
    favCacheLoaded_ = false;
    if (favRepo_) {
        connect(favRepo_, &iptvxs::FavoriteRepository::favoritesChanged, this,
                [this]() {
                    favIds_.clear();
                    favCacheLoaded_ = false;
                });
    }
}

int ChannelListViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(channels_.size());
}

QVariant ChannelListViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= channels_.size()) return {};

    const auto &ch = channels_.at(index.row());
    switch (role) {
    case IdRole: return QVariant::fromValue(ch.id);
    case NameRole: return ch.name;
    case StreamUrlRole: return ch.streamUrl;
    case LogoUrlRole: return ch.logoUrl;
    case TypeRole: return ch.type;
    case CategoryIdRole: return QVariant::fromValue(ch.categoryId);
    case EpgChannelIdRole: return ch.epgChannelId;
    case ExternalIdRole: return ch.externalId;
    case ServerIdRole: return QVariant::fromValue(ch.serverId);
    case TvArchiveRole: return ch.tvArchive;
    case TvArchiveDurationRole: return ch.tvArchiveDuration;
    default: return {};
    }
}

QHash<int, QByteArray> ChannelListViewModel::roleNames() const {
    return {
        {IdRole, "channelId"},
        {NameRole, "name"},
        {StreamUrlRole, "streamUrl"},
        {LogoUrlRole, "logoUrl"},
        {TypeRole, "type"},
        {CategoryIdRole, "categoryId"},
        {EpgChannelIdRole, "epgChannelId"},
        {ExternalIdRole, "externalId"},
        {ServerIdRole, "serverId"},
        {TvArchiveRole, "tvArchive"},
        {TvArchiveDurationRole, "tvArchiveDuration"},
    };
}

int64_t ChannelListViewModel::serverId() const { return serverId_; }

void ChannelListViewModel::setServerId(int64_t id) {
    if (serverId_ != id) {
        serverId_ = id;
        categoryId_ = 0;
        searchQuery_.clear();
        emit serverIdChanged();
        emit categoryIdChanged();
        emit searchQueryChanged();
        loadChannels();
    }
}

int64_t ChannelListViewModel::categoryId() const { return categoryId_; }

void ChannelListViewModel::setCategoryId(int64_t id) {
    if (categoryId_ != id) {
        categoryId_ = id;
        emit categoryIdChanged();
        loadChannels();
    }
}

QString ChannelListViewModel::searchQuery() const { return searchQuery_; }

void ChannelListViewModel::setSearchQuery(const QString &query) {
    if (searchQuery_ != query) {
        searchQuery_ = query;
        emit searchQueryChanged();
        loadChannels();
    }
}

int ChannelListViewModel::count() const {
    return static_cast<int>(channels_.size());
}

int ChannelListViewModel::totalCount() const { return totalCount_; }

bool ChannelListViewModel::hasMore() const {
    return channels_.size() < totalCount_;
}

bool ChannelListViewModel::loading() const { return loading_; }

QString ChannelListViewModel::typeFilter() const { return typeFilter_; }

void ChannelListViewModel::setTypeFilter(const QString &type) {
    if (typeFilter_ != type) {
        typeFilter_ = type;
        emit typeFilterChanged();
        loadChannels();
    }
}

bool ChannelListViewModel::recentlyAddedFilter() const { return recentlyAddedFilter_; }

void ChannelListViewModel::setRecentlyAddedFilter(bool enabled) {
    if (recentlyAddedFilter_ != enabled) {
        recentlyAddedFilter_ = enabled;
        emit recentlyAddedFilterChanged();
        loadChannels();
    }
}

void ChannelListViewModel::loadMore() {
    if (!hasMore() || loading_) return;
    loadChannels(true);
}

void ChannelListViewModel::refresh() { loadChannels(); }

void ChannelListViewModel::setBrowseContext(int64_t serverId, const QString &type,
                                            int64_t categoryId) {
    bool serverChanged = serverId_ != serverId;
    bool typeChanged = typeFilter_ != type;
    bool categoryChanged = categoryId_ != categoryId;
    bool searchChanged = serverChanged && !searchQuery_.isEmpty();

    if (!serverChanged && !typeChanged && !categoryChanged && !searchChanged) {
        return;
    }

    serverId_ = serverId;
    typeFilter_ = type;
    categoryId_ = categoryId;
    if (serverChanged) {
        searchQuery_.clear();
    }

    if (serverChanged) emit serverIdChanged();
    if (typeChanged) emit typeFilterChanged();
    if (categoryChanged) emit categoryIdChanged();
    if (searchChanged) emit searchQueryChanged();

    loadChannels();
}

QString ChannelListViewModel::streamUrlAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_[index].streamUrl;
}
QString ChannelListViewModel::nameAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_[index].name;
}
QString ChannelListViewModel::logoUrlAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_[index].logoUrl;
}
int64_t ChannelListViewModel::channelIdAt(int index) const {
    if (index < 0 || index >= channels_.size()) return 0;
    return channels_[index].id;
}
QString ChannelListViewModel::typeAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_[index].type;
}
QString ChannelListViewModel::externalIdAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_[index].externalId;
}
int64_t ChannelListViewModel::serverIdAt(int index) const {
    if (index < 0 || index >= channels_.size()) return 0;
    return channels_[index].serverId;
}

QString ChannelListViewModel::epgChannelIdAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_[index].epgChannelId;
}

QString ChannelListViewModel::channelUrlAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_.at(index).streamUrl;
}

QString ChannelListViewModel::channelNameAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_.at(index).name;
}

QVariantList ChannelListViewModel::channelsForCategory(int64_t categoryId, int limit) const {
    QVariantList result;
    if (!repo_) return result;
    auto channels = repo_->findByCategory(categoryId, limit * 2, 0);
    for (const auto &ch : channels) {
        if (serverId_ > 0 && ch.serverId != serverId_) continue;
        if (!typeFilter_.isEmpty() && ch.type != typeFilter_) continue;
        QVariantMap item;
        item[QStringLiteral("channelId")] = QVariant::fromValue(ch.id);
        item[QStringLiteral("name")] = ch.name;
        item[QStringLiteral("streamUrl")] = ch.streamUrl;
        item[QStringLiteral("logoUrl")] = ch.logoUrl;
        item[QStringLiteral("type")] = ch.type;
        item[QStringLiteral("externalId")] = ch.externalId;
        item[QStringLiteral("serverId")] = QVariant::fromValue(ch.serverId);
        item[QStringLiteral("epgChannelId")] = ch.epgChannelId;
        result.append(item);
        if (result.size() >= limit) break;
    }
    return result;
}

QVariantList ChannelListViewModel::channelsForServerAndType(int64_t serverId,
                                                            const QString &type) const {
    QVariantList result;
    if (!repo_ || serverId <= 0 || type.isEmpty()) return result;

    auto channels = repo_->findByServerAndType(serverId, type, 0, 0);
    if (channels.isEmpty()) return result;

    QSet<int64_t> favoriteIds = favIds_;
    if (!favCacheLoaded_ && favRepo_) {
        const auto favorites = favRepo_->findAll();
        favoriteIds.clear();
        for (const auto &favorite : favorites) {
            favoriteIds.insert(favorite.channelId);
        }
        favIds_ = favoriteIds;
        favCacheLoaded_ = true;
    }

    std::stable_partition(channels.begin(), channels.end(),
                          [&favoriteIds](const iptvxs::Channel &channel) {
                              return favoriteIds.contains(channel.id);
                          });

    for (const auto &ch : channels) {
        QVariantMap item;
        item[QStringLiteral("channelId")] = QVariant::fromValue(ch.id);
        item[QStringLiteral("name")] = ch.name;
        item[QStringLiteral("streamUrl")] = ch.streamUrl;
        item[QStringLiteral("logoUrl")] = ch.logoUrl;
        item[QStringLiteral("type")] = ch.type;
        item[QStringLiteral("externalId")] = ch.externalId;
        item[QStringLiteral("serverId")] = QVariant::fromValue(ch.serverId);
        item[QStringLiteral("epgChannelId")] = ch.epgChannelId;
        item[QStringLiteral("isFavorite")] = favoriteIds.contains(ch.id);
        result.append(item);
    }

    return result;
}

void ChannelListViewModel::refreshFavoriteCache() {
    favIds_.clear();
    favCacheLoaded_ = false;
    if (!favRepo_) return;
    const auto favorites = favRepo_->findAll();
    for (const auto &favorite : favorites) {
        favIds_.insert(favorite.channelId);
    }
    favCacheLoaded_ = true;
}

void ChannelListViewModel::loadChannels(bool append) {
    if (!repo_ || serverId_ <= 0) return;

    loading_ = true;
    emit loadingChanged();

    int offset = append ? static_cast<int>(channels_.size()) : 0;
    const auto recentSince = QDateTime::currentSecsSinceEpoch() - 7 * 24 * 3600;

    QVector<iptvxs::Channel> result;
    if (recentlyAddedFilter_ && searchQuery_.isEmpty() && categoryId_ <= 0) {
        if (typeFilter_.isEmpty()) {
            result = repo_->findRecentlyAdded(serverId_, recentSince, kPageSize, offset);
        } else {
            result = repo_->findRecentlyAdded(serverId_, recentSince, typeFilter_, kPageSize, offset);
        }
    } else if (!searchQuery_.isEmpty() && !typeFilter_.isEmpty()) {
        result = repo_->searchWithType(serverId_, searchQuery_, typeFilter_, kPageSize, offset);
    } else if (!searchQuery_.isEmpty()) {
        result = repo_->search(serverId_, searchQuery_, kPageSize, offset);
    } else if (categoryId_ > 0) {
        result = repo_->findByCategory(categoryId_, kPageSize, offset);
    } else if (!typeFilter_.isEmpty()) {
        result = repo_->findByServerAndType(serverId_, typeFilter_, kPageSize, offset);
    } else {
        result = repo_->findByServer(serverId_, kPageSize, offset);
    }

    if (favRepo_ && !append && !result.isEmpty()) {
        if (!favCacheLoaded_) {
            refreshFavoriteCache();
        }
        if (!favIds_.isEmpty()) {
            std::stable_partition(result.begin(), result.end(),
                                  [this](const iptvxs::Channel &channel) {
                                      return favIds_.contains(channel.id);
                                  });
        }
    }

    if (recentlyAddedFilter_ && !(searchQuery_.isEmpty() && categoryId_ <= 0)) {
        QVector<iptvxs::Channel> filtered;
        filtered.reserve(result.size());
        std::copy_if(result.begin(), result.end(), std::back_inserter(filtered),
                     [recentSince](const iptvxs::Channel &ch) {
                         auto addedAt = ch.addedAt > 0 ? ch.addedAt : ch.firstSeenAt;
                         return addedAt >= recentSince;
                     });
        result = filtered;
    }

    if (append) {
        if (!result.isEmpty()) {
            beginInsertRows({}, channels_.size(),
                            channels_.size() + result.size() - 1);
            channels_.append(result);
            endInsertRows();
        }
    } else {
        beginResetModel();
        channels_ = result;
        endResetModel();
    }

    updateTotalCount();

    loading_ = false;
    emit loadingChanged();
    emit countChanged();
    emit hasMoreChanged();
}

void ChannelListViewModel::updateTotalCount() {
    int newTotal = 0;
    const auto recentSince = QDateTime::currentSecsSinceEpoch() - 7 * 24 * 3600;
    if (recentlyAddedFilter_ && searchQuery_.isEmpty() && categoryId_ <= 0) {
        if (typeFilter_.isEmpty()) {
            newTotal = repo_->countRecentlyAdded(serverId_, recentSince);
        } else {
            newTotal = repo_->countRecentlyAdded(serverId_, recentSince, typeFilter_);
        }
    } else if (!searchQuery_.isEmpty() && !typeFilter_.isEmpty()) {
        newTotal = repo_->countBySearchWithType(serverId_, searchQuery_, typeFilter_);
    } else if (!searchQuery_.isEmpty()) {
        newTotal = repo_->countBySearch(serverId_, searchQuery_);
    } else if (categoryId_ > 0) {
        newTotal = repo_->countByCategory(categoryId_);
    } else if (!typeFilter_.isEmpty()) {
        newTotal = repo_->countByServerAndType(serverId_, typeFilter_);
    } else {
        newTotal = repo_->count(serverId_);
    }

    if (totalCount_ != newTotal) {
        totalCount_ = newTotal;
        emit totalCountChanged();
    }
}
