#include "channel_list_viewmodel.h"

ChannelListViewModel::ChannelListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void ChannelListViewModel::setRepository(iptvxs::ChannelRepository *repo) {
    repo_ = repo;
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

void ChannelListViewModel::loadMore() {
    if (!hasMore() || loading_) return;
    loadChannels(true);
}

void ChannelListViewModel::refresh() { loadChannels(); }

QString ChannelListViewModel::channelUrlAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_.at(index).streamUrl;
}

QString ChannelListViewModel::channelNameAt(int index) const {
    if (index < 0 || index >= channels_.size()) return {};
    return channels_.at(index).name;
}

void ChannelListViewModel::loadChannels(bool append) {
    if (!repo_ || serverId_ <= 0) return;

    loading_ = true;
    emit loadingChanged();

    int offset = append ? static_cast<int>(channels_.size()) : 0;

    QVector<iptvxs::Channel> result;
    if (!searchQuery_.isEmpty()) {
        result = repo_->search(serverId_, searchQuery_, kPageSize, offset);
    } else if (categoryId_ > 0) {
        result = repo_->findByCategory(categoryId_, kPageSize, offset);
    } else {
        result = repo_->findByServer(serverId_, kPageSize, offset);
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
    if (!searchQuery_.isEmpty()) {
        newTotal = repo_->countBySearch(serverId_, searchQuery_);
    } else if (categoryId_ > 0) {
        newTotal = repo_->countByCategory(categoryId_);
    } else {
        newTotal = repo_->count(serverId_);
    }

    if (totalCount_ != newTotal) {
        totalCount_ = newTotal;
        emit totalCountChanged();
    }
}
