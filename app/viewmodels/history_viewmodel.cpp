// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "history_viewmodel.h"

#include <QDateTime>

HistoryViewModel::HistoryViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void HistoryViewModel::setRepository(iptvxs::HistoryRepository *repo) {
    repo_ = repo;
    loadEntries();
}

int HistoryViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return entries_.size();
}

QVariant HistoryViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= entries_.size()) return {};

    const auto &e = entries_[index.row()];
    switch (role) {
    case IdRole: return QVariant::fromValue(e.id);
    case ChannelIdRole: return QVariant::fromValue(e.channelId);
    case ChannelNameRole: return e.channelName;
    case ChannelLogoRole: return e.channelLogo;
    case ChannelTypeRole: return e.channelType;
    case WatchedAtRole: {
        auto dt = QDateTime::fromSecsSinceEpoch(e.watchedAt);
        auto now = QDateTime::currentDateTime();
        auto secsAgo = e.watchedAt > 0 ? now.toSecsSinceEpoch() - e.watchedAt : 0;
        if (secsAgo < 60) return QStringLiteral("Just now");
        if (secsAgo < 3600) return QStringLiteral("%1 min ago").arg(secsAgo / 60);
        if (secsAgo < 86400) return QStringLiteral("%1h ago").arg(secsAgo / 3600);
        return dt.toString(QStringLiteral("MMM d, HH:mm"));
    }
    case DurationRole: {
        if (e.durationSecs <= 0) return QString();
        auto m = e.durationSecs / 60;
        auto s = e.durationSecs % 60;
        return QStringLiteral("%1:%2").arg(m).arg(s, 2, 10, QLatin1Char('0'));
    }
    case StreamUrlRole:
        return e.streamUrl;
    case PositionSecsRole:
        return e.positionSecs;
    case TotalDurationSecsRole:
        return e.totalDurationSecs;
    }
    return {};
}

QHash<int, QByteArray> HistoryViewModel::roleNames() const {
    return {
        {IdRole, "historyId"},
        {ChannelIdRole, "channelId"},
        {ChannelNameRole, "channelName"},
        {ChannelLogoRole, "channelLogo"},
        {ChannelTypeRole, "channelType"},
        {WatchedAtRole, "watchedAt"},
        {DurationRole, "duration"},
        {StreamUrlRole, "streamUrl"},
        {PositionSecsRole, "positionSecs"},
        {TotalDurationSecsRole, "totalDurationSecs"},
    };
}

int HistoryViewModel::count() const { return entries_.size(); }

bool HistoryViewModel::hasMore() const {
    return entries_.size() < totalCount_;
}

void HistoryViewModel::refresh() { loadEntries(); }

void HistoryViewModel::loadMore() {
    if (!hasMore()) return;
    loadEntries(true);
}

void HistoryViewModel::removeEntry(int64_t id) {
    if (!repo_) return;
    repo_->removeEntry(id);
    loadEntries();
}

void HistoryViewModel::markFinished(int64_t id) {
    if (!repo_) return;
    repo_->markFinished(id);
    loadEntries();
}

void HistoryViewModel::clearHistory() {
    if (!repo_) return;
    beginResetModel();
    repo_->clear();
    entries_.clear();
    totalCount_ = 0;
    endResetModel();
    emit countChanged();
    emit hasMoreChanged();
}

void HistoryViewModel::loadEntries(bool append) {
    if (!repo_) return;

    int offset = append ? entries_.size() : 0;
    auto newEntries = repo_->findRecent(kPageSize, offset);
    totalCount_ = repo_->count();

    if (append) {
        if (!newEntries.isEmpty()) {
            beginInsertRows({}, entries_.size(), entries_.size() + newEntries.size() - 1);
            entries_.append(newEntries);
            endInsertRows();
        }
    } else {
        beginResetModel();
        entries_ = newEntries;
        endResetModel();
    }

    emit countChanged();
    emit hasMoreChanged();
}
