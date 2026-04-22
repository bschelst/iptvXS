#include "group_list_viewmodel.h"

GroupListViewModel::GroupListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void GroupListViewModel::setRepository(iptvxs::ChannelGroupRepository *repo) {
    repo_ = repo;
    if (repo_) {
        connect(repo_, &iptvxs::ChannelGroupRepository::groupsChanged, this,
                &GroupListViewModel::refresh);
        loadGroups();
    }
}

int GroupListViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    if (activeGroupId_ > 0) {
        return static_cast<int>(members_.size());
    }
    return static_cast<int>(groups_.size());
}

QVariant GroupListViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid()) return {};

    if (activeGroupId_ > 0) {
        // Member mode
        if (index.row() >= members_.size()) return {};
        const auto &m = members_.at(index.row());
        switch (role) {
        case IdRole: return QVariant::fromValue(m.id);
        case ChannelIdRole: return QVariant::fromValue(m.channelId);
        case ChannelNameRole: return m.channel.name;
        case StreamUrlRole: return m.channel.streamUrl;
        case LogoUrlRole: return m.channel.logoUrl;
        case TypeRole: return m.channel.type;
        case PositionRole: return m.position;
        default: return {};
        }
    }

    // Group mode
    if (index.row() >= groups_.size()) return {};
    const auto &g = groups_.at(index.row());
    switch (role) {
    case IdRole: return QVariant::fromValue(g.id);
    case NameRole: return g.name;
    case PositionRole: return g.position;
    case MemberCountRole:
        return repo_ ? repo_->memberCount(g.id) : 0;
    default: return {};
    }
}

QHash<int, QByteArray> GroupListViewModel::roleNames() const {
    return {
        {IdRole, "groupId"},
        {NameRole, "name"},
        {PositionRole, "position"},
        {MemberCountRole, "memberCount"},
        {ChannelIdRole, "channelId"},
        {ChannelNameRole, "channelName"},
        {StreamUrlRole, "streamUrl"},
        {LogoUrlRole, "logoUrl"},
        {TypeRole, "type"},
    };
}

int GroupListViewModel::count() const {
    if (activeGroupId_ > 0) {
        return static_cast<int>(members_.size());
    }
    return static_cast<int>(groups_.size());
}

bool GroupListViewModel::empty() const {
    return count() == 0;
}

int64_t GroupListViewModel::activeGroupId() const {
    return activeGroupId_;
}

void GroupListViewModel::setActiveGroupId(int64_t id) {
    if (activeGroupId_ != id) {
        activeGroupId_ = id;
        emit activeGroupIdChanged();
        refresh();
    }
}

void GroupListViewModel::refresh() {
    if (activeGroupId_ > 0) {
        loadMembers();
    } else {
        loadGroups();
    }
}

void GroupListViewModel::createGroup(const QString &name) {
    if (!repo_ || name.trimmed().isEmpty()) return;
    repo_->createGroup(name.trimmed());
}

void GroupListViewModel::renameGroup(int64_t groupId, const QString &name) {
    if (!repo_ || name.trimmed().isEmpty()) return;
    repo_->renameGroup(groupId, name.trimmed());
}

void GroupListViewModel::deleteGroup(int64_t groupId) {
    if (!repo_) return;
    repo_->deleteGroup(groupId);
    if (activeGroupId_ == groupId) {
        activeGroupId_ = 0;
        emit activeGroupIdChanged();
        loadGroups();
    }
}

void GroupListViewModel::addChannel(int64_t groupId, int64_t channelId) {
    if (!repo_) return;
    repo_->addMember(groupId, channelId);
    if (activeGroupId_ == groupId) {
        loadMembers();
    }
}

void GroupListViewModel::removeChannel(int64_t groupId, int64_t channelId) {
    if (!repo_) return;
    repo_->removeMember(groupId, channelId);
    if (activeGroupId_ == groupId) {
        loadMembers();
    }
}

bool GroupListViewModel::isInGroup(int64_t groupId, int64_t channelId) const {
    if (!repo_) return false;
    return repo_->isMember(groupId, channelId);
}

QString GroupListViewModel::groupNameAt(int index) const {
    if (index < 0 || index >= groups_.size()) return {};
    return groups_.at(index).name;
}

int64_t GroupListViewModel::groupIdAt(int index) const {
    if (index < 0 || index >= groups_.size()) return 0;
    return groups_.at(index).id;
}

QString GroupListViewModel::streamUrlAt(int index) const {
    if (index < 0 || index >= members_.size()) return {};
    return members_.at(index).channel.streamUrl;
}

QString GroupListViewModel::channelNameAt(int index) const {
    if (index < 0 || index >= members_.size()) return {};
    return members_.at(index).channel.name;
}

QString GroupListViewModel::logoUrlAt(int index) const {
    if (index < 0 || index >= members_.size()) return {};
    return members_.at(index).channel.logoUrl;
}

int64_t GroupListViewModel::channelIdAt(int index) const {
    if (index < 0 || index >= members_.size()) return 0;
    return members_.at(index).channelId;
}

void GroupListViewModel::setChannelRepository(iptvxs::ChannelRepository *repo) {
    channelRepo_ = repo;
}

QVariantList GroupListViewModel::searchChannels(const QString &query, int limit) const {
    QVariantList results;
    if (!channelRepo_ || query.trimmed().isEmpty()) return results;

    auto channels = channelRepo_->searchAll(query.trimmed(), limit);
    for (const auto &ch : channels) {
        QVariantMap item;
        item["channelId"] = QVariant::fromValue(ch.id);
        item["name"] = ch.name;
        item["logoUrl"] = ch.logoUrl;
        item["streamUrl"] = ch.streamUrl;
        item["type"] = ch.type;
        results.append(item);
    }
    return results;
}

int GroupListViewModel::memberCount(int64_t groupId) const {
    if (!repo_) return 0;
    return repo_->memberCount(groupId);
}

void GroupListViewModel::loadGroups() {
    if (!repo_) return;
    beginResetModel();
    groups_ = repo_->findAllGroups();
    endResetModel();
    emit countChanged();
}

void GroupListViewModel::loadMembers() {
    if (!repo_ || activeGroupId_ <= 0) return;
    beginResetModel();
    members_ = repo_->findMembers(activeGroupId_);
    endResetModel();
    emit countChanged();
}
