// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/category_repository.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }
} // namespace

namespace iptvxs {

CategoryRepository::CategoryRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

QVector<Category> CategoryRepository::findByServer(int64_t serverId, const QString &type) const {
    QSqlQuery query(db_);
    if (type.isEmpty()) {
        query.prepare("SELECT id, server_id, external_id, name, type "
                      "FROM categories WHERE server_id = ? ORDER BY name");
        query.addBindValue(toVariant(serverId));
    } else {
        query.prepare("SELECT id, server_id, external_id, name, type "
                      "FROM categories WHERE server_id = ? AND type = ? ORDER BY name");
        query.addBindValue(toVariant(serverId));
        query.addBindValue(type);
    }

    if (!query.exec()) {
        return {};
    }

    QVector<Category> categories;
    while (query.next()) {
        categories.append(fromQuery(query));
    }
    return categories;
}

std::optional<Category> CategoryRepository::findById(int64_t id) const {
    QSqlQuery query(db_);
    query.prepare("SELECT id, server_id, external_id, name, type "
                  "FROM categories WHERE id = ?");
    query.addBindValue(toVariant(id));
    if (!query.exec() || !query.next()) {
        return std::nullopt;
    }
    return fromQuery(query);
}

int64_t CategoryRepository::upsert(const Category &category) {
    QSqlQuery query(db_);
    query.prepare("INSERT INTO categories (server_id, external_id, name, type) "
                  "VALUES (?, ?, ?, ?) "
                  "ON CONFLICT(server_id, external_id, type) DO UPDATE SET "
                  "name = excluded.name");
    query.addBindValue(toVariant(category.serverId));
    query.addBindValue(category.externalId);
    query.addBindValue(category.name);
    query.addBindValue(category.type);
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to upsert category: %1")
                               .arg(query.lastError().text()));
        return -1;
    }
    return query.lastInsertId().toLongLong();
}

void CategoryRepository::batchUpsert(const QVector<Category> &categories) {
    if (categories.isEmpty()) {
        return;
    }

    db_.transaction();
    QSqlQuery query(db_);
    query.prepare("INSERT INTO categories (server_id, external_id, name, type) "
                  "VALUES (?, ?, ?, ?) "
                  "ON CONFLICT(server_id, external_id, type) DO UPDATE SET "
                  "name = excluded.name");

    for (const auto &cat : categories) {
        query.addBindValue(toVariant(cat.serverId));
        query.addBindValue(cat.externalId);
        query.addBindValue(cat.name);
        query.addBindValue(cat.type);
        if (!query.exec()) {
            db_.rollback();
            emit errorOccurred(QStringLiteral("Batch category upsert failed: %1")
                                   .arg(query.lastError().text()));
            return;
        }
    }

    if (!db_.commit()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to commit category batch"));
    }
}

bool CategoryRepository::deleteByServer(int64_t serverId) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM categories WHERE server_id = ?");
    query.addBindValue(toVariant(serverId));
    return query.exec();
}

int CategoryRepository::count(int64_t serverId) const {
    QSqlQuery query(db_);
    query.prepare("SELECT COUNT(*) FROM categories WHERE server_id = ?");
    query.addBindValue(toVariant(serverId));
    if (!query.exec() || !query.next()) {
        return 0;
    }
    return query.value(0).toInt();
}

Category CategoryRepository::fromQuery(const QSqlQuery &query) {
    Category c;
    c.id = query.value(0).toLongLong();
    c.serverId = query.value(1).toLongLong();
    c.externalId = query.value(2).toString();
    c.name = query.value(3).toString();
    c.type = query.value(4).toString();
    return c;
}

} // namespace iptvxs
