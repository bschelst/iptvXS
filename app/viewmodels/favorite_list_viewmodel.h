// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/db/favorite_repository.h"

class FavoriteListViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool empty READ empty NOTIFY countChanged)

public:
    enum Roles {
        ChannelIdRole = Qt::UserRole + 1,
        NameRole,
        StreamUrlRole,
        LogoUrlRole,
        TypeRole,
        PositionRole,
        ExternalIdRole,
        ServerIdRole
    };

    explicit FavoriteListViewModel(QObject *parent = nullptr);

    void setRepository(iptvxs::FavoriteRepository *repo);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool empty() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void toggleFavorite(int64_t channelId);
    Q_INVOKABLE bool isFavorite(int64_t channelId) const;
    Q_INVOKABLE void moveItem(int fromIndex, int toIndex);

signals:
    void countChanged();
    void favoriteToggled(int64_t channelId, bool isFav);

private:
    void loadFavorites();

    iptvxs::FavoriteRepository *repo_{nullptr};
    QVector<iptvxs::Favorite> favorites_;
};
