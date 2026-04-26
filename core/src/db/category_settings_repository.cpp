// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/category_settings_repository.h"

#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

namespace {
inline QVariant toVariant(int64_t val) { return QVariant(static_cast<qlonglong>(val)); }
} // namespace

namespace iptvxs {

CategorySettingsRepository::CategorySettingsRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

void CategorySettingsRepository::ensureRow(int64_t categoryId) {
    QSqlQuery q(db_);
    q.prepare("INSERT OR IGNORE INTO category_settings (category_id) VALUES (?)");
    q.addBindValue(toVariant(categoryId));
    q.exec();
}

bool CategorySettingsRepository::isHidden(int64_t categoryId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT hidden FROM category_settings WHERE category_id = ?");
    q.addBindValue(toVariant(categoryId));
    if (!q.exec() || !q.next()) return false;
    return q.value(0).toInt() != 0;
}

bool CategorySettingsRepository::isFavorite(int64_t categoryId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT favorite FROM category_settings WHERE category_id = ?");
    q.addBindValue(toVariant(categoryId));
    if (!q.exec() || !q.next()) return false;
    return q.value(0).toInt() != 0;
}

QString CategorySettingsRepository::customName(int64_t categoryId) const {
    QSqlQuery q(db_);
    q.prepare("SELECT custom_name FROM category_settings WHERE category_id = ?");
    q.addBindValue(toVariant(categoryId));
    if (!q.exec() || !q.next()) return {};
    return q.value(0).toString();
}

void CategorySettingsRepository::setHidden(int64_t categoryId, bool hidden) {
    ensureRow(categoryId);
    QSqlQuery q(db_);
    q.prepare("UPDATE category_settings SET hidden = ? WHERE category_id = ?");
    q.addBindValue(hidden ? 1 : 0);
    q.addBindValue(toVariant(categoryId));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set hidden: %1").arg(q.lastError().text()));
        return;
    }
    emit settingsChanged();
}

void CategorySettingsRepository::setFavorite(int64_t categoryId, bool favorite) {
    ensureRow(categoryId);
    QSqlQuery q(db_);
    q.prepare("UPDATE category_settings SET favorite = ? WHERE category_id = ?");
    q.addBindValue(favorite ? 1 : 0);
    q.addBindValue(toVariant(categoryId));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set favorite: %1").arg(q.lastError().text()));
        return;
    }
    emit settingsChanged();
}

void CategorySettingsRepository::setCustomName(int64_t categoryId, const QString &name) {
    ensureRow(categoryId);
    QSqlQuery q(db_);
    q.prepare("UPDATE category_settings SET custom_name = ? WHERE category_id = ?");
    q.addBindValue(name);
    q.addBindValue(toVariant(categoryId));
    if (!q.exec()) {
        emit errorOccurred(QStringLiteral("Failed to set custom name: %1").arg(q.lastError().text()));
        return;
    }
    emit settingsChanged();
}

QSet<int64_t> CategorySettingsRepository::hiddenCategoryIds() const {
    QSet<int64_t> ids;
    QSqlQuery q(db_);
    if (!q.exec("SELECT category_id FROM category_settings WHERE hidden = 1")) return ids;
    while (q.next()) {
        ids.insert(q.value(0).toLongLong());
    }
    return ids;
}

QSet<int64_t> CategorySettingsRepository::favoriteCategoryIds() const {
    QSet<int64_t> ids;
    QSqlQuery q(db_);
    if (!q.exec("SELECT category_id FROM category_settings WHERE favorite = 1")) return ids;
    while (q.next()) {
        ids.insert(q.value(0).toLongLong());
    }
    return ids;
}

QMap<int64_t, QString> CategorySettingsRepository::customNames() const {
    QMap<int64_t, QString> names;
    QSqlQuery q(db_);
    if (!q.exec("SELECT category_id, custom_name FROM category_settings WHERE custom_name != ''"))
        return names;
    while (q.next()) {
        names.insert(q.value(0).toLongLong(), q.value(1).toString());
    }
    return names;
}

} // namespace iptvxs
