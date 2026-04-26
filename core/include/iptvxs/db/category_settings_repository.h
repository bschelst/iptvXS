// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QMap>
#include <QObject>
#include <QSet>
#include <QSqlDatabase>
#include <QString>

namespace iptvxs {

class CategorySettingsRepository : public QObject {
    Q_OBJECT

public:
    explicit CategorySettingsRepository(QSqlDatabase db, QObject *parent = nullptr);

    bool isHidden(int64_t categoryId) const;
    bool isFavorite(int64_t categoryId) const;
    QString customName(int64_t categoryId) const;

    void setHidden(int64_t categoryId, bool hidden);
    void setFavorite(int64_t categoryId, bool favorite);
    void setCustomName(int64_t categoryId, const QString &name);

    QSet<int64_t> hiddenCategoryIds() const;
    QSet<int64_t> favoriteCategoryIds() const;
    QMap<int64_t, QString> customNames() const;

signals:
    void settingsChanged();
    void errorOccurred(const QString &message);

private:
    void ensureRow(int64_t categoryId);
    QSqlDatabase db_;
};

} // namespace iptvxs
