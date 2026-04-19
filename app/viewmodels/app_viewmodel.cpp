#include "app_viewmodel.h"
#include "log_viewmodel.h"

#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonObject>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTimer>

AppViewModel::AppViewModel(QObject *parent)
    : QObject(parent),
      serverListVm_(new ServerListViewModel(this)),
      categoryListVm_(new CategoryListViewModel(this)),
      channelListVm_(new ChannelListViewModel(this)),
      playerVm_(new PlayerViewModel(this)),
      favoriteListVm_(new FavoriteListViewModel(this)),
      epgVm_(new EpgViewModel(this)),
      recordingListVm_(new RecordingListViewModel(this)),
      gdriveVm_(new GDriveViewModel(this)),
      speedTestVm_(new SpeedTestViewModel(this)) {}

AppViewModel::~AppViewModel() = default;

bool AppViewModel::initialize(const QString &dbPath) {
    database_ = std::make_unique<iptvxs::Database>(this);

    connect(database_.get(), &iptvxs::Database::errorOccurred, this,
            &AppViewModel::errorOccurred);

    if (!database_->open(dbPath)) {
        return false;
    }

    auto db = database_->connection();

    settingsRepo_ = std::make_unique<iptvxs::SettingsRepository>(db, this);
    serverRepo_ = std::make_unique<iptvxs::ServerRepository>(db, this);
    categoryRepo_ = std::make_unique<iptvxs::CategoryRepository>(db, this);
    channelRepo_ = std::make_unique<iptvxs::ChannelRepository>(db, this);
    favoriteRepo_ = std::make_unique<iptvxs::FavoriteRepository>(db, this);
    progRepo_ = std::make_unique<iptvxs::ProgrammeRepository>(db, this);
    recordingRepo_ = std::make_unique<iptvxs::RecordingRepository>(db, this);
    recordingMgr_ = std::make_unique<iptvxs::RecordingManager>(this);
    httpClient_ = std::make_unique<iptvxs::HttpClient>(this);
    speedTestRunner_ = std::make_unique<iptvxs::SpeedTestRunner>(this);

    serverListVm_->setRepositories(serverRepo_.get(), categoryRepo_.get(),
                                   channelRepo_.get());
    favoriteListVm_->setRepository(favoriteRepo_.get());
    epgVm_->setRepositories(progRepo_.get(), channelRepo_.get());
    epgVm_->setHttpClient(httpClient_.get());
    categoryListVm_->setRepository(categoryRepo_.get());
    channelListVm_->setRepository(channelRepo_.get());
    recordingMgr_->setRepositories(recordingRepo_.get(), channelRepo_.get(),
                                   settingsRepo_.get(), progRepo_.get());
    recordingListVm_->setRepositories(recordingRepo_.get(), channelRepo_.get());
    recordingListVm_->setRecordingManager(recordingMgr_.get());
    connect(recordingMgr_.get(), &iptvxs::RecordingManager::recordingFailed, this,
            [](int64_t recordingId, const QString &error) {
                qWarning("Recording %lld failed: %s",
                         static_cast<long long>(recordingId), qPrintable(error));
            });
    connect(recordingMgr_.get(), &iptvxs::RecordingManager::recordingStarted, this,
            [](int64_t recordingId) {
                qInfo("Recording %lld started",
                      static_cast<long long>(recordingId));
            });
    connect(recordingMgr_.get(), &iptvxs::RecordingManager::recordingStopped, this,
            [](int64_t recordingId) {
                qInfo("Recording %lld completed",
                      static_cast<long long>(recordingId));
            });
    recordingMgr_->start();

    gdriveAuth_ = std::make_unique<iptvxs::GDriveAuth>(settingsRepo_.get(), this);
    gdriveUploader_ = std::make_unique<iptvxs::GDriveUploader>(gdriveAuth_.get(), this);

    auto clientId = settingsRepo_->getString(QStringLiteral("gdrive_client_id"));
    auto clientSecret = settingsRepo_->getString(QStringLiteral("gdrive_client_secret"));
    if (!clientId.isEmpty() && !clientSecret.isEmpty()) {
        gdriveAuth_->setCredentials(clientId, clientSecret);
    }

    connect(gdriveAuth_.get(), &iptvxs::GDriveAuth::openUrlRequested, this,
            [](const QUrl &url) { QDesktopServices::openUrl(url); });

    speedTestVm_->setRunner(speedTestRunner_.get());
    speedTestVm_->setChannelRepository(channelRepo_.get());

    gdriveVm_->setAuth(gdriveAuth_.get());
    gdriveVm_->setUploader(gdriveUploader_.get());
    gdriveVm_->setRecordingRepository(recordingRepo_.get());

    connect(serverListVm_, &ServerListViewModel::syncFinished, this,
            [this](int64_t serverId) {
                if (channelListVm_->serverId() == serverId) {
                    channelListVm_->refresh();
                }
                if (categoryListVm_->serverId() == serverId) {
                    categoryListVm_->refresh();
                }
            });

    auto bufSecs = settingsRepo_->getInt(QStringLiteral("buffer_seconds"), 0);
    if (bufSecs > 0) {
        playerVm_->setBufferSeconds(bufSecs);
    }

    auto subSize = settingsRepo_->getInt(QStringLiteral("subtitle_size"), 48);
    playerVm_->mpvPlayer()->setProperty(QStringLiteral("sub-font-size"), QVariant(subSize));
    auto subColor = settingsRepo_->getString(QStringLiteral("subtitle_color"), QStringLiteral("#FFFFFF"));
    playerVm_->mpvPlayer()->setProperty(QStringLiteral("sub-color"), QVariant(subColor));
    auto subBg = settingsRepo_->getString(QStringLiteral("subtitle_bg_color"), QStringLiteral("#80000000"));
    playerVm_->mpvPlayer()->setProperty(QStringLiteral("sub-back-color"), QVariant(subBg));

    subtitlesClient_ = std::make_unique<iptvxs::OpenSubtitlesClient>(
        httpClient_.get(), this);

    connect(subtitlesClient_.get(), &iptvxs::OpenSubtitlesClient::searchCompleted,
            this, [this](const QVector<iptvxs::SubtitleResult> &results) {
                lastSubResults_ = results;
                emit subtitlesFound(results.size());
                if (!results.isEmpty()) {
                    loadSubtitleResult(0);
                }
            });

    connect(subtitlesClient_.get(), &iptvxs::OpenSubtitlesClient::downloadCompleted,
            this, [this](const QString &filePath) {
                playerVm_->loadSubtitleFile(filePath);
                qInfo("Subtitle loaded: %s", qPrintable(filePath));
                emit subtitleLoaded(filePath);
            });

    connect(subtitlesClient_.get(), &iptvxs::OpenSubtitlesClient::errorOccurred,
            this, [](const QString &msg) {
                qWarning("Subtitle error: %s", qPrintable(msg));
            });

    databaseReady_ = true;
    emit databaseReadyChanged();

    return true;
}

void AppViewModel::setLogViewModel(LogViewModel *logVm) { logVm_ = logVm; }

QString AppViewModel::appName() const { return QStringLiteral("iptvXS"); }

QString AppViewModel::appVersion() const { return QStringLiteral("0.1.0"); }

bool AppViewModel::databaseReady() const { return databaseReady_; }

QString AppViewModel::currentView() const { return currentView_; }

void AppViewModel::setCurrentView(const QString &view) {
    if (currentView_ != view) {
        previousView_ = currentView_;
        currentView_ = view;
        emit currentViewChanged();
    }
}

QString AppViewModel::previousView() const { return previousView_; }

bool AppViewModel::videoFullscreen() const { return videoFullscreen_; }

void AppViewModel::setVideoFullscreen(bool fs) {
    if (videoFullscreen_ != fs) {
        videoFullscreen_ = fs;
        emit videoFullscreenChanged();
    }
}

iptvxs::Database *AppViewModel::database() const { return database_.get(); }

iptvxs::SettingsRepository *AppViewModel::settings() const {
    return settingsRepo_.get();
}

ServerListViewModel *AppViewModel::serverList() const {
    return serverListVm_;
}

CategoryListViewModel *AppViewModel::categoryList() const {
    return categoryListVm_;
}

ChannelListViewModel *AppViewModel::channelList() const {
    return channelListVm_;
}

PlayerViewModel *AppViewModel::player() const {
    return playerVm_;
}

FavoriteListViewModel *AppViewModel::favoriteList() const {
    return favoriteListVm_;
}

EpgViewModel *AppViewModel::epg() const {
    return epgVm_;
}

RecordingListViewModel *AppViewModel::recordingList() const {
    return recordingListVm_;
}

GDriveViewModel *AppViewModel::gdrive() const {
    return gdriveVm_;
}

SpeedTestViewModel *AppViewModel::speedTest() const {
    return speedTestVm_;
}

LogViewModel *AppViewModel::log() const {
    return logVm_;
}

int AppViewModel::autoSyncInterval() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("auto_sync_hours"), 0) : 0;
}

void AppViewModel::setAutoSyncInterval(int hours) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("auto_sync_hours"), hours);
    emit autoSyncIntervalChanged();
}

int AppViewModel::autoSyncEpgInterval() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("auto_sync_epg_hours"), 0) : 0;
}

void AppViewModel::setAutoSyncEpgInterval(int hours) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("auto_sync_epg_hours"), hours);
    emit autoSyncEpgIntervalChanged();
}

QString AppViewModel::databasePath() const {
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/iptvxs.db");
}

QString AppViewModel::databaseSize() const {
    QFileInfo fi(databasePath());
    if (!fi.exists()) return QStringLiteral("0 B");
    auto bytes = fi.size();
    if (bytes < 1024) return QStringLiteral("%1 B").arg(bytes);
    if (bytes < 1024 * 1024) return QStringLiteral("%1 KB").arg(bytes / 1024.0, 0, 'f', 1);
    if (bytes < 1024 * 1024 * 1024)
        return QStringLiteral("%1 MB").arg(bytes / (1024.0 * 1024.0), 0, 'f', 1);
    return QStringLiteral("%1 GB").arg(bytes / (1024.0 * 1024.0 * 1024.0), 0, 'f', 2);
}

QString AppViewModel::recordingDirectory() const {
    if (recordingMgr_) return recordingMgr_->recordingDirectory();
    return QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)
           + QStringLiteral("/iptvxs");
}

void AppViewModel::setRecordingDirectory(const QString &path) {
    if (!settingsRepo_ || path.isEmpty()) return;
    settingsRepo_->set(QStringLiteral("recording_directory"), path);
    emit recordingDirectoryChanged();
}

int AppViewModel::bufferSeconds() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("buffer_seconds"), 0) : 0;
}

void AppViewModel::setBufferSeconds(int seconds) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("buffer_seconds"), seconds);
    if (playerVm_) playerVm_->setBufferSeconds(seconds);
    emit bufferSecondsChanged();
}

QString AppViewModel::theme() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("theme"), QStringLiteral("midnight")) : QStringLiteral("midnight");
}

void AppViewModel::setTheme(const QString &name) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("theme"), name);
    emit themeChanged();
}

QString AppViewModel::subtitleLanguage() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("subtitle_language"), QStringLiteral("en")) : QStringLiteral("en");
}

void AppViewModel::setSubtitleLanguage(const QString &lang) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("subtitle_language"), lang);
    emit subtitleLanguageChanged();
}

bool AppViewModel::subtitlesEnabled() const {
    return settingsRepo_ ? settingsRepo_->getBool(QStringLiteral("subtitles_enabled"), false) : false;
}

void AppViewModel::setSubtitlesEnabled(bool enabled) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("subtitles_enabled"), enabled ? QStringLiteral("true") : QStringLiteral("false"));
    emit subtitlesEnabledChanged();
}

int AppViewModel::subtitleSize() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("subtitle_size"), 48) : 48;
}

void AppViewModel::setSubtitleSize(int size) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("subtitle_size"), size);
    if (playerVm_) playerVm_->mpvPlayer()->setProperty(QStringLiteral("sub-font-size"), QVariant(size));
    emit subtitleSizeChanged();
}

QString AppViewModel::subtitleColor() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("subtitle_color"), QStringLiteral("#FFFFFF")) : QStringLiteral("#FFFFFF");
}

void AppViewModel::setSubtitleColor(const QString &color) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("subtitle_color"), color);
    if (playerVm_) playerVm_->mpvPlayer()->setProperty(QStringLiteral("sub-color"), QVariant(color));
    emit subtitleColorChanged();
}

QString AppViewModel::subtitleBgColor() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("subtitle_bg_color"), QStringLiteral("#80000000")) : QStringLiteral("#80000000");
}

void AppViewModel::setSubtitleBgColor(const QString &color) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("subtitle_bg_color"), color);
    if (playerVm_) playerVm_->mpvPlayer()->setProperty(QStringLiteral("sub-back-color"), QVariant(color));
    emit subtitleBgColorChanged();
}

void AppViewModel::searchSubtitles(const QString &query) {
    if (!subtitlesClient_ || query.isEmpty()) return;
    auto lang = subtitleLanguage();
    qInfo("Searching subtitles for: %s (lang: %s)", qPrintable(query), qPrintable(lang));
    subtitlesClient_->searchByName(query, lang);
}

void AppViewModel::loadSubtitleResult(int index) {
    if (index < 0 || index >= lastSubResults_.size()) return;

    auto &result = lastSubResults_[index];
    auto dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
               + QStringLiteral("/subtitles");
    QDir().mkpath(dir);
    auto outputPath = dir + QStringLiteral("/") + result.fileName;

    subtitlesClient_->downloadSubtitle(result.downloadUrl, outputPath);
}

void AppViewModel::fetchSeriesEpisodes(int64_t serverId, const QString &seriesId,
                                        const QString &seriesName, const QString &logoUrl) {
    if (!serverRepo_ || !httpClient_) return;

    if (seriesId.isEmpty()) {
        qWarning("Series ID is empty for '%s'", qPrintable(seriesName));
        return;
    }

    auto srv = serverRepo_->findById(serverId);
    if (!srv) return;

    seriesServerUrl_ = srv->url;
    seriesUsername_ = srv->username;
    seriesPassword_ = srv->password;

    auto *client = new iptvxs::XtreamClient(
        httpClient_.get(), srv->url, srv->username, srv->password, this);

    connect(client, &iptvxs::XtreamClient::seriesInfoReady, this,
            [this, client, seriesName, logoUrl](const QString &, const QJsonObject &info) {
                client->deleteLater();

                auto episodes = info.value(QStringLiteral("episodes")).toObject();
                if (episodes.isEmpty()) {
                    qWarning("No episodes found for series '%s'", qPrintable(seriesName));
                    return;
                }

                QVariantList seasons;
                auto seasonKeys = episodes.keys();
                std::sort(seasonKeys.begin(), seasonKeys.end(),
                          [](const QString &a, const QString &b) { return a.toInt() < b.toInt(); });

                for (const auto &seasonKey : seasonKeys) {
                    QVariantMap seasonMap;
                    seasonMap[QStringLiteral("season")] = seasonKey;

                    QVariantList epList;
                    auto seasonEps = episodes.value(seasonKey).toArray();
                    for (const auto &epVal : seasonEps) {
                        auto ep = epVal.toObject();
                        QVariantMap epMap;
                        auto epId = ep.value(QStringLiteral("id")).toVariant().toString();
                        epMap[QStringLiteral("id")] = epId;
                        epMap[QStringLiteral("title")] = ep.value(QStringLiteral("title")).toString();
                        epMap[QStringLiteral("episodeNum")] = ep.value(QStringLiteral("episode_num")).toVariant().toString();
                        epMap[QStringLiteral("ext")] = ep.value(QStringLiteral("container_extension")).toString(QStringLiteral("mkv"));
                        epMap[QStringLiteral("logoUrl")] = logoUrl;
                        epList.append(epMap);
                    }
                    seasonMap[QStringLiteral("episodes")] = epList;
                    seasons.append(seasonMap);
                }

                emit seriesEpisodesReady(seriesName, seasons);
            });

    connect(client, &iptvxs::XtreamClient::errorOccurred, this,
            [client](const QString &msg) {
                client->deleteLater();
                qWarning("Series info error: %s", qPrintable(msg));
            });

    client->fetchSeriesInfo(seriesId);
}

void AppViewModel::playSeriesEpisode(const QString &episodeId, const QString &ext,
                                      const QString &title, const QString &logoUrl) {
    auto url = QStringLiteral("%1/series/%2/%3/%4.%5")
                   .arg(seriesServerUrl_, seriesUsername_, seriesPassword_, episodeId, ext);
    playerVm_->play(url, title, logoUrl, 0);
    setCurrentView(QStringLiteral("player"));
}

void AppViewModel::resetDatabase() {
    if (!database_) return;

    auto path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                + QStringLiteral("/iptvxs.db");

    database_->close();
    QFile::remove(path);

    databaseReady_ = false;
    emit databaseReadyChanged();

    if (database_->open(path)) {
        auto db = database_->connection();
        settingsRepo_ = std::make_unique<iptvxs::SettingsRepository>(db, this);
        serverRepo_ = std::make_unique<iptvxs::ServerRepository>(db, this);
        categoryRepo_ = std::make_unique<iptvxs::CategoryRepository>(db, this);
        channelRepo_ = std::make_unique<iptvxs::ChannelRepository>(db, this);
        favoriteRepo_ = std::make_unique<iptvxs::FavoriteRepository>(db, this);
        progRepo_ = std::make_unique<iptvxs::ProgrammeRepository>(db, this);
        recordingRepo_ = std::make_unique<iptvxs::RecordingRepository>(db, this);

        serverListVm_->setRepositories(serverRepo_.get(), categoryRepo_.get(),
                                       channelRepo_.get());
        favoriteListVm_->setRepository(favoriteRepo_.get());
        channelListVm_->setRepository(channelRepo_.get());
        categoryListVm_->setRepository(categoryRepo_.get());
        speedTestVm_->setChannelRepository(channelRepo_.get());

        databaseReady_ = true;
        emit databaseReadyChanged();
    }
}
