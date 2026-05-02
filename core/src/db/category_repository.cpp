// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/category_repository.h"

#include <QSet>
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

void CategoryRepository::deleteMissingByServer(int64_t serverId,
                                               const QVector<Category> &keepCategories) {
    QSet<QString> keepKeys;
    keepKeys.reserve(keepCategories.size());
    for (const auto &cat : keepCategories) {
        keepKeys.insert(QStringLiteral("%1\u001f%2").arg(cat.type, cat.externalId));
    }

    QSqlQuery query(db_);
    query.prepare("SELECT id, external_id, type FROM categories WHERE server_id = ?");
    query.addBindValue(toVariant(serverId));
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to query stale categories: %1")
                               .arg(query.lastError().text()));
        return;
    }

    QVector<int64_t> staleIds;
    while (query.next()) {
        auto externalId = query.value(1).toString();
        auto type = query.value(2).toString();
        auto key = QStringLiteral("%1\u001f%2").arg(type, externalId);
        if (!keepKeys.contains(key)) {
            staleIds.append(query.value(0).toLongLong());
        }
    }

    if (staleIds.isEmpty()) {
        return;
    }

    if (!db_.transaction()) {
        emit errorOccurred(QStringLiteral("Failed to start category cleanup transaction"));
        return;
    }

    QSqlQuery deleteQuery(db_);
    deleteQuery.prepare("DELETE FROM categories WHERE id = ?");
    for (auto id : staleIds) {
        deleteQuery.addBindValue(toVariant(id));
        if (!deleteQuery.exec()) {
            db_.rollback();
            emit errorOccurred(QStringLiteral("Failed to delete stale category: %1")
                                   .arg(deleteQuery.lastError().text()));
            return;
        }
        deleteQuery.finish();
    }

    if (!db_.commit()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to commit stale category cleanup"));
    }
}

void CategoryRepository::deleteMissingByServerAndType(
    int64_t serverId, const QString &type, const QVector<Category> &keepCategories) {
    QSet<QString> keepKeys;
    keepKeys.reserve(keepCategories.size());
    for (const auto &cat : keepCategories) {
        keepKeys.insert(QStringLiteral("%1\u001f%2").arg(cat.type, cat.externalId));
    }

    QSqlQuery query(db_);
    query.prepare("SELECT id, external_id, type FROM categories "
                  "WHERE server_id = ? AND type = ?");
    query.addBindValue(toVariant(serverId));
    query.addBindValue(type);
    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to query stale categories: %1")
                               .arg(query.lastError().text()));
        return;
    }

    QVector<int64_t> staleIds;
    while (query.next()) {
        auto externalId = query.value(1).toString();
        auto rowType = query.value(2).toString();
        auto key = QStringLiteral("%1\u001f%2").arg(rowType, externalId);
        if (!keepKeys.contains(key)) {
            staleIds.append(query.value(0).toLongLong());
        }
    }

    if (staleIds.isEmpty()) {
        return;
    }

    if (!db_.transaction()) {
        emit errorOccurred(QStringLiteral("Failed to start category cleanup transaction"));
        return;
    }

    QSqlQuery deleteQuery(db_);
    deleteQuery.prepare("DELETE FROM categories WHERE id = ?");
    for (auto id : staleIds) {
        deleteQuery.addBindValue(toVariant(id));
        if (!deleteQuery.exec()) {
            db_.rollback();
            emit errorOccurred(QStringLiteral("Failed to delete stale category: %1")
                                   .arg(deleteQuery.lastError().text()));
            return;
        }
        deleteQuery.finish();
    }

    if (!db_.commit()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to commit stale category cleanup"));
    }
}

void CategoryRepository::deleteEmptyByServer(int64_t serverId, const QString &type) {
    QSqlQuery query(db_);
    if (type.isEmpty()) {
        query.prepare("SELECT c.id, c.name, c.type "
                      "FROM categories c "
                      "LEFT JOIN channels ch ON ch.category_id = c.id "
                      "WHERE c.server_id = ? "
                      "GROUP BY c.id "
                      "HAVING COUNT(ch.id) = 0");
        query.addBindValue(toVariant(serverId));
    } else {
        query.prepare("SELECT c.id, c.name, c.type "
                      "FROM categories c "
                      "LEFT JOIN channels ch ON ch.category_id = c.id "
                      "WHERE c.server_id = ? AND c.type = ? "
                      "GROUP BY c.id "
                      "HAVING COUNT(ch.id) = 0");
        query.addBindValue(toVariant(serverId));
        query.addBindValue(type);
    }

    if (!query.exec()) {
        emit errorOccurred(QStringLiteral("Failed to query empty categories: %1")
                               .arg(query.lastError().text()));
        return;
    }

    QVector<int64_t> staleIds;
    QVector<QString> staleNames;
    QVector<QString> staleTypes;
    while (query.next()) {
        staleIds.append(query.value(0).toLongLong());
        staleNames.append(query.value(1).toString());
        staleTypes.append(query.value(2).toString());
    }

    if (staleIds.isEmpty()) {
        return;
    }

    if (!db_.transaction()) {
        emit errorOccurred(QStringLiteral("Failed to start empty category cleanup transaction"));
        return;
    }

    QSqlQuery deleteQuery(db_);
    deleteQuery.prepare("DELETE FROM categories WHERE id = ?");
    for (int i = 0; i < staleIds.size(); ++i) {
        deleteQuery.addBindValue(toVariant(staleIds.at(i)));
        if (!deleteQuery.exec()) {
            db_.rollback();
            emit errorOccurred(QStringLiteral("Failed to delete empty category: %1")
                                   .arg(deleteQuery.lastError().text()));
            return;
        }
        qInfo("Removed empty category during sync: %s [%s] (id %lld)",
              qPrintable(staleNames.at(i)),
              qPrintable(staleTypes.at(i)),
              static_cast<long long>(staleIds.at(i)));
        deleteQuery.finish();
    }

    if (!db_.commit()) {
        db_.rollback();
        emit errorOccurred(QStringLiteral("Failed to commit empty category cleanup"));
    }
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
