#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/server.h"

namespace iptvxs {

class ServerRepository : public QObject {
    Q_OBJECT

public:
    explicit ServerRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVector<Server> findAll() const;
    std::optional<Server> findById(int64_t id) const;
    int64_t create(const Server &server);
    bool update(const Server &server);
    bool remove(int64_t id);
    bool updateLastSynced(int64_t id, int64_t timestamp);
    int count() const;

signals:
    void errorOccurred(const QString &message);

private:
    static Server fromQuery(const QSqlQuery &query);
    QSqlDatabase db_;
};

} // namespace iptvxs
