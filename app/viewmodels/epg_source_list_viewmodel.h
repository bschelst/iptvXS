// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/db/epg_source_repository.h"
#include "epg_viewmodel.h"

class EpgSourceListViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool syncing READ syncing NOTIFY syncingChanged)
    Q_PROPERTY(QString syncStatus READ syncStatus NOTIFY syncStatusChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        UrlRole,
        LastSyncedRole,
        EnabledRole,
        IsPrimaryRole
    };

    explicit EpgSourceListViewModel(QObject *parent = nullptr);

    void setRepository(iptvxs::EpgSourceRepository *repo);
    void setEpgViewModel(EpgViewModel *epgVm);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool syncing() const;
    QString syncStatus() const;

    Q_INVOKABLE void addSource(const QString &name, const QString &url);
    Q_INVOKABLE void updateSource(int index, const QString &name, const QString &url);
    Q_INVOKABLE void removeSource(int index);
    Q_INVOKABLE void syncSource(int index);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE int64_t sourceIdAt(int index) const;
    Q_INVOKABLE QString sourceUrlAt(int index) const;
    Q_INVOKABLE QString sourceNameAt(int index) const;
    Q_INVOKABLE int indexOfSource(int64_t sourceId) const;
    Q_INVOKABLE void setEnabled(int index, bool enabled);
    Q_INVOKABLE void setPrimary(int index);

signals:
    void countChanged();
    void syncingChanged();
    void syncStatusChanged();
    void errorOccurred(const QString &message);

private:
    void loadSources();
    void setSyncing(bool value);
    void setSyncStatus(const QString &status);

    iptvxs::EpgSourceRepository *repo_{nullptr};
    EpgViewModel *epgVm_{nullptr};
    QVector<iptvxs::EpgSource> sources_;
    bool syncing_{false};
    QString syncStatus_;
    int syncingIndex_{-1};
};
