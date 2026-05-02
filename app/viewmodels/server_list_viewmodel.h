// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/api/xtream_client.h"
#include "iptvxs/db/epg_source_repository.h"
#include "iptvxs/db/category_repository.h"
#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/server_repository.h"
#include "iptvxs/models/server.h"
#include "iptvxs/net/http_client.h"
#include "iptvxs/parser/m3u_parser.h"

class ServerListViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool syncing READ syncing NOTIFY syncingChanged)
    Q_PROPERTY(QString syncStatus READ syncStatus NOTIFY syncStatusChanged)
    Q_PROPERTY(bool freeServerExists READ freeServerExists NOTIFY countChanged)
    Q_PROPERTY(bool freeServerEnabled READ freeServerEnabled NOTIFY countChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        TypeRole,
        UrlRole,
        UsernameRole,
        LastSyncedRole,
        ChannelCountRole,
        VodCountRole,
        SeriesCountRole,
        EpgUrlRole,
        EpgSourceIdRole,
        EpgSourceNameRole,
        EnabledRole,
        IsPrimaryRole,
        IsBuiltinFreeRole
    };

    explicit ServerListViewModel(QObject *parent = nullptr);

    void setRepositories(iptvxs::ServerRepository *servers,
                         iptvxs::CategoryRepository *categories,
                         iptvxs::ChannelRepository *channels,
                         iptvxs::EpgSourceRepository *epgSources);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool syncing() const;
    QString syncStatus() const;

    Q_INVOKABLE void addServer(const QString &name, const QString &type,
                               const QString &url, const QString &username,
                               const QString &password,
                               const QString &epgUrl = {},
                               int64_t epgSourceId = 0);
    Q_INVOKABLE void updateServer(int index, const QString &name,
                                  const QString &url, const QString &username,
                                  const QString &password,
                                  const QString &epgUrl = {},
                                  int64_t epgSourceId = 0);
    Q_INVOKABLE QString passwordAt(int index) const;
    Q_INVOKABLE void removeServer(int index);
    Q_INVOKABLE void syncServer(int index);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE int64_t serverIdAt(int index) const;
    Q_INVOKABLE QString epgUrlAt(int index) const;
    Q_INVOKABLE int64_t epgSourceIdAt(int index) const;
    Q_INVOKABLE void setEnabled(int index, bool enabled);
    Q_INVOKABLE void setPrimary(int index);
    Q_INVOKABLE int primaryServerIndex() const;
    Q_INVOKABLE int64_t builtinFreeServerId() const;
    Q_INVOKABLE int firstLiveServerIndex() const;
    Q_INVOKABLE bool isFreeServer(int index) const;
    Q_INVOKABLE bool freeServerExists() const;
    Q_INVOKABLE bool freeServerEnabled() const;
    Q_INVOKABLE void setFreeServerEnabled(bool enabled);
    Q_INVOKABLE void reAddFreeServer();

signals:
    void countChanged();
    void syncingChanged();
    void syncStatusChanged();
    void syncFinished(int64_t serverId);
    void errorOccurred(const QString &message);

private:
    void loadServers();
    void syncXtreamServer(const iptvxs::Server &server);
    void syncM3uServer(const iptvxs::Server &server);
    void setSyncing(bool value);
    void setSyncStatus(const QString &status);
    void saveXtreamCategories(int64_t serverId,
                              const QVector<iptvxs::XtreamCategory> &cats,
                              const QString &type);
    void saveXtreamStreams(int64_t serverId,
                           const QVector<iptvxs::XtreamStream> &streams,
                           const QString &type, const QString &urlSegment);

    iptvxs::ServerRepository *serverRepo_{nullptr};
    iptvxs::CategoryRepository *categoryRepo_{nullptr};
    iptvxs::ChannelRepository *channelRepo_{nullptr};
    iptvxs::EpgSourceRepository *epgSourceRepo_{nullptr};

    QVector<iptvxs::Server> servers_;
    bool syncing_{false};
    QString syncStatus_;
};
