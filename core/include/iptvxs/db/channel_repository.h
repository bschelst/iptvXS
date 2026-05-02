// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/channel.h"

namespace iptvxs {

class ChannelRepository : public QObject {
    Q_OBJECT

public:
    explicit ChannelRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVector<Channel> findByServer(int64_t serverId, int limit = 200, int offset = 0) const;
    QVector<Channel> findByCategory(int64_t categoryId, int limit = 200, int offset = 0) const;
    QVector<Channel> findByServerAndType(int64_t serverId, const QString &type,
                                         int limit = 200, int offset = 0) const;
    QVector<Channel> search(int64_t serverId, const QString &query,
                            int limit = 200, int offset = 0) const;
    QVector<Channel> searchWithType(int64_t serverId, const QString &query,
                                    const QString &type, int limit = 200, int offset = 0) const;
    std::optional<Channel> findById(int64_t id) const;
    QVector<Channel> searchAll(const QString &query, int limit = 50) const;
    QVector<Channel> findRecentlyAdded(int64_t serverId, int64_t sinceSecs,
                                       int limit = 200, int offset = 0) const;
    QVector<Channel> findRecentlyAdded(int64_t serverId, int64_t sinceSecs,
                                       const QString &type, int limit = 200,
                                       int offset = 0) const;
    int countRecentlyAdded(int64_t serverId, int64_t sinceSecs) const;
    int countRecentlyAdded(int64_t serverId, int64_t sinceSecs, const QString &type) const;

    void batchUpsert(const QVector<Channel> &channels);
    bool deleteByServer(int64_t serverId);
    void deleteByServerAndTypeWithEmptyExternalId(int64_t serverId, const QString &type);
    void deleteMissingByServer(int64_t serverId, const QVector<Channel> &keepChannels);
    void deleteMissingByServerAndType(int64_t serverId, const QString &type,
                                      const QVector<Channel> &keepChannels);

    int count(int64_t serverId) const;
    int countByCategory(int64_t categoryId) const;
    int countBySearch(int64_t serverId, const QString &query) const;
    int countBySearchWithType(int64_t serverId, const QString &query, const QString &type) const;
    int countByServerAndType(int64_t serverId, const QString &type) const;

    static constexpr int kBatchSize = 500;

signals:
    void errorOccurred(const QString &message);

private:
    static Channel fromQuery(const QSqlQuery &query);
    QSqlDatabase db_;
};

} // namespace iptvxs
