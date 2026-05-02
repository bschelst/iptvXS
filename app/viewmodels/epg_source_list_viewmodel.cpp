// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "epg_source_list_viewmodel.h"

#include <QDateTime>

EpgSourceListViewModel::EpgSourceListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void EpgSourceListViewModel::setRepository(iptvxs::EpgSourceRepository *repo) {
    repo_ = repo;
    if (repo_) {
        connect(repo_, &iptvxs::EpgSourceRepository::errorOccurred,
                this, &EpgSourceListViewModel::errorOccurred);
        loadSources();
    }
}

void EpgSourceListViewModel::setEpgViewModel(EpgViewModel *epgVm) {
    epgVm_ = epgVm;
    if (epgVm_) {
        connect(epgVm_, &EpgViewModel::syncCompleted, this,
                [this](bool ok, int programmeCount, const QString &message) {
            if (syncingIndex_ >= 0 && syncingIndex_ < sources_.size() && repo_ && ok) {
                auto now = QDateTime::currentSecsSinceEpoch();
                auto sourceId = sources_.at(syncingIndex_).id;
                repo_->updateLastSynced(sourceId, now);
                sources_[syncingIndex_].lastSyncedAt = now;
                auto idx = this->index(syncingIndex_);
                emit dataChanged(idx, idx, {LastSyncedRole});
            }
            syncingIndex_ = -1;
            setSyncing(false);
            setSyncStatus(message);
            qInfo("EPG source sync completed: ok=%d programmes=%d msg=%s",
                  ok ? 1 : 0, programmeCount, qPrintable(message));
        });
    }
}

int EpgSourceListViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(sources_.size());
}

QVariant EpgSourceListViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= sources_.size()) return {};
    const auto &source = sources_.at(index.row());
    switch (role) {
    case IdRole: return QVariant::fromValue(source.id);
    case NameRole: return source.name;
    case UrlRole: return source.url;
    case LastSyncedRole: {
        if (source.lastSyncedAt == 0) return QStringLiteral("Never");
        auto dt = QDateTime::fromSecsSinceEpoch(source.lastSyncedAt);
        return dt.toString(QStringLiteral("yyyy-MM-dd HH:mm"));
    }
    case EnabledRole: return source.enabled;
    case IsPrimaryRole: return source.isPrimary;
    default: return {};
    }
}

QHash<int, QByteArray> EpgSourceListViewModel::roleNames() const {
    return {
        {IdRole, "epgSourceId"},
        {NameRole, "name"},
        {UrlRole, "url"},
        {LastSyncedRole, "lastSynced"},
        {EnabledRole, "enabled"},
        {IsPrimaryRole, "isPrimary"},
    };
}

int EpgSourceListViewModel::count() const { return static_cast<int>(sources_.size()); }

bool EpgSourceListViewModel::syncing() const { return syncing_; }

QString EpgSourceListViewModel::syncStatus() const { return syncStatus_; }

void EpgSourceListViewModel::addSource(const QString &name, const QString &url) {
    if (!repo_) return;
    iptvxs::EpgSource source;
    source.name = name;
    source.url = url;
    source.createdAt = QDateTime::currentSecsSinceEpoch();
    auto id = repo_->create(source);
    if (id <= 0) {
        emit errorOccurred(QStringLiteral("Failed to add EPG source"));
        return;
    }
    source.id = id;
    beginInsertRows({}, sources_.size(), sources_.size());
    sources_.append(source);
    endInsertRows();
    emit countChanged();
}

void EpgSourceListViewModel::updateSource(int index, const QString &name, const QString &url) {
    if (!repo_ || index < 0 || index >= sources_.size()) return;
    auto source = sources_.at(index);
    source.name = name;
    source.url = url;
    if (!repo_->update(source)) {
        emit errorOccurred(QStringLiteral("Failed to update EPG source"));
        return;
    }
    sources_[index] = source;
    auto idx = this->index(index);
    emit dataChanged(idx, idx);
}

void EpgSourceListViewModel::removeSource(int index) {
    if (!repo_ || index < 0 || index >= sources_.size()) return;
    auto sourceId = sources_.at(index).id;
    if (!repo_->remove(sourceId)) {
        emit errorOccurred(QStringLiteral("Failed to remove EPG source"));
        return;
    }
    beginRemoveRows({}, index, index);
    sources_.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

void EpgSourceListViewModel::syncSource(int index) {
    if (!epgVm_ || index < 0 || index >= sources_.size() || syncing_) return;
    const auto &source = sources_.at(index);
    if (!source.enabled) {
        emit errorOccurred(QStringLiteral("Cannot sync a disabled EPG source"));
        return;
    }
    syncingIndex_ = index;
    setSyncing(true);
    setSyncStatus(QStringLiteral("Syncing %1...").arg(source.name));
    qInfo("EPG source sync started: %s (%s)",
          qPrintable(source.name), qPrintable(source.url));
    epgVm_->syncEpg(source.url);
}

void EpgSourceListViewModel::refresh() { loadSources(); }

int64_t EpgSourceListViewModel::sourceIdAt(int index) const {
    if (index < 0 || index >= sources_.size()) return 0;
    return sources_.at(index).id;
}

QString EpgSourceListViewModel::sourceUrlAt(int index) const {
    if (index < 0 || index >= sources_.size()) return {};
    return sources_.at(index).url;
}

QString EpgSourceListViewModel::sourceNameAt(int index) const {
    if (index < 0 || index >= sources_.size()) return {};
    return sources_.at(index).name;
}

int EpgSourceListViewModel::indexOfSource(int64_t sourceId) const {
    if (sourceId <= 0) return -1;
    for (int i = 0; i < sources_.size(); ++i) {
        if (sources_.at(i).id == sourceId) return i;
    }
    return -1;
}

void EpgSourceListViewModel::setEnabled(int index, bool enabled) {
    if (!repo_ || index < 0 || index >= sources_.size()) return;
    auto sourceId = sources_.at(index).id;
    if (!repo_->setEnabled(sourceId, enabled)) {
        emit errorOccurred(QStringLiteral("Failed to set EPG source enabled state"));
        return;
    }
    sources_[index].enabled = enabled;
    auto idx = this->index(index);
    emit dataChanged(idx, idx, {EnabledRole});
}

void EpgSourceListViewModel::setPrimary(int index) {
    if (!repo_ || index < 0 || index >= sources_.size()) return;
    auto sourceId = sources_.at(index).id;
    if (!repo_->setPrimary(sourceId)) {
        emit errorOccurred(QStringLiteral("Failed to set primary EPG source"));
        return;
    }
    for (int i = 0; i < sources_.size(); ++i) {
        if (sources_[i].isPrimary) {
            sources_[i].isPrimary = false;
            auto oldIdx = this->index(i);
            emit dataChanged(oldIdx, oldIdx, {IsPrimaryRole});
        }
    }
    sources_[index].isPrimary = true;
    auto idx = this->index(index);
    emit dataChanged(idx, idx, {IsPrimaryRole});
}

void EpgSourceListViewModel::setSyncing(bool value) {
    if (syncing_ == value) return;
    syncing_ = value;
    emit syncingChanged();
}

void EpgSourceListViewModel::setSyncStatus(const QString &status) {
    if (syncStatus_ == status) return;
    syncStatus_ = status;
    emit syncStatusChanged();
}

void EpgSourceListViewModel::loadSources() {
    if (!repo_) return;
    beginResetModel();
    sources_ = repo_->findAll();
    endResetModel();
    emit countChanged();
}
