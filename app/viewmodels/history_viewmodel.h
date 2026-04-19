#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/db/history_repository.h"

class HistoryViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY hasMoreChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        ChannelIdRole,
        ChannelNameRole,
        ChannelLogoRole,
        ChannelTypeRole,
        WatchedAtRole,
        DurationRole,
        StreamUrlRole
    };

    explicit HistoryViewModel(QObject *parent = nullptr);

    void setRepository(iptvxs::HistoryRepository *repo);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool hasMore() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void removeEntry(int64_t id);
    Q_INVOKABLE void clearHistory();

signals:
    void countChanged();
    void hasMoreChanged();

private:
    void loadEntries(bool append = false);

    iptvxs::HistoryRepository *repo_{nullptr};
    QVector<iptvxs::HistoryEntry> entries_;
    int totalCount_{0};
    static constexpr int kPageSize = 20;
};
