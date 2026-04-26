#include "log_viewmodel.h"

LogViewModel::LogViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

int LogViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(filteredIndices_.size());
}

QVariant LogViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= filteredIndices_.size()) return {};

    const auto &entry = allEntries_.at(filteredIndices_.at(index.row()));
    switch (role) {
    case LevelRole: return entry.level;
    case TimestampRole: return entry.timestamp;
    case MessageRole: return entry.message;
    case ColorRole: return colorForLevel(entry.level);
    default: return {};
    }
}

QHash<int, QByteArray> LogViewModel::roleNames() const {
    return {
        {LevelRole, "level"},
        {TimestampRole, "timestamp"},
        {MessageRole, "message"},
        {ColorRole, "levelColor"},
    };
}

int LogViewModel::count() const {
    return static_cast<int>(filteredIndices_.size());
}

QString LogViewModel::filterLevel() const { return filterLevel_; }

void LogViewModel::setFilterLevel(const QString &level) {
    if (filterLevel_ != level) {
        filterLevel_ = level;
        emit filterLevelChanged();
        rebuildFiltered();
    }
}

void LogViewModel::clear() {
    beginResetModel();
    allEntries_.clear();
    filteredIndices_.clear();
    endResetModel();
    emit countChanged();
}

void LogViewModel::refresh() {
    rebuildFiltered();
}

void LogViewModel::appendLog(const QString &level, const QString &timestamp,
                             const QString &message) {
    if (allEntries_.size() >= kMaxEntries) {
        beginResetModel();
        allEntries_.remove(0, kMaxEntries / 4);
        rebuildFiltered();
        endResetModel();
    }

    int newIdx = allEntries_.size();
    allEntries_.append({level, timestamp, message});

    bool matchesFilter = filterLevel_.isEmpty() || level == filterLevel_;
    if (matchesFilter) {
        beginInsertRows({}, 0, 0);
        filteredIndices_.prepend(newIdx);
        endInsertRows();
    }

    emit countChanged();
    emit newLogEntry();
}

void LogViewModel::rebuildFiltered() {
    beginResetModel();
    filteredIndices_.clear();
    for (int i = allEntries_.size() - 1; i >= 0; --i) {
        if (filterLevel_.isEmpty() || allEntries_.at(i).level == filterLevel_) {
            filteredIndices_.append(i);
        }
    }
    endResetModel();
    emit countChanged();
}

QString LogViewModel::colorForLevel(const QString &level) {
    if (level == QStringLiteral("ERROR") || level == QStringLiteral("FATAL"))
        return QStringLiteral("#ff6b6b");
    if (level == QStringLiteral("WARN"))
        return QStringLiteral("#fdcb6e");
    if (level == QStringLiteral("INFO"))
        return QStringLiteral("#00cec9");
    return QStringLiteral("#888888");
}
