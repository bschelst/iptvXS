#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/db/category_repository.h"
#include "iptvxs/db/category_settings_repository.h"
#include "iptvxs/models/category.h"

class CategoryListViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int64_t serverId READ serverId WRITE setServerId NOTIFY serverIdChanged)
    Q_PROPERTY(QString filterType READ filterType WRITE setFilterType NOTIFY filterTypeChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ExternalIdRole,
        TypeRole,
        HiddenRole,
        FavoriteRole,
        CustomNameRole
    };

    explicit CategoryListViewModel(QObject *parent = nullptr);

    void setRepository(iptvxs::CategoryRepository *repo);
    void setCategorySettingsRepository(iptvxs::CategorySettingsRepository *repo);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int64_t serverId() const;
    void setServerId(int64_t id);
    QString filterType() const;
    void setFilterType(const QString &type);
    int count() const;

    Q_INVOKABLE int64_t categoryIdAt(int index) const;
    Q_INVOKABLE QString categoryNameAt(int index) const;
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void toggleHidden(int64_t categoryId);
    Q_INVOKABLE void toggleFavorite(int64_t categoryId);
    Q_INVOKABLE void renameCategory(int64_t categoryId, const QString &name);
    Q_INVOKABLE bool isCategoryHidden(int64_t categoryId) const;
    Q_INVOKABLE bool isCategoryFavorite(int64_t categoryId) const;

signals:
    void serverIdChanged();
    void filterTypeChanged();
    void countChanged();

private:
    void loadCategories();

    iptvxs::CategoryRepository *repo_{nullptr};
    iptvxs::CategorySettingsRepository *settingsRepo_{nullptr};
    QVector<iptvxs::Category> categories_;
    int64_t serverId_{0};
    QString filterType_;
};
