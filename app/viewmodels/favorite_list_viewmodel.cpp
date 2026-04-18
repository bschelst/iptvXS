#include "favorite_list_viewmodel.h"

FavoriteListViewModel::FavoriteListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void FavoriteListViewModel::setRepository(iptvxs::FavoriteRepository *repo) {
    repo_ = repo;
    if (repo_) {
        connect(repo_, &iptvxs::FavoriteRepository::favoritesChanged, this,
                &FavoriteListViewModel::loadFavorites);
        loadFavorites();
    }
}

int FavoriteListViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return static_cast<int>(favorites_.size());
}

QVariant FavoriteListViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= favorites_.size()) {
        return {};
    }

    const auto &fav = favorites_.at(index.row());

    switch (role) {
    case ChannelIdRole:
        return QVariant::fromValue(fav.channelId);
    case NameRole:
        return fav.channel.name;
    case StreamUrlRole:
        return fav.channel.streamUrl;
    case LogoUrlRole:
        return fav.channel.logoUrl;
    case TypeRole:
        return fav.channel.type;
    case PositionRole:
        return fav.position;
    default:
        return {};
    }
}

QHash<int, QByteArray> FavoriteListViewModel::roleNames() const {
    return {
        {ChannelIdRole, "channelId"},
        {NameRole, "name"},
        {StreamUrlRole, "streamUrl"},
        {LogoUrlRole, "logoUrl"},
        {TypeRole, "type"},
        {PositionRole, "position"},
    };
}

int FavoriteListViewModel::count() const {
    return static_cast<int>(favorites_.size());
}

bool FavoriteListViewModel::empty() const {
    return favorites_.isEmpty();
}

void FavoriteListViewModel::refresh() {
    loadFavorites();
}

void FavoriteListViewModel::toggleFavorite(int64_t channelId) {
    if (!repo_) {
        return;
    }

    bool wasFav = repo_->isFavorite(channelId);
    repo_->toggle(channelId);
    emit favoriteToggled(channelId, !wasFav);
}

bool FavoriteListViewModel::isFavorite(int64_t channelId) const {
    if (!repo_) {
        return false;
    }
    return repo_->isFavorite(channelId);
}

void FavoriteListViewModel::moveItem(int fromIndex, int toIndex) {
    if (!repo_ || fromIndex < 0 || toIndex < 0 ||
        fromIndex >= favorites_.size() || toIndex >= favorites_.size() ||
        fromIndex == toIndex) {
        return;
    }

    auto moved = favorites_.at(fromIndex);
    repo_->reorder(moved.channelId, toIndex);
}

void FavoriteListViewModel::loadFavorites() {
    if (!repo_) {
        return;
    }

    beginResetModel();
    favorites_ = repo_->findAll();
    endResetModel();
    emit countChanged();
}
