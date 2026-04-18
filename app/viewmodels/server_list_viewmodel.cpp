#include "server_list_viewmodel.h"

#include <QBuffer>
#include <QDateTime>

ServerListViewModel::ServerListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void ServerListViewModel::setRepositories(
    iptvxs::ServerRepository *servers, iptvxs::CategoryRepository *categories,
    iptvxs::ChannelRepository *channels) {
    serverRepo_ = servers;
    categoryRepo_ = categories;
    channelRepo_ = channels;
    loadServers();
}

int ServerListViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(servers_.size());
}

QVariant ServerListViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= servers_.size()) return {};

    const auto &server = servers_.at(index.row());
    switch (role) {
    case IdRole: return QVariant::fromValue(server.id);
    case NameRole: return server.name;
    case TypeRole: return server.type;
    case UrlRole: return server.url;
    case UsernameRole: return server.username;
    case LastSyncedRole: {
        if (server.lastSyncedAt == 0) return QStringLiteral("Never");
        auto dt = QDateTime::fromSecsSinceEpoch(server.lastSyncedAt);
        return dt.toString(QStringLiteral("yyyy-MM-dd HH:mm"));
    }
    case ChannelCountRole:
        return channelRepo_ ? channelRepo_->count(server.id) : 0;
    default: return {};
    }
}

QHash<int, QByteArray> ServerListViewModel::roleNames() const {
    return {
        {IdRole, "serverId"},
        {NameRole, "name"},
        {TypeRole, "type"},
        {UrlRole, "url"},
        {UsernameRole, "username"},
        {LastSyncedRole, "lastSynced"},
        {ChannelCountRole, "channelCount"},
    };
}

int ServerListViewModel::count() const {
    return static_cast<int>(servers_.size());
}

bool ServerListViewModel::syncing() const { return syncing_; }

QString ServerListViewModel::syncStatus() const { return syncStatus_; }

void ServerListViewModel::addServer(const QString &name, const QString &type,
                                    const QString &url, const QString &username,
                                    const QString &password) {
    if (!serverRepo_) return;

    iptvxs::Server server;
    server.name = name;
    server.type = type;
    server.url = url;
    server.username = username;
    server.password = password;
    server.createdAt = QDateTime::currentSecsSinceEpoch();

    auto id = serverRepo_->create(server);
    if (id <= 0) {
        emit errorOccurred(QStringLiteral("Failed to add server"));
        return;
    }

    server.id = id;
    beginInsertRows({}, servers_.size(), servers_.size());
    servers_.append(server);
    endInsertRows();
    emit countChanged();
}

void ServerListViewModel::removeServer(int index) {
    if (!serverRepo_ || index < 0 || index >= servers_.size()) return;

    auto serverId = servers_.at(index).id;
    if (!serverRepo_->remove(serverId)) {
        emit errorOccurred(QStringLiteral("Failed to remove server"));
        return;
    }

    if (channelRepo_) channelRepo_->deleteByServer(serverId);
    if (categoryRepo_) categoryRepo_->deleteByServer(serverId);

    beginRemoveRows({}, index, index);
    servers_.removeAt(index);
    endRemoveRows();
    emit countChanged();
}

void ServerListViewModel::syncServer(int index) {
    if (index < 0 || index >= servers_.size() || syncing_) return;

    const auto &server = servers_.at(index);
    if (server.type == QStringLiteral("xtream")) {
        syncXtreamServer(server);
    } else {
        syncM3uServer(server);
    }
}

void ServerListViewModel::refresh() { loadServers(); }

int64_t ServerListViewModel::serverIdAt(int index) const {
    if (index < 0 || index >= servers_.size()) return 0;
    return servers_.at(index).id;
}

void ServerListViewModel::loadServers() {
    if (!serverRepo_) return;

    beginResetModel();
    servers_ = serverRepo_->findAll();
    endResetModel();
    emit countChanged();
}

void ServerListViewModel::syncXtreamServer(const iptvxs::Server &server) {
    setSyncing(true);
    setSyncStatus(QStringLiteral("Connecting to server..."));

    auto *http = new iptvxs::HttpClient(this);
    auto *client = new iptvxs::XtreamClient(
        http, server.url, server.username, server.password, this);

    auto serverId = server.id;

    connect(client, &iptvxs::XtreamClient::liveCategoriesReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamCategory> &cats) {
                if (!categoryRepo_) return;
                setSyncStatus(QStringLiteral("Saving %1 categories...").arg(cats.size()));

                QVector<iptvxs::Category> dbCats;
                dbCats.reserve(cats.size());
                for (const auto &c : cats) {
                    iptvxs::Category cat;
                    cat.serverId = serverId;
                    cat.externalId = c.categoryId;
                    cat.name = c.categoryName;
                    cat.type = QStringLiteral("live");
                    dbCats.append(cat);
                }
                categoryRepo_->batchUpsert(dbCats);

                setSyncStatus(QStringLiteral("Fetching channels..."));
                client->fetchLiveStreams();
            });

    connect(client, &iptvxs::XtreamClient::liveStreamsReady, this,
            [this, client, http, serverId](const QVector<iptvxs::XtreamStream> &streams) {
                if (!channelRepo_) return;
                setSyncStatus(QStringLiteral("Saving %1 channels...").arg(streams.size()));

                QVector<iptvxs::Channel> dbChannels;
                dbChannels.reserve(streams.size());
                for (const auto &s : streams) {
                    iptvxs::Channel ch;
                    ch.serverId = serverId;
                    ch.externalId = s.streamId;
                    ch.name = s.name;
                    ch.logoUrl = s.streamIcon;
                    ch.categoryId = 0;
                    ch.epgChannelId = s.epgChannelId;
                    ch.type = QStringLiteral("live");
                    ch.streamUrl = s.directSource.isEmpty()
                        ? QStringLiteral("%1/live/%2/%3/%4.ts")
                              .arg(QString(), QString(), QString(), s.streamId)
                        : s.directSource;
                    ch.addedAt = s.added;
                    dbChannels.append(ch);
                }
                channelRepo_->batchUpsert(dbChannels);

                if (serverRepo_) {
                    auto now = QDateTime::currentSecsSinceEpoch();
                    serverRepo_->updateLastSynced(serverId, now);
                }

                setSyncStatus(QStringLiteral("Sync complete"));
                setSyncing(false);
                loadServers();
                emit syncFinished(serverId);

                client->deleteLater();
                http->deleteLater();
            });

    connect(client, &iptvxs::XtreamClient::errorOccurred, this,
            [this, client, http](const QString &msg) {
                setSyncStatus(QStringLiteral("Sync failed: %1").arg(msg));
                setSyncing(false);
                emit errorOccurred(msg);
                client->deleteLater();
                http->deleteLater();
            });

    setSyncStatus(QStringLiteral("Fetching categories..."));
    client->fetchLiveCategories();
}

void ServerListViewModel::syncM3uServer(const iptvxs::Server &server) {
    setSyncing(true);
    setSyncStatus(QStringLiteral("Downloading M3U playlist..."));

    auto *http = new iptvxs::HttpClient(this);
    auto *reply = http->get(QUrl(server.url));
    auto serverId = server.id;

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, http, serverId]() {
                if (reply->error() != QNetworkReply::NoError) {
                    setSyncStatus(
                        QStringLiteral("Download failed: %1").arg(reply->errorString()));
                    setSyncing(false);
                    emit errorOccurred(reply->errorString());
                    reply->deleteLater();
                    http->deleteLater();
                    return;
                }

                auto data = reply->readAll();
                reply->deleteLater();

                setSyncStatus(QStringLiteral("Parsing playlist..."));

                QBuffer buffer(&data);
                buffer.open(QIODevice::ReadOnly);
                iptvxs::M3uParser parser;
                auto channels = parser.parseAll(&buffer, serverId);

                setSyncStatus(
                    QStringLiteral("Saving %1 channels...").arg(channels.size()));

                channelRepo_->batchUpsert(channels);

                if (serverRepo_) {
                    auto now = QDateTime::currentSecsSinceEpoch();
                    serverRepo_->updateLastSynced(serverId, now);
                }

                setSyncStatus(QStringLiteral("Sync complete"));
                setSyncing(false);
                loadServers();
                emit syncFinished(serverId);
                http->deleteLater();
            });
}

void ServerListViewModel::setSyncing(bool value) {
    if (syncing_ != value) {
        syncing_ = value;
        emit syncingChanged();
    }
}

void ServerListViewModel::setSyncStatus(const QString &status) {
    if (syncStatus_ != status) {
        syncStatus_ = status;
        emit syncStatusChanged();
    }
}
