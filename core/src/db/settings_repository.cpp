#include "iptvxs/db/settings_repository.h"

#include <QSqlError>
#include <QSqlQuery>

namespace iptvxs {

SettingsRepository::SettingsRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(std::move(db)) {}

std::optional<QString> SettingsRepository::get(const QString &key) const {
    QSqlQuery query(db_);
    query.prepare("SELECT value FROM settings WHERE key = ?");
    query.addBindValue(key);
    if (query.exec() && query.next()) {
        return query.value(0).toString();
    }
    return std::nullopt;
}

QString SettingsRepository::getString(const QString &key,
                                       const QString &defaultValue) const {
    return get(key).value_or(defaultValue);
}

int SettingsRepository::getInt(const QString &key, int defaultValue) const {
    auto val = get(key);
    if (!val) return defaultValue;
    bool ok = false;
    int result = val->toInt(&ok);
    return ok ? result : defaultValue;
}

bool SettingsRepository::getBool(const QString &key, bool defaultValue) const {
    auto val = get(key);
    if (!val) return defaultValue;
    return *val == "1" || val->toLower() == "true";
}

double SettingsRepository::getDouble(const QString &key, double defaultValue) const {
    auto val = get(key);
    if (!val) return defaultValue;
    bool ok = false;
    double result = val->toDouble(&ok);
    return ok ? result : defaultValue;
}

void SettingsRepository::set(const QString &key, const QString &value) {
    QSqlQuery query(db_);
    query.prepare(
        "INSERT INTO settings (key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value");
    query.addBindValue(key);
    query.addBindValue(value);
    if (query.exec()) {
        emit settingChanged(key, value);
    }
}

void SettingsRepository::set(const QString &key, int value) {
    set(key, QString::number(value));
}

void SettingsRepository::set(const QString &key, bool value) {
    set(key, value ? QStringLiteral("1") : QStringLiteral("0"));
}

void SettingsRepository::set(const QString &key, double value) {
    set(key, QString::number(value, 'g', 15));
}

void SettingsRepository::remove(const QString &key) {
    QSqlQuery query(db_);
    query.prepare("DELETE FROM settings WHERE key = ?");
    query.addBindValue(key);
    query.exec();
}

bool SettingsRepository::contains(const QString &key) const {
    return get(key).has_value();
}

} // namespace iptvxs
