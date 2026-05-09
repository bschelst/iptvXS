// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/db/settings_repository.h"

#include <QDebug>
#include <QSqlError>
#include <QSqlQuery>

namespace iptvxs {

SettingsRepository::SettingsRepository(QSqlDatabase db, QObject *parent)
    : SettingsRepository(std::move(db), nullptr, parent) {}

SettingsRepository::SettingsRepository(QSqlDatabase db, CredentialVault *credentialVault, QObject *parent)
    : QObject(parent), db_(std::move(db)) {
    if (credentialVault) {
        credentialVaultPtr_ = credentialVault;
    } else {
        ownedCredentialVault_ = std::make_unique<CredentialVault>();
        credentialVaultPtr_ = ownedCredentialVault_.get();
    }
}

std::optional<QString> SettingsRepository::get(const QString &key) const {
    QSqlQuery query(db_);
    query.prepare("SELECT value FROM settings WHERE key = ?");
    query.addBindValue(key);
    if (query.exec() && query.next()) {
        return query.value(0).toString();
    }
    return std::nullopt;
}

bool SettingsRepository::isEncryptedSettingKey(const QString &key) const {
    return key == QStringLiteral("gdrive_access_token")
        || key == QStringLiteral("gdrive_refresh_token");
}

QString SettingsRepository::maybeDecryptValue(const QString &key, const QString &value) const {
    if (!credentialVaultPtr_ || value.isEmpty() || !isEncryptedSettingKey(key)) {
        return value;
    }
    const auto decrypted = credentialVaultPtr_->decrypt(value, key);
    return decrypted.isEmpty() ? value : decrypted;
}

QString SettingsRepository::maybeEncryptValue(const QString &key, const QString &value) const {
    if (!credentialVaultPtr_ || value.isEmpty() || !isEncryptedSettingKey(key)) {
        return value;
    }
    const auto encrypted = credentialVaultPtr_->encrypt(value, key);
    return encrypted.isEmpty() ? value : encrypted;
}

QString SettingsRepository::getString(const QString &key,
                                       const QString &defaultValue) const {
    auto value = get(key);
    if (!value) return defaultValue;
    return maybeDecryptValue(key, *value);
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
    const auto storedValue = maybeEncryptValue(key, value);
    query.addBindValue(storedValue);
    if (query.exec()) {
        emit settingChanged(key, storedValue);
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

bool SettingsRepository::isEncryptedStoredValue(const QString &key) const {
    if (!credentialVaultPtr_ || !isEncryptedSettingKey(key)) {
        return false;
    }
    auto value = get(key);
    return value.has_value() && credentialVaultPtr_->isEncryptedValue(*value);
}

} // namespace iptvxs
