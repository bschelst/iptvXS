#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVariant>
#include <optional>

namespace iptvxs {

class SettingsRepository : public QObject {
    Q_OBJECT

public:
    explicit SettingsRepository(QSqlDatabase db, QObject *parent = nullptr);

    QString getString(const QString &key, const QString &defaultValue = {}) const;
    int getInt(const QString &key, int defaultValue = 0) const;
    bool getBool(const QString &key, bool defaultValue = false) const;
    double getDouble(const QString &key, double defaultValue = 0.0) const;

    void set(const QString &key, const QString &value);
    void set(const QString &key, int value);
    void set(const QString &key, bool value);
    void set(const QString &key, double value);

    template <typename T>
    void set(const QString &key, T *) = delete;

    void remove(const QString &key);
    bool contains(const QString &key) const;

signals:
    void settingChanged(const QString &key, const QString &value);

private:
    std::optional<QString> get(const QString &key) const;
    QSqlDatabase db_;
};

} // namespace iptvxs
