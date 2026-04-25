#include "server_list_viewmodel.h"

#include <QBuffer>
#include <QDateTime>
#include <QUrl>

namespace {
QString normalizeHttpUrl(const QString &input) {
    QUrl url(input);
    if (!url.isValid() ||
        (url.scheme() != QStringLiteral("http") && url.scheme() != QStringLiteral("https"))) {
        return input;
    }

    QString path = url.path();
    while (path.startsWith(QStringLiteral("//"))) {
        path.remove(0, 1);
    }
    url.setPath(path);
    return url.toString(QUrl::FullyEncoded);
}
}

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
        return channelRepo_
            ? channelRepo_->countByServerAndType(server.id, QStringLiteral("live"))
            : 0;
    case VodCountRole:
        return channelRepo_
            ? channelRepo_->countByServerAndType(server.id, QStringLiteral("vod"))
            : 0;
    case SeriesCountRole:
        return channelRepo_
            ? channelRepo_->countByServerAndType(server.id, QStringLiteral("series"))
            : 0;
    case EpgUrlRole:
        return server.epgUrl;
    case EnabledRole:
        return server.enabled;
    case IsPrimaryRole:
        return server.isPrimary;
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
        {VodCountRole, "vodCount"},
        {SeriesCountRole, "seriesCount"},
        {EpgUrlRole, "epgUrl"},
        {EnabledRole, "enabled"},
        {IsPrimaryRole, "isPrimary"},
    };
}

int ServerListViewModel::count() const {
    return static_cast<int>(servers_.size());
}

bool ServerListViewModel::syncing() const { return syncing_; }

QString ServerListViewModel::syncStatus() const { return syncStatus_; }

void ServerListViewModel::addServer(const QString &name, const QString &type,
                                    const QString &url, const QString &username,
                                    const QString &password,
                                    const QString &epgUrl) {
    if (!serverRepo_) return;

    iptvxs::Server server;
    server.name = name;
    server.type = type;
    server.url = url;
    server.username = username;
    server.password = password;
    server.epgUrl = epgUrl;
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

void ServerListViewModel::updateServer(int index, const QString &name,
                                       const QString &url, const QString &username,
                                       const QString &password,
                                       const QString &epgUrl) {
    if (!serverRepo_ || index < 0 || index >= servers_.size()) return;

    auto server = servers_.at(index);
    server.name = name;
    server.url = url;
    server.username = username;
    server.password = password;
    server.epgUrl = epgUrl;

    if (!serverRepo_->update(server)) {
        emit errorOccurred(QStringLiteral("Failed to update server"));
        return;
    }

    servers_[index] = server;
    auto idx = this->index(index);
    emit dataChanged(idx, idx);
}

QString ServerListViewModel::passwordAt(int index) const {
    if (index < 0 || index >= servers_.size()) return {};
    return servers_.at(index).password;
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
    if (!server.enabled) {
        emit errorOccurred(QStringLiteral("Cannot sync a disabled server"));
        return;
    }
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

QString ServerListViewModel::epgUrlAt(int index) const {
    if (index < 0 || index >= servers_.size()) return {};
    const auto &srv = servers_.at(index);
    if (!srv.epgUrl.isEmpty()) return normalizeHttpUrl(srv.epgUrl);
    if (srv.type == QStringLiteral("xtream")) {
        return normalizeHttpUrl(QStringLiteral("%1/xmltv.php?username=%2&password=%3")
                                     .arg(srv.url, srv.username, srv.password));
    }
    return {};
}

void ServerListViewModel::setEnabled(int index, bool enabled) {
    if (!serverRepo_ || index < 0 || index >= servers_.size()) return;

    auto serverId = servers_.at(index).id;
    if (!serverRepo_->setEnabled(serverId, enabled)) {
        emit errorOccurred(QStringLiteral("Failed to set server enabled state"));
        return;
    }

    servers_[index].enabled = enabled;
    auto idx = this->index(index);
    emit dataChanged(idx, idx, {EnabledRole});
}

void ServerListViewModel::setPrimary(int index) {
    if (!serverRepo_ || index < 0 || index >= servers_.size()) return;

    auto serverId = servers_.at(index).id;
    if (!serverRepo_->setPrimary(serverId)) {
        emit errorOccurred(QStringLiteral("Failed to set primary server"));
        return;
    }

    // Update local state: clear old primary, set new
    for (int i = 0; i < servers_.size(); ++i) {
        if (servers_[i].isPrimary) {
            servers_[i].isPrimary = false;
            auto oldIdx = this->index(i);
            emit dataChanged(oldIdx, oldIdx, {IsPrimaryRole});
        }
    }
    servers_[index].isPrimary = true;
    auto idx = this->index(index);
    emit dataChanged(idx, idx, {IsPrimaryRole});
}

int ServerListViewModel::primaryServerIndex() const {
    for (int i = 0; i < servers_.size(); ++i) {
        if (servers_.at(i).isPrimary && servers_.at(i).enabled) return i;
    }
    return -1;
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
                saveXtreamCategories(serverId, cats, QStringLiteral("live"));
                setSyncStatus(QStringLiteral("Fetching channels..."));
                client->fetchLiveStreams();
            });

    connect(client, &iptvxs::XtreamClient::liveStreamsReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamStream> &streams) {
                saveXtreamStreams(serverId, streams, QStringLiteral("live"),
                                 QStringLiteral("live"));
                setSyncStatus(QStringLiteral("Fetching VOD categories..."));
                client->fetchVodCategories();
            });

    connect(client, &iptvxs::XtreamClient::vodCategoriesReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamCategory> &cats) {
                saveXtreamCategories(serverId, cats, QStringLiteral("vod"));
                setSyncStatus(QStringLiteral("Fetching VOD streams..."));
                client->fetchVodStreams();
            });

    connect(client, &iptvxs::XtreamClient::vodStreamsReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamStream> &streams) {
                saveXtreamStreams(serverId, streams, QStringLiteral("vod"),
                                 QStringLiteral("movie"));
                setSyncStatus(QStringLiteral("Fetching series categories..."));
                client->fetchSeriesCategories();
            });

    connect(client, &iptvxs::XtreamClient::seriesCategoriesReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamCategory> &cats) {
                saveXtreamCategories(serverId, cats, QStringLiteral("series"));
                setSyncStatus(QStringLiteral("Fetching series..."));
                client->fetchSeries();
            });

    connect(client, &iptvxs::XtreamClient::seriesReady, this,
            [this, client, http, serverId](const QVector<iptvxs::XtreamStream> &streams) {
                saveXtreamStreams(serverId, streams, QStringLiteral("series"),
                                 QStringLiteral("series"));

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

                // Save discovered categories and build group→id map
                QHash<QString, int64_t> catMap;
                if (categoryRepo_) {
                    QSet<QString> groups;
                    for (const auto &ch : channels) {
                        if (!ch.groupTitle.isEmpty())
                            groups.insert(ch.groupTitle);
                    }

                    QHash<QString, QString> groupTypes;
                    for (const auto &ch : channels) {
                        if (!ch.groupTitle.isEmpty() && !groupTypes.contains(ch.groupTitle)) {
                            groupTypes[ch.groupTitle] = ch.type;
                        }
                    }

                    QVector<iptvxs::Category> dbCats;
                    dbCats.reserve(groups.size());
                    for (const auto &g : groups) {
                        iptvxs::Category cat;
                        cat.serverId = serverId;
                        cat.externalId = g;
                        cat.name = g;
                        cat.type = groupTypes.value(g, QStringLiteral("live"));
                        dbCats.append(cat);
                    }
                    categoryRepo_->batchUpsert(dbCats);

                    auto savedCats = categoryRepo_->findByServer(serverId);
                    for (const auto &c : savedCats) {
                        catMap[c.name] = c.id;
                    }
                }

                // Assign category IDs to channels
                for (auto &ch : channels) {
                    if (!ch.groupTitle.isEmpty())
                        ch.categoryId = catMap.value(ch.groupTitle, 0);
                }

                setSyncStatus(
                    QStringLiteral("Saving %1 channels...").arg(channels.size()));

                channelRepo_->batchUpsert(channels);

                if (serverRepo_) {
                    auto now = QDateTime::currentSecsSinceEpoch();
                    serverRepo_->updateLastSynced(serverId, now);
                }

                qInfo("Channel sync complete: %d channels for server %lld",
                      channels.size(), serverId);
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

void ServerListViewModel::saveXtreamCategories(
    int64_t serverId, const QVector<iptvxs::XtreamCategory> &cats,
    const QString &type) {
    if (!categoryRepo_) return;
    setSyncStatus(QStringLiteral("Saving %1 %2 categories...")
                      .arg(cats.size())
                      .arg(type));

    QVector<iptvxs::Category> dbCats;
    dbCats.reserve(cats.size());
    for (const auto &c : cats) {
        iptvxs::Category cat;
        cat.serverId = serverId;
        cat.externalId = c.categoryId;
        cat.name = c.categoryName;
        cat.type = type;
        dbCats.append(cat);
    }
    categoryRepo_->batchUpsert(dbCats);
}

void ServerListViewModel::saveXtreamStreams(
    int64_t serverId, const QVector<iptvxs::XtreamStream> &streams,
    const QString &type, const QString &urlSegment) {
    if (!channelRepo_ || !serverRepo_) return;
    setSyncStatus(QStringLiteral("Saving %1 %2 streams...")
                      .arg(streams.size())
                      .arg(type));

    auto srv = serverRepo_->findById(serverId);
    if (!srv) return;

    QHash<QString, int64_t> catMap;
    if (categoryRepo_) {
        auto cats = categoryRepo_->findByServer(serverId);
        for (const auto &c : cats) {
            catMap[c.externalId] = c.id;
        }
    }

    channelRepo_->deleteByServerAndTypeWithEmptyExternalId(serverId, type);

    QVector<iptvxs::Channel> dbChannels;
    dbChannels.reserve(streams.size());
    for (const auto &s : streams) {
        if (s.streamId.isEmpty() && s.directSource.isEmpty()) continue;

        iptvxs::Channel ch;
        ch.serverId = serverId;
        ch.externalId = s.streamId;
        ch.name = s.name;
        ch.logoUrl = s.streamIcon;
        ch.categoryId = catMap.value(s.categoryId, 0);
        ch.epgChannelId = s.epgChannelId;
        ch.type = type;
        auto ext = (type == QStringLiteral("live"))
            ? QStringLiteral(".ts") : QStringLiteral(".mkv");
        ch.streamUrl = s.directSource.isEmpty()
            ? QStringLiteral("%1/%2/%3/%4/%5%6")
                  .arg(srv->url, urlSegment, srv->username, srv->password,
                       s.streamId, ext)
            : s.directSource;
        ch.addedAt = s.added;
        dbChannels.append(ch);
    }
    channelRepo_->batchUpsert(dbChannels);
}
