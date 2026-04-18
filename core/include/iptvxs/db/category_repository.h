#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/category.h"

namespace iptvxs {

class CategoryRepository : public QObject {
    Q_OBJECT

public:
    explicit CategoryRepository(QSqlDatabase db, QObject *parent = nullptr);

    QVector<Category> findByServer(int64_t serverId, const QString &type = {}) const;
    std::optional<Category> findById(int64_t id) const;
    int64_t upsert(const Category &category);
    void batchUpsert(const QVector<Category> &categories);
    bool deleteByServer(int64_t serverId);
    int count(int64_t serverId) const;

signals:
    void errorOccurred(const QString &message);

private:
    static Category fromQuery(const QSqlQuery &query);
    QSqlDatabase db_;
};

} // namespace iptvxs
