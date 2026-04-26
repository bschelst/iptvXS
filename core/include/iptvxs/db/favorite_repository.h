// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/channel.h"

namespace iptvxs {

struct Favorite {
    int64_t id{0};
    int64_t channelId{0};
    int position{0};
    int64_t addedAt{0};
    Channel channel;
};

class FavoriteRepository : public QObject {
    Q_OBJECT

public:
    explicit FavoriteRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVector<Favorite> findAll() const;
    bool isFavorite(int64_t channelId) const;
    bool add(int64_t channelId);
    bool remove(int64_t channelId);
    bool toggle(int64_t channelId);
    bool reorder(int64_t channelId, int newPosition);
    int count() const;

signals:
    void favoritesChanged();
    void errorOccurred(const QString &message);

private:
    int nextPosition() const;
    QSqlDatabase db_;
};

} // namespace iptvxs
