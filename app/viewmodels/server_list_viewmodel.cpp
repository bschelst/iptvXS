// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "server_list_viewmodel.h"

#include <QBuffer>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QHash>
#include <QNetworkRequest>
#include <QUrl>

namespace {
constexpr auto kFreePlaylistUrl = "https://iptvxs.schelstraete.org/api/v1/playlist.m3u";
constexpr auto kFreeEpgUrl = "https://iptvxs.schelstraete.org/api/v1/epg.xml";
// This client-side signature is only meant to slow down casual scraping of the
// free gateway endpoints. It is not a strong security boundary.
constexpr auto kPlaylistHmacSecretB64 =
    "OWYzYTdjOGIyZDFlNmE0ZjVjMGI5ZDhlN2ExZjJjM2Q0ZTViNmE3YzhkOWUwZjFhMmIzYzRkNWU2"
    "ZjdhOGI5Yw==";

QString normalizeHttpUrl(const QString &input) {
    QUrl url(input);
    if (!url.isValid() ||
        (url.scheme() != QStringLiteral("http") && url.scheme() != QStringLiteral("https"))) {
        return {};
    }

    QString path = url.path();
    while (path.startsWith(QStringLiteral("//"))) {
        path.remove(0, 1);
    }
    url.setPath(path);
    return url.toString(QUrl::FullyEncoded);
}

QByteArray hmacSha256Hex(const QByteArray &key, const QByteArray &message) {
    constexpr int blockSize = 64;
    QByteArray normalizedKey = key;
    if (normalizedKey.size() > blockSize) {
        normalizedKey = QCryptographicHash::hash(normalizedKey, QCryptographicHash::Sha256);
    }
    normalizedKey = normalizedKey.leftJustified(blockSize, '\0', true);

    QByteArray oKeyPad(blockSize, '\0');
    QByteArray iKeyPad(blockSize, '\0');
    for (int i = 0; i < blockSize; ++i) {
        const auto keyByte = static_cast<unsigned char>(normalizedKey.at(i));
        oKeyPad[i] = static_cast<char>(keyByte ^ 0x5c);
        iKeyPad[i] = static_cast<char>(keyByte ^ 0x36);
    }

    const QByteArray inner = QCryptographicHash::hash(iKeyPad + message, QCryptographicHash::Sha256);
    return QCryptographicHash::hash(oKeyPad + inner, QCryptographicHash::Sha256).toHex();
}

QNetworkRequest buildPlaylistRequest(const QString &url) {
    QUrl qurl(url);
    QNetworkRequest request{qurl};
    request.setTransferTimeout(30000);
    request.setRawHeader("X-API-Key", QByteArrayLiteral(IPTVXS_GATEWAY_API_KEY));
    request.setRawHeader("User-Agent",
                         QStringLiteral("IPTVXs/%1")
                             .arg(QCoreApplication::applicationVersion().isEmpty()
                                      ? QStringLiteral("0.3.8")
                                      : QCoreApplication::applicationVersion())
                             .toUtf8());
    const auto timestamp = QByteArray::number(QDateTime::currentSecsSinceEpoch());
    request.setRawHeader("X-Timestamp", timestamp);
    const auto secret = QByteArray::fromBase64(QByteArray(kPlaylistHmacSecretB64));
    const auto message = timestamp + QByteArrayLiteral(":/api/v1/playlist.m3u");
    request.setRawHeader("X-Signature", hmacSha256Hex(secret, message));
    return request;
}

bool isFreePlaylistUrl(const QString &url) {
    return normalizeHttpUrl(url) == QString::fromLatin1(kFreePlaylistUrl);
}

bool hasGatewayApiKey() {
    return QStringLiteral(IPTVXS_GATEWAY_API_KEY).isEmpty() == false;
}

int findBuiltinFreeServerIndex(const QVector<iptvxs::Server> &servers) {
    for (int i = 0; i < servers.size(); ++i) {
        if (servers.at(i).isBuiltinFree) {
            return i;
        }
    }
    return -1;
}

}

ServerListViewModel::ServerListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void ServerListViewModel::setRepositories(
    iptvxs::ServerRepository *servers, iptvxs::CategoryRepository *categories,
    iptvxs::ChannelRepository *channels, iptvxs::EpgSourceRepository *epgSources) {
    serverRepo_ = servers;
    categoryRepo_ = categories;
    channelRepo_ = channels;
    epgSourceRepo_ = epgSources;
    if (epgSourceRepo_) {
        connect(epgSourceRepo_, &iptvxs::EpgSourceRepository::errorOccurred,
                this, &ServerListViewModel::errorOccurred);
    }
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
    case UrlRole: return server.isBuiltinFree ? QString() : server.url;
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
    case EpgSourceIdRole:
        return QVariant::fromValue(server.epgSourceId);
    case EpgSourceNameRole: {
        if (server.isBuiltinFree) {
            return QStringLiteral("Built-in EPG");
        }
        if (!epgSourceRepo_ || server.epgSourceId <= 0) return QString();
        auto source = epgSourceRepo_->findById(server.epgSourceId);
        return source ? source->name : QString();
    }
    case EnabledRole:
        return server.enabled;
    case IsPrimaryRole:
        return server.isPrimary;
    case IsBuiltinFreeRole:
        return server.isBuiltinFree;
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
        {EpgSourceIdRole, "epgSourceId"},
        {EpgSourceNameRole, "epgSourceName"},
        {EnabledRole, "enabled"},
        {IsPrimaryRole, "isPrimary"},
        {IsBuiltinFreeRole, "isBuiltinFree"},
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
                                    const QString &epgUrl,
                                    int64_t epgSourceId) {
    if (!serverRepo_) return;

    iptvxs::Server server;
    server.name = name;
    server.type = type;
    server.url = url;
    server.username = username;
    server.password = password;
    server.epgUrl = epgUrl;
    server.epgSourceId = epgSourceId;
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
                                       const QString &epgUrl,
                                       int64_t epgSourceId) {
    if (!serverRepo_ || index < 0 || index >= servers_.size()) return;

    auto server = servers_.at(index);
    server.name = name;
    server.url = url;
    server.username = username;
    server.password = password;
    server.epgUrl = epgUrl;
    server.epgSourceId = epgSourceId;

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
    if (srv.isBuiltinFree) {
        return normalizeHttpUrl(QString::fromLatin1(kFreeEpgUrl));
    }
    if (epgSourceRepo_ && srv.epgSourceId > 0) {
        auto source = epgSourceRepo_->findById(srv.epgSourceId);
        if (source && !source->url.isEmpty()) {
            return normalizeHttpUrl(source->url);
        }
    }
    if (!srv.epgUrl.isEmpty()) return normalizeHttpUrl(srv.epgUrl);
    if (srv.type == QStringLiteral("xtream")) {
        return normalizeHttpUrl(QStringLiteral("%1/xmltv.php?username=%2&password=%3")
                                     .arg(srv.url, srv.username, srv.password));
    }
    return {};
}

int64_t ServerListViewModel::epgSourceIdAt(int index) const {
    if (index < 0 || index >= servers_.size()) return 0;
    return servers_.at(index).epgSourceId;
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
    if (isFreeServer(index)) {
        loadServers();
    }
    emit serverEnabledChanged(serverId, enabled);
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

int64_t ServerListViewModel::builtinFreeServerId() const {
    const auto idx = findBuiltinFreeServerIndex(servers_);
    return idx >= 0 ? servers_.at(idx).id : 0;
}

int ServerListViewModel::firstLiveServerIndex() const {
    if (!channelRepo_) {
        return primaryServerIndex();
    }

    for (int i = 0; i < servers_.size(); ++i) {
        const auto &srv = servers_.at(i);
        if (!srv.enabled) continue;
        if (channelRepo_->countByServerAndType(srv.id, QStringLiteral("live")) > 0) {
            return i;
        }
    }

    const auto primary = primaryServerIndex();
    if (primary >= 0) {
        return primary;
    }

    for (int i = 0; i < servers_.size(); ++i) {
        if (servers_.at(i).enabled) return i;
    }
    return -1;
}

int ServerListViewModel::firstEnabledServerIndex() const {
    for (int i = 0; i < servers_.size(); ++i) {
        if (servers_.at(i).enabled) return i;
    }
    return -1;
}

bool ServerListViewModel::isFreeServer(int index) const {
    if (index < 0 || index >= servers_.size()) return false;
    return servers_.at(index).isBuiltinFree;
}

bool ServerListViewModel::freeServerExists() const {
    return findBuiltinFreeServerIndex(servers_) >= 0;
}

bool ServerListViewModel::freeServerEnabled() const {
    const auto idx = findBuiltinFreeServerIndex(servers_);
    return idx >= 0 ? servers_.at(idx).enabled : false;
}

void ServerListViewModel::setFreeServerEnabled(bool enabled) {
    const auto idx = findBuiltinFreeServerIndex(servers_);
    if (idx < 0 || !serverRepo_) return;
    const auto serverId = servers_.at(idx).id;
    if (!serverRepo_->setEnabled(servers_.at(idx).id, enabled)) {
        emit errorOccurred(QStringLiteral("Failed to update free server enabled state"));
        return;
    }
    loadServers();
    emit serverEnabledChanged(serverId, enabled);
}

void ServerListViewModel::reAddFreeServer() {
    if (!serverRepo_) return;
    const auto idx = findBuiltinFreeServerIndex(servers_);
    if (idx >= 0) {
        if (!servers_.at(idx).enabled) {
            setFreeServerEnabled(true);
        }
        return;
    }

    iptvxs::Server server;
    server.name = QStringLiteral("iptvXS Free");
    server.type = QStringLiteral("m3u");
    server.url = QStringLiteral("https://iptvxs.schelstraete.org/api/v1/playlist.m3u");
    server.enabled = true;
    server.isBuiltinFree = true;
    server.isPrimary = servers_.isEmpty();
    const auto id = serverRepo_->create(server);
    if (id <= 0) {
        emit errorOccurred(QStringLiteral("Failed to re-add Free iptvXS server"));
        return;
    }
    if (server.isPrimary) {
        serverRepo_->setPrimary(id);
    }
    loadServers();
    emit serverEnabledChanged(id, true);
}

void ServerListViewModel::loadServers() {
    if (!serverRepo_) return;

    beginResetModel();
    servers_ = serverRepo_->findAll();
    endResetModel();
    emit countChanged();
}

void ServerListViewModel::syncXtreamServer(const iptvxs::Server &server) {
    const auto sanitizedServerUrl = normalizeHttpUrl(server.url);
    if (sanitizedServerUrl.isEmpty()) {
        setSyncStatus(QStringLiteral("Sync failed: invalid or local server URL"));
        emit errorOccurred(QStringLiteral("Invalid or local server URL"));
        return;
    }
    setSyncing(true);
    setSyncStatus(QStringLiteral("Connecting to server..."));

    auto *http = new iptvxs::HttpClient(this);
    auto *client = new iptvxs::XtreamClient(
        http, sanitizedServerUrl, server.username, server.password, this);

    auto serverId = server.id;

    connect(client, &iptvxs::XtreamClient::liveCategoriesReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamCategory> &cats) {
                qInfo("Xtream live categories ready for server %lld: %lld",
                      static_cast<long long>(serverId),
                      static_cast<long long>(cats.size()));
                saveXtreamCategories(serverId, cats, QStringLiteral("live"));
                setSyncStatus(QStringLiteral("Fetching channels..."));
                client->fetchLiveStreams();
            });

    connect(client, &iptvxs::XtreamClient::liveStreamsReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamStream> &streams) {
                qInfo("Xtream live streams ready for server %lld: %lld",
                      static_cast<long long>(serverId),
                      static_cast<long long>(streams.size()));
                saveXtreamStreams(serverId, streams, QStringLiteral("live"),
                                 QStringLiteral("live"));
                setSyncStatus(QStringLiteral("Fetching VOD categories..."));
                client->fetchVodCategories();
            });

    connect(client, &iptvxs::XtreamClient::vodCategoriesReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamCategory> &cats) {
                qInfo("Xtream VOD categories ready for server %lld: %lld",
                      static_cast<long long>(serverId),
                      static_cast<long long>(cats.size()));
                saveXtreamCategories(serverId, cats, QStringLiteral("vod"));
                setSyncStatus(QStringLiteral("Fetching VOD streams..."));
                client->fetchVodStreams();
            });

    connect(client, &iptvxs::XtreamClient::vodStreamsReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamStream> &streams) {
                qInfo("Xtream VOD streams ready for server %lld: %lld",
                      static_cast<long long>(serverId),
                      static_cast<long long>(streams.size()));
                saveXtreamStreams(serverId, streams, QStringLiteral("vod"),
                                 QStringLiteral("movie"));
                setSyncStatus(QStringLiteral("Fetching series categories..."));
                client->fetchSeriesCategories();
            });

    connect(client, &iptvxs::XtreamClient::seriesCategoriesReady, this,
            [this, client, serverId](const QVector<iptvxs::XtreamCategory> &cats) {
                qInfo("Xtream series categories ready for server %lld: %lld",
                      static_cast<long long>(serverId),
                      static_cast<long long>(cats.size()));
                saveXtreamCategories(serverId, cats, QStringLiteral("series"));
                setSyncStatus(QStringLiteral("Fetching series..."));
                client->fetchSeries();
            });

    connect(client, &iptvxs::XtreamClient::seriesReady, this,
            [this, client, http, serverId](const QVector<iptvxs::XtreamStream> &streams) {
                qInfo("Xtream series ready for server %lld: %lld",
                      static_cast<long long>(serverId),
                      static_cast<long long>(streams.size()));
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
    const auto sanitizedServerUrl = normalizeHttpUrl(server.url);
    if (sanitizedServerUrl.isEmpty() && !isFreePlaylistUrl(server.url)) {
        setSyncStatus(QStringLiteral("Sync failed: invalid or local playlist URL"));
        emit errorOccurred(QStringLiteral("Invalid or local playlist URL"));
        return;
    }
    if (isFreePlaylistUrl(server.url) && !hasGatewayApiKey()) {
        setSyncStatus(QStringLiteral("Sync failed: built-in Free server is unavailable in this build"));
        emit errorOccurred(QStringLiteral("Built-in Free server requires a gateway API key"));
        return;
    }
    setSyncing(true);
    setSyncStatus(QStringLiteral("Downloading M3U playlist..."));

    auto *http = new iptvxs::HttpClient(this);
    auto *reply = isFreePlaylistUrl(server.url) ? http->get(buildPlaylistRequest(sanitizedServerUrl))
                                                : http->get(QUrl(sanitizedServerUrl));
    auto serverId = server.id;

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, http, server, serverId]() {
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
                if (channels.isEmpty()) {
                    qWarning("M3U sync returned no channels for server %lld; keeping existing rows",
                             static_cast<long long>(serverId));
                    setSyncStatus(QStringLiteral("Sync returned no channels; keeping existing data"));
                    setSyncing(false);
                    http->deleteLater();
                    return;
                }

                const auto playlistEpgUrl = parser.playlistEpgUrl();
                if (!playlistEpgUrl.isEmpty() && serverRepo_) {
                    auto updatedServer = server;
                    updatedServer.epgUrl = playlistEpgUrl;
                    if (!serverRepo_->update(updatedServer)) {
                        qWarning("Failed to persist playlist EPG URL for server %lld",
                                 static_cast<long long>(serverId));
                    }
                }

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
                    categoryRepo_->deleteMissingByServer(serverId, dbCats);

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
                channelRepo_->deleteMissingByServer(serverId, channels);
                if (categoryRepo_) {
                    categoryRepo_->deleteEmptyByServer(serverId);
                }

                if (serverRepo_) {
                    auto now = QDateTime::currentSecsSinceEpoch();
                    serverRepo_->updateLastSynced(serverId, now);
                }

                qInfo("Channel sync complete: %lld channels for server %lld",
                      static_cast<long long>(channels.size()),
                      static_cast<long long>(serverId));
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
    if (type == QStringLiteral("live") && cats.isEmpty()) {
        qWarning("Xtream live category sync returned no categories for server %lld; keeping existing rows",
                 static_cast<long long>(serverId));
        return;
    }
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
    categoryRepo_->deleteMissingByServerAndType(serverId, type, dbCats);
}

void ServerListViewModel::saveXtreamStreams(
    int64_t serverId, const QVector<iptvxs::XtreamStream> &streams,
    const QString &type, const QString &urlSegment) {
    if (!channelRepo_ || !serverRepo_) return;
    if (type == QStringLiteral("live") && streams.isEmpty()) {
        qWarning("Xtream live stream sync returned no streams for server %lld; keeping existing rows",
                 static_cast<long long>(serverId));
        return;
    }
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
        ch.logoUrl = normalizeHttpUrl(s.streamIcon);
        ch.categoryId = catMap.value(s.categoryId, 0);
        ch.epgChannelId = s.epgChannelId;
        ch.type = type;
        auto ext = (type == QStringLiteral("live"))
            ? QStringLiteral(".ts") : QStringLiteral(".mkv");
        const auto directSource = normalizeHttpUrl(s.directSource);
        const auto fallbackStreamUrl = normalizeHttpUrl(
            QStringLiteral("%1/%2/%3/%4/%5%6")
                .arg(srv->url, urlSegment, srv->username, srv->password,
                     s.streamId, ext));
        ch.streamUrl = !directSource.isEmpty() ? directSource : fallbackStreamUrl;
        if (ch.streamUrl.isEmpty()) {
            qWarning("Skipping stream '%s' on server %lld due to invalid or local URL",
                     qPrintable(ch.name),
                     static_cast<long long>(serverId));
            continue;
        }
        ch.addedAt = s.added;
        dbChannels.append(ch);
    }
    channelRepo_->batchUpsert(dbChannels);
    if (!dbChannels.isEmpty()) {
        channelRepo_->deleteMissingByServerAndType(serverId, type, dbChannels);
    }
    if (categoryRepo_) {
        categoryRepo_->deleteEmptyByServer(serverId, type);
    }
}
