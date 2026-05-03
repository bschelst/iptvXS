// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "app_viewmodel.h"
#include "log_viewmodel.h"

#include <mpv/client.h>

#ifdef Q_OS_WIN
#include <winsparkle.h>
#endif

#include <QDateTime>
#include <QDesktopServices>
#include <QJsonArray>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUrlQuery>
#include <QTimer>

namespace {
constexpr auto kDefaultFreeServerSeededKey = "default_free_server_seeded";
constexpr auto kDefaultFreeServerBootstrapDoneKey = "default_free_server_bootstrap_done";
constexpr qint64 kValidationSampleBytes = 16 * 1024;
constexpr qint64 kValidationMaxContentBytes = 100 * 1024 * 1024;

QString localAppDataPath() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
           + QStringLiteral("/iptvXS");
}

QString databaseFilePath() {
    return localAppDataPath() + QStringLiteral("/iptvXS.db");
}

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

QString contentTypeLower(const QNetworkReply *reply) {
    return reply->header(QNetworkRequest::ContentTypeHeader).toString().toLower();
}

bool contentTypeLooksBinary(const QString &contentType) {
    if (contentType.isEmpty()) return false;
    return contentType.contains(QStringLiteral("image/"))
        || contentType.contains(QStringLiteral("video/"))
        || contentType.contains(QStringLiteral("audio/"))
        || contentType.contains(QStringLiteral("application/zip"))
        || contentType.contains(QStringLiteral("application/x-7z-compressed"))
        || contentType.contains(QStringLiteral("application/x-rar"))
        || contentType.contains(QStringLiteral("application/pdf"))
        || contentType.contains(QStringLiteral("multipart/"));
}

bool hasGatewayApiKey() {
    return QStringLiteral(IPTVXS_GATEWAY_API_KEY).isEmpty() == false;
}

QByteArray stripBomAndWhitespace(QByteArray data) {
    if (data.startsWith("\xEF\xBB\xBF")) {
        data.remove(0, 3);
    }
    while (!data.isEmpty() && static_cast<unsigned char>(data.front()) <= 0x20) {
        data.remove(0, 1);
    }
    return data;
}

bool looksLikeM3u(const QByteArray &data) {
    auto trimmed = stripBomAndWhitespace(data);
    if (trimmed.startsWith("#EXTM3U")) return true;
    return trimmed.contains("\n#EXTINF") || trimmed.contains("\r\n#EXTINF");
}

bool looksLikeXmltv(const QByteArray &data) {
    auto trimmed = stripBomAndWhitespace(data);
    return trimmed.startsWith("<?xml") || trimmed.startsWith("<tv") || trimmed.contains("<tv");
}

qint64 extractTotalSize(const QNetworkReply *reply) {
    const auto contentRange = reply->rawHeader("Content-Range");
    if (!contentRange.isEmpty()) {
        const auto slash = contentRange.lastIndexOf('/');
        if (slash >= 0 && slash + 1 < contentRange.size()) {
            bool ok = false;
            const auto total = QByteArray(contentRange.mid(slash + 1)).toLongLong(&ok);
            if (ok && total > 0) {
                return total;
            }
        }
    }
    bool ok = false;
    const auto len = reply->header(QNetworkRequest::ContentLengthHeader).toLongLong(&ok);
    return ok ? len : -1;
}

enum class ValidationKind {
    Xtream,
    M3u,
    Xmltv,
};

struct ValidationProbeState {
    QByteArray sample;
    bool finished{false};
    bool resolved{false};
};
}

AppViewModel::AppViewModel(QObject *parent)
    : QObject(parent),
      serverListVm_(new ServerListViewModel(this)),
      categoryListVm_(new CategoryListViewModel(this)),
      epgSourceListVm_(new EpgSourceListViewModel(this)),
      channelListVm_(new ChannelListViewModel(this)),
      playerVm_(new PlayerViewModel(this)),
      favoriteListVm_(new FavoriteListViewModel(this)),
      epgVm_(new EpgViewModel(this)),
      recordingListVm_(new RecordingListViewModel(this)),
      gdriveVm_(new GDriveViewModel(this)),
      speedTestVm_(new SpeedTestViewModel(this)),
      historyVm_(new HistoryViewModel(this)),
      groupListVm_(new GroupListViewModel(this)),
      chromecastMgr_(new iptvxs::ChromecastManager(this)) {}

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
    ensureDefaultServers();
    epgSourceRepo_ = std::make_unique<iptvxs::EpgSourceRepository>(db, this);
    connect(epgSourceRepo_.get(), &iptvxs::EpgSourceRepository::errorOccurred,
            this, &AppViewModel::errorOccurred);
    categoryRepo_ = std::make_unique<iptvxs::CategoryRepository>(db, this);
    channelRepo_ = std::make_unique<iptvxs::ChannelRepository>(db, this);
    favoriteRepo_ = std::make_unique<iptvxs::FavoriteRepository>(db, this);
    progRepo_ = std::make_unique<iptvxs::ProgrammeRepository>(db, this);
    recordingRepo_ = std::make_unique<iptvxs::RecordingRepository>(db, this);
    historyRepo_ = std::make_unique<iptvxs::HistoryRepository>(db, this);
    historyVm_->setRepository(historyRepo_.get());
    groupRepo_ = std::make_unique<iptvxs::ChannelGroupRepository>(db, this);
    connect(groupRepo_.get(), &iptvxs::ChannelGroupRepository::errorOccurred,
            this, &AppViewModel::errorOccurred);
    groupListVm_->setRepository(groupRepo_.get());
    groupListVm_->setChannelRepository(channelRepo_.get());
    logoCache_ = std::make_unique<iptvxs::LogoCache>(this);
    logoCache_->setCacheDir(localAppDataPath() + QStringLiteral("/logos"));
    auto maxMb = settingsRepo_->getInt(QStringLiteral("logo_cache_max_mb"), 500);
    logoCache_->pruneExpired(30, static_cast<qint64>(maxMb) * 1024 * 1024);
    recordingMgr_ = std::make_unique<iptvxs::RecordingManager>(this);
    httpClient_ = std::make_unique<iptvxs::HttpClient>(this);
    speedTestRunner_ = std::make_unique<iptvxs::SpeedTestRunner>(this);

    serverListVm_->setRepositories(serverRepo_.get(), categoryRepo_.get(),
                                   channelRepo_.get(), epgSourceRepo_.get());
    QTimer::singleShot(0, this, [this]() { bootstrapDefaultFreeServerSync(); });
    epgSourceListVm_->setRepository(epgSourceRepo_.get());
    epgSourceListVm_->setEpgViewModel(epgVm_);
    favoriteListVm_->setRepository(favoriteRepo_.get());
    epgVm_->setRepositories(progRepo_.get(), channelRepo_.get(),
                            favoriteRepo_.get());
    connect(favoriteListVm_, &FavoriteListViewModel::favoriteToggled,
            this, [this](int64_t, bool) {
                epgVm_->refresh();
                channelListVm_->invalidateFavCache();
            });
    epgVm_->setHttpClient(httpClient_.get());
    categorySettingsRepo_ = std::make_unique<iptvxs::CategorySettingsRepository>(db, this);
    seriesCacheRepo_ = std::make_unique<iptvxs::SeriesCacheRepository>(db, this);
    categoryListVm_->setRepository(categoryRepo_.get());
    categoryListVm_->setCategorySettingsRepository(categorySettingsRepo_.get());
    channelListVm_->setRepository(channelRepo_.get());
    channelListVm_->setFavoriteRepository(favoriteRepo_.get());
    recordingMgr_->setRepositories(recordingRepo_.get(), channelRepo_.get(),
                                   settingsRepo_.get(), progRepo_.get());
    recordingListVm_->setRepositories(recordingRepo_.get(), channelRepo_.get(), progRepo_.get());
    recordingListVm_->setRecordingManager(recordingMgr_.get());

    // When destination=gdrive and the user is authenticated, auto-upload new
    // recordings to the chosen Drive folder as soon as they finish.
    connect(recordingListVm_, &RecordingListViewModel::recordingCreated, this,
            [this](int64_t recordingId) {
                if (recordingDestination() != QStringLiteral("gdrive")) return;
                if (!gdriveVm_ || !gdriveVm_->authenticated()) {
                    qWarning("Recording %lld destination=gdrive but user not authenticated",
                             static_cast<long long>(recordingId));
                    return;
                }
                qInfo("Recording %lld auto-uploading to Google Drive",
                      static_cast<long long>(recordingId));
                gdriveVm_->uploadRecording(recordingId);
            });

    autoSyncTimer_ = new QTimer(this);
    autoSyncTimer_->setSingleShot(true);
    connect(autoSyncTimer_, &QTimer::timeout, this,
            [this]() { runAutoSyncChannels(); });

    autoSyncEpgTimer_ = new QTimer(this);
    autoSyncEpgTimer_->setSingleShot(true);
    connect(autoSyncEpgTimer_, &QTimer::timeout, this,
            [this]() { runAutoSyncEpg(); });

    autoSyncWatchdog_ = new QTimer(this);
    autoSyncWatchdog_->setSingleShot(true);
    connect(autoSyncWatchdog_, &QTimer::timeout, this, [this]() {
        if (!autoSyncInProgress_) return;
        qWarning("Auto channel sync watchdog: sync timed out, resetting");
        autoSyncInProgress_ = false;
        rescheduleAutoSyncChannels();
    });

    autoSyncEpgWatchdog_ = new QTimer(this);
    autoSyncEpgWatchdog_->setSingleShot(true);
    connect(autoSyncEpgWatchdog_, &QTimer::timeout, this, [this]() {
        if (!autoSyncEpgInProgress_) return;
        qWarning("Auto EPG sync watchdog: sync timed out, resetting");
        autoSyncEpgInProgress_ = false;
        rescheduleAutoSyncEpg();
    });

    historyFlushTimer_ = new QTimer(this);
    historyFlushTimer_->setInterval(5000);
    historyFlushTimer_->setSingleShot(false);
    connect(historyFlushTimer_, &QTimer::timeout, this,
            [this]() { persistCurrentHistoryPosition(); });

    connect(serverListVm_, &ServerListViewModel::syncFinished, this,
            [this](int64_t) {
                if (defaultFreeServerBootstrapEpgPending_) {
                    const auto builtinIdx = serverListVm_ ? serverListVm_->builtinFreeServerId() : 0;
                    if (builtinIdx > 0 && serverListVm_) {
                        int idx = -1;
                        for (int i = 0; i < serverListVm_->count(); ++i) {
                            if (serverListVm_->serverIdAt(i) == builtinIdx) {
                                idx = i;
                                break;
                            }
                        }
                        if (idx >= 0) {
                            const auto epgUrl = serverListVm_->epgUrlAt(idx);
                            if (!epgUrl.isEmpty()) {
                                defaultFreeServerBootstrapPending_ = false;
                                qInfo("Bootstrap syncing EPG for built-in iptvXS Free server");
                                epgVm_->syncEpg(epgUrl);
                                return;
                            }
                        }
                    }
                    defaultFreeServerBootstrapPending_ = false;
                    defaultFreeServerBootstrapEpgPending_ = false;
                    if (settingsRepo_) {
                        settingsRepo_->set(QString::fromLatin1(kDefaultFreeServerBootstrapDoneKey), true);
                    }
                }
                if (!autoSyncInProgress_) return;
                advanceAutoSyncToNextEnabled();
                if (autoSyncServerCursor_ < serverListVm_->count()) {
                    qInfo("Auto channel sync: next server (%d/%d)",
                          autoSyncServerCursor_ + 1, serverListVm_->count());
                    autoSyncWatchdog_->start(120 * 1000);
                    serverListVm_->syncServer(autoSyncServerCursor_);
                    return;
                }
                autoSyncWatchdog_->stop();
                autoSyncInProgress_ = false;
                if (settingsRepo_) {
                    settingsRepo_->set(
                        QStringLiteral("last_channel_sync_ts"),
                        static_cast<int>(QDateTime::currentSecsSinceEpoch()));
                }
                qInfo("Auto channel sync finished");
                rescheduleAutoSyncChannels();
            });

    connect(epgVm_, &EpgViewModel::syncingChanged, this, [this]() {
        if (defaultFreeServerBootstrapEpgPending_ && !epgVm_->syncing()) {
            defaultFreeServerBootstrapEpgPending_ = false;
            if (settingsRepo_) {
                settingsRepo_->set(QString::fromLatin1(kDefaultFreeServerBootstrapDoneKey), true);
            }
            qInfo("Bootstrap sync for built-in iptvXS Free server complete");
        }
        if (!autoSyncEpgInProgress_) return;
        if (epgVm_->syncing()) return;
        // Sync just finished — advance to next server with an EPG URL, or stop.
        const int n = serverListVm_ ? serverListVm_->count() : 0;
        int next = -1;
        for (int i = autoSyncEpgCursor_ + 1; i < n; ++i) {
            if (!serverListVm_->epgUrlAt(i).isEmpty()) { next = i; break; }
        }
        if (next >= 0) {
            autoSyncEpgCursor_ = next;
            qInfo("Auto EPG sync: next server (index %d)", next);
            autoSyncEpgWatchdog_->start(300 * 1000);
            epgVm_->syncEpg(serverListVm_->epgUrlAt(next));
            return;
        }
        autoSyncEpgWatchdog_->stop();
        autoSyncEpgInProgress_ = false;
        if (settingsRepo_) {
            settingsRepo_->set(
                QStringLiteral("last_epg_sync_ts"),
                static_cast<int>(QDateTime::currentSecsSinceEpoch()));
        }
        qInfo("Auto EPG sync finished");
        rescheduleAutoSyncEpg();
    });
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
            [this](int64_t recordingId) {
                qInfo("Recording %lld completed",
                      static_cast<long long>(recordingId));
                if (recordingDestination() == QStringLiteral("gdrive") &&
                    gdriveVm_ && gdriveVm_->authenticated()) {
                    qInfo("Recording %lld auto-uploading to Google Drive (scheduled)",
                          static_cast<long long>(recordingId));
                    gdriveVm_->uploadRecording(recordingId);
                }
            });
    recordingMgr_->start();

    gdriveAuth_ = std::make_unique<iptvxs::GDriveAuth>(settingsRepo_.get(), this);
    gdriveUploader_ = std::make_unique<iptvxs::GDriveUploader>(gdriveAuth_.get(), this);

    // Client ID is now bundled in the binary (PKCE flow). Clean up legacy
    // per-user credential rows from the settings DB.
    settingsRepo_->remove(QStringLiteral("gdrive_client_id"));
    settingsRepo_->remove(QStringLiteral("gdrive_client_secret"));

    // Migrate old default folder name to branded version.
    auto oldFolder = settingsRepo_->getString(QStringLiteral("gdrive_folder_name"));
    if (oldFolder == QStringLiteral("iptvxs-recordings")) {
        settingsRepo_->set(QStringLiteral("gdrive_folder_name"),
                           QStringLiteral("iptvXS-recordings"));
        settingsRepo_->remove(QStringLiteral("gdrive_folder_id"));
    }

    connect(gdriveAuth_.get(), &iptvxs::GDriveAuth::openUrlRequested, this,
            [this](const QUrl &url) {
                const bool gamescope = qEnvironmentVariableIsSet("GAMESCOPE_WAYLAND_DISPLAY");
                if (gamescope) {
                    emit showAuthHint(url.toString());
                } else {
                    QDesktopServices::openUrl(url);
                }
            });

    speedTestVm_->setRunner(speedTestRunner_.get());
    speedTestVm_->setChannelRepository(channelRepo_.get());
    speedTestVm_->setFavoriteRepository(favoriteRepo_.get());
    speedTestVm_->setHistoryRepository(historyRepo_.get());

    gdriveVm_->setAuth(gdriveAuth_.get());
    gdriveVm_->setUploader(gdriveUploader_.get());
    gdriveVm_->setRecordingRepository(recordingRepo_.get());
    gdriveVm_->setSettingsRepository(settingsRepo_.get());
    gdriveVm_->setDeleteLocalAfterUpload(!keepLocalCopy() && recordingDestination() == QStringLiteral("gdrive"));
    gdriveVm_->resumePendingUploads();

    connect(serverListVm_, &ServerListViewModel::syncFinished, this,
            [this](int64_t serverId) {
                if (channelListVm_->serverId() == serverId) {
                    channelListVm_->refresh();
                }
                if (categoryListVm_->serverId() == serverId) {
                    categoryListVm_->refresh();
                }
                // Pre-populate series episode cache in background
                prefetchSeriesCache(serverId);
            });

    connect(playerVm_, &PlayerViewModel::streamRecordingStopped, this,
            [this](const QString &filePath, qint64 startTime) {
                Q_UNUSED(startTime)
                if (!recordingRepo_) return;
                auto recs = recordingRepo_->findByStatus(QStringLiteral("recording"));
                for (const auto &rec : recs) {
                    if (rec.filePath == filePath) {
                        auto now = QDateTime::currentSecsSinceEpoch();
                        recordingListVm_->completeStreamRecording(rec.id, now, filePath);
                        qInfo("Stream recording %lld finalized via player stop",
                              static_cast<long long>(rec.id));
                        return;
                    }
                }
            });

    connect(playerVm_, &PlayerViewModel::stateChanged, this, [this]() {
        if (playerVm_->playing() && historyRepo_) {
            if (resumeHistoryPending_) {
                resumeHistoryPending_ = false;
                if (historyVm_) historyVm_->refresh();
                if (!playerVm_->isLive()) {
                    startHistoryFlushTimer();
                } else {
                    stopHistoryFlushTimer();
                }
                return;
            }

            persistCurrentHistoryPosition();

            auto url = playerVm_->currentUrl();
            auto name = playerVm_->channelName();
            if (name.isEmpty()) return;

            QString type;
            if (url.contains(QStringLiteral("/live/"))) type = QStringLiteral("live");
            else if (url.contains(QStringLiteral("/series/"))) type = QStringLiteral("series");
            else if (url.contains(QStringLiteral("/movie/"))) type = QStringLiteral("vod");
            else if (playerVm_->isLive()) type = QStringLiteral("live");
            else type = QStringLiteral("vod");

            historyRepo_->addEntry(name, playerVm_->channelLogo(), type, url, 0, playerVm_->channelId());

            // Track the new entry ID (latest in DB)
            auto recent = historyRepo_->findRecent(1, 0);
            lastHistoryEntryId_ = recent.isEmpty() ? 0 : recent.first().id;
            if (historyVm_) historyVm_->refresh();
            if (!playerVm_->isLive()) {
                startHistoryFlushTimer();
            } else {
                stopHistoryFlushTimer();
            }
        } else if (playerVm_->paused() && historyRepo_ && lastHistoryEntryId_ > 0 && !playerVm_->isLive()) {
            startHistoryFlushTimer();
        } else if (playerVm_->stopped() && historyRepo_ && lastHistoryEntryId_ > 0) {
            persistCurrentHistoryPosition();
            lastHistoryEntryId_ = 0;
            stopHistoryFlushTimer();
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

    auto vePreset = videoEnhancement();
    if (vePreset != QStringLiteral("off")) {
        setVideoEnhancement(vePreset);
    }

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

    auto hwdec = hwdecMode();
    if (!hwdec.isEmpty()) {
        playerVm_->mpvPlayer()->setProperty(QStringLiteral("hwdec"), QVariant(hwdec));
    }
    if (deinterlace()) {
        playerVm_->mpvPlayer()->setProperty(QStringLiteral("deinterlace"), QVariant(QStringLiteral("yes")));
    }
    applyToneMappingToPlayer();

    // Clean up stale recordings left in "recording" state from a previous crash/shutdown
    auto staleRecordings = recordingRepo_->findByStatus(QStringLiteral("recording"));
    for (const auto &rec : staleRecordings) {
        qWarning("Cleaning up stale recording %lld (was still marked 'recording' from previous session)",
                 static_cast<long long>(rec.id));
        if (!rec.filePath.isEmpty() && QFileInfo::exists(rec.filePath)) {
            recordingRepo_->updateStatus(rec.id, QStringLiteral("completed"));
            recordingRepo_->updateEndTime(rec.id, rec.startTime);
            auto fi = QFileInfo(rec.filePath);
            recordingRepo_->updateFileSize(rec.id, fi.size());
        } else {
            recordingRepo_->updateStatus(rec.id, QStringLiteral("failed"));
        }
    }

    databaseReady_ = true;
    emit databaseReadyChanged();

    rescheduleAutoSyncChannels();
    rescheduleAutoSyncEpg();
    checkForUpdates();

    // Run daily maintenance if >24h since last run
    auto lastMaint = static_cast<qint64>(settingsRepo_->getInt(QStringLiteral("last_maintenance"), 0));
    auto now = QDateTime::currentSecsSinceEpoch();
    if (now - lastMaint > 86400) {
        QTimer::singleShot(5000, this, [this]() { runMaintenance(); });
    }

    return true;
}

void AppViewModel::setLogViewModel(LogViewModel *logVm) { logVm_ = logVm; }

QString AppViewModel::appName() const { return QStringLiteral("iptvXS"); }

QString AppViewModel::appVersion() const { return QStringLiteral(IPTVXS_VERSION); }

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

EpgSourceListViewModel *AppViewModel::epgSourceList() const {
    return epgSourceListVm_;
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

HistoryViewModel *AppViewModel::history() const { return historyVm_; }

LogViewModel *AppViewModel::log() const {
    return logVm_;
}

GroupListViewModel *AppViewModel::groupList() const {
    return groupListVm_;
}

iptvxs::LogoCache *AppViewModel::logoCache() const {
    return logoCache_.get();
}

iptvxs::ChromecastManager *AppViewModel::chromecast() const {
    return chromecastMgr_;
}

bool AppViewModel::chromecastEnabled() const {
    return settingsRepo_ ? settingsRepo_->getBool(QStringLiteral("chromecast_enabled"), true) : true;
}

void AppViewModel::setChromecastEnabled(bool enabled) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("chromecast_enabled"), enabled);
    emit chromecastEnabledChanged();
}

int AppViewModel::logoCacheMaxMb() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("logo_cache_max_mb"), 500) : 500;
}

void AppViewModel::setLogoCacheMaxMb(int mb) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("logo_cache_max_mb"), qBound(50, mb, 2000));
    emit logoCacheMaxMbChanged();
}

int AppViewModel::autoSyncInterval() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("auto_sync_hours"), 24) : 24;
}

void AppViewModel::setAutoSyncInterval(int hours) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("auto_sync_hours"), hours);
    emit autoSyncIntervalChanged();
    rescheduleAutoSyncChannels();
}

int AppViewModel::autoSyncEpgInterval() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("auto_sync_epg_hours"), 24) : 24;
}

void AppViewModel::setAutoSyncEpgInterval(int hours) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("auto_sync_epg_hours"), hours);
    emit autoSyncEpgIntervalChanged();
    rescheduleAutoSyncEpg();
}

void AppViewModel::rescheduleAutoSyncChannels() {
    if (!autoSyncTimer_ || !settingsRepo_) return;
    const int hours = autoSyncInterval();
    autoSyncTimer_->stop();
    if (hours <= 0) {
        qInfo("Auto channel sync disabled");
        return;
    }
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    const qint64 last =
        settingsRepo_->getInt(QStringLiteral("last_channel_sync_ts"), 0);
    const qint64 dueAt = last + static_cast<qint64>(hours) * 3600;
    qint64 delaySec = dueAt - now;
    if (delaySec < 60) delaySec = 60;  // run shortly after startup if overdue
    autoSyncTimer_->setInterval(static_cast<int>(
        qMin<qint64>(delaySec, static_cast<qint64>(hours) * 3600) * 1000));
    autoSyncTimer_->start();
    qInfo("Auto channel sync scheduled in %lld seconds (interval %d hours)",
          static_cast<long long>(delaySec), hours);
}

void AppViewModel::rescheduleAutoSyncEpg() {
    if (!autoSyncEpgTimer_ || !settingsRepo_) return;
    const int hours = autoSyncEpgInterval();
    autoSyncEpgTimer_->stop();
    if (hours <= 0) {
        qInfo("Auto EPG sync disabled");
        return;
    }
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    const qint64 last =
        settingsRepo_->getInt(QStringLiteral("last_epg_sync_ts"), 0);
    const qint64 dueAt = last + static_cast<qint64>(hours) * 3600;
    qint64 delaySec = dueAt - now;
    if (delaySec < 120) delaySec = 120;
    autoSyncEpgTimer_->setInterval(static_cast<int>(
        qMin<qint64>(delaySec, static_cast<qint64>(hours) * 3600) * 1000));
    autoSyncEpgTimer_->start();
    qInfo("Auto EPG sync scheduled in %lld seconds (interval %d hours)",
          static_cast<long long>(delaySec), hours);
}

void AppViewModel::advanceAutoSyncToNextEnabled() {
    ++autoSyncServerCursor_;
    while (autoSyncServerCursor_ < serverListVm_->count()) {
        auto sid = serverListVm_->serverIdAt(autoSyncServerCursor_);
        auto idx = serverListVm_->index(autoSyncServerCursor_);
        auto enabled = serverListVm_->data(idx, ServerListViewModel::EnabledRole).toBool();
        if (enabled) return;
        ++autoSyncServerCursor_;
    }
}

void AppViewModel::runAutoSyncChannels() {
    if (!serverListVm_ || !settingsRepo_) return;
    if (autoSyncInProgress_ || serverListVm_->syncing()) {
        qInfo("Auto channel sync skipped: another sync is in progress");
        return;
    }
    const int n = serverListVm_->count();
    if (n <= 0) {
        qInfo("Auto channel sync: no servers configured");
        settingsRepo_->set(QStringLiteral("last_channel_sync_ts"),
                           static_cast<int>(QDateTime::currentSecsSinceEpoch()));
        rescheduleAutoSyncChannels();
        return;
    }
    autoSyncInProgress_ = true;
    autoSyncServerCursor_ = -1;
    advanceAutoSyncToNextEnabled();
    if (autoSyncServerCursor_ < 0 || autoSyncServerCursor_ >= n) {
        autoSyncInProgress_ = false;
        qInfo("Auto channel sync: no enabled servers");
        settingsRepo_->set(QStringLiteral("last_channel_sync_ts"),
                           static_cast<int>(QDateTime::currentSecsSinceEpoch()));
        rescheduleAutoSyncChannels();
        return;
    }
    qInfo("Auto channel sync starting for %d server(s)", n);
    autoSyncWatchdog_->start(120 * 1000);
    serverListVm_->syncServer(autoSyncServerCursor_);
}

void AppViewModel::runAutoSyncEpg() {
    if (!serverListVm_ || !epgVm_ || !settingsRepo_) return;
    if (autoSyncEpgInProgress_ || epgVm_->syncing()) {
        qInfo("Auto EPG sync skipped: another sync is in progress");
        return;
    }
    const int n = serverListVm_->count();
    if (n <= 0) {
        qInfo("Auto EPG sync: no servers configured");
        settingsRepo_->set(QStringLiteral("last_epg_sync_ts"),
                           static_cast<int>(QDateTime::currentSecsSinceEpoch()));
        rescheduleAutoSyncEpg();
        return;
    }
    autoSyncEpgInProgress_ = true;
    autoSyncEpgCursor_ = -1;
    // Advance to the first server that has an EPG URL.
    for (int i = 0; i < n; ++i) {
        if (!serverListVm_->epgUrlAt(i).isEmpty()) {
            autoSyncEpgCursor_ = i;
            break;
        }
    }
    if (autoSyncEpgCursor_ < 0) {
        qInfo("Auto EPG sync: no server has an EPG URL configured");
        autoSyncEpgInProgress_ = false;
        settingsRepo_->set(QStringLiteral("last_epg_sync_ts"),
                           static_cast<int>(QDateTime::currentSecsSinceEpoch()));
        rescheduleAutoSyncEpg();
        return;
    }
    qInfo("Auto EPG sync starting (server index %d)", autoSyncEpgCursor_);
    autoSyncEpgWatchdog_->start(300 * 1000);
    epgVm_->syncEpg(serverListVm_->epgUrlAt(autoSyncEpgCursor_));
}

QString AppViewModel::databasePath() const {
    return databaseFilePath();
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
           + QStringLiteral("/iptvXS");
}

void AppViewModel::setRecordingDirectory(const QString &path) {
    if (!settingsRepo_ || path.isEmpty()) return;
    settingsRepo_->set(QStringLiteral("recording_directory"), path);
    emit recordingDirectoryChanged();
}

QString AppViewModel::recordingDestination() const {
    if (!settingsRepo_) return QStringLiteral("local");
    auto v = settingsRepo_->getString(QStringLiteral("recording_destination"),
                                      QStringLiteral("local"));
    return (v == QStringLiteral("gdrive")) ? v : QStringLiteral("local");
}

void AppViewModel::setRecordingDestination(const QString &dest) {
    if (!settingsRepo_) return;
    auto normalized = (dest == QStringLiteral("gdrive")) ? dest : QStringLiteral("local");
    if (recordingDestination() == normalized) return;
    settingsRepo_->set(QStringLiteral("recording_destination"), normalized);
    if (gdriveVm_) {
        gdriveVm_->setDeleteLocalAfterUpload(!keepLocalCopy() && normalized == QStringLiteral("gdrive"));
    }
    emit recordingDestinationChanged();
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

QString AppViewModel::subtitleLanguageSecondary() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("subtitle_language_secondary"), QString()) : QString();
}

void AppViewModel::setSubtitleLanguageSecondary(const QString &lang) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("subtitle_language_secondary"), lang);
    emit subtitleLanguageSecondaryChanged();
}

bool AppViewModel::subtitlesEnabled() const {
    return settingsRepo_ ? settingsRepo_->getBool(QStringLiteral("subtitles_enabled"), true) : true;
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

qint64 AppViewModel::maxRecordingSizeGb() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("max_recording_size_gb"), 2) : 2;
}

void AppViewModel::setMaxRecordingSizeGb(qint64 gb) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("max_recording_size_gb"), static_cast<int>(gb));
    emit maxRecordingSizeGbChanged();
}

int AppViewModel::epgRecordingLeadTime() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("epg_recording_lead_time"), 0) : 0;
}

void AppViewModel::setEpgRecordingLeadTime(int minutes) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("epg_recording_lead_time"), qBound(0, minutes, 5));
    emit epgRecordingLeadTimeChanged();
}

int AppViewModel::epgRecordingOverrun() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("epg_recording_overrun"), 0) : 0;
}

void AppViewModel::setEpgRecordingOverrun(int minutes) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("epg_recording_overrun"), qBound(0, minutes, 5));
    emit epgRecordingOverrunChanged();
}

int AppViewModel::gridColumns() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("grid_columns"), 2) : 2;
}

void AppViewModel::setGridColumns(int cols) {
    if (!settingsRepo_) return;
    cols = qBound(1, cols, 3);
    settingsRepo_->set(QStringLiteral("grid_columns"), cols);
    emit gridColumnsChanged();
}

bool AppViewModel::closeToTray() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("close_to_tray"), 0) != 0 : false;
}

void AppViewModel::setCloseToTray(bool enabled) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("close_to_tray"), enabled ? 1 : 0);
    emit closeToTrayChanged();
}

QString AppViewModel::videoEnhancement() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("video_enhancement"), QStringLiteral("off")) : QStringLiteral("off");
}

void AppViewModel::setVideoEnhancement(const QString &preset) {
    if (!settingsRepo_ || !playerVm_) return;
    settingsRepo_->set(QStringLiteral("video_enhancement"), preset);

    auto *mpv = playerVm_->mpvPlayer();

    if (preset == QStringLiteral("off")) {
        mpv->setProperty(QStringLiteral("deband"), QVariant(false));
        mpv->setProperty(QStringLiteral("scale"), QVariant(QStringLiteral("bilinear")));
        mpv->setProperty(QStringLiteral("cscale"), QVariant(QStringLiteral("bilinear")));
        mpv->setProperty(QStringLiteral("sigmoid-upscaling"), QVariant(false));
        mpv->command(QStringList{QStringLiteral("vf"), QStringLiteral("set"), QString()});
    } else if (preset == QStringLiteral("light")) {
        mpv->setProperty(QStringLiteral("deband"), QVariant(true));
        mpv->setProperty(QStringLiteral("deband-iterations"), QVariant(2));
        mpv->setProperty(QStringLiteral("deband-threshold"), QVariant(48));
        mpv->setProperty(QStringLiteral("deband-range"), QVariant(16));
        mpv->setProperty(QStringLiteral("scale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("cscale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("sigmoid-upscaling"), QVariant(true));
        mpv->command(QStringList{QStringLiteral("vf"), QStringLiteral("set"), QString()});
    } else if (preset == QStringLiteral("medium")) {
        mpv->setProperty(QStringLiteral("deband"), QVariant(true));
        mpv->setProperty(QStringLiteral("deband-iterations"), QVariant(2));
        mpv->setProperty(QStringLiteral("deband-threshold"), QVariant(48));
        mpv->setProperty(QStringLiteral("deband-range"), QVariant(16));
        mpv->setProperty(QStringLiteral("scale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("cscale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("sigmoid-upscaling"), QVariant(true));
        mpv->command(QStringList{QStringLiteral("vf"), QStringLiteral("set"),
                                  QStringLiteral("lavfi=\"hqdn3d=luma_spatial=1.2:chroma_spatial=1.2:luma_tmp=4:chroma_tmp=4\"")});
    } else if (preset == QStringLiteral("strong")) {
        mpv->setProperty(QStringLiteral("deband"), QVariant(true));
        mpv->setProperty(QStringLiteral("deband-iterations"), QVariant(2));
        mpv->setProperty(QStringLiteral("deband-threshold"), QVariant(48));
        mpv->setProperty(QStringLiteral("deband-range"), QVariant(16));
        mpv->setProperty(QStringLiteral("scale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("cscale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("sigmoid-upscaling"), QVariant(true));
        mpv->command(QStringList{QStringLiteral("vf"), QStringLiteral("set"),
                                  QStringLiteral("lavfi=\"hqdn3d=luma_spatial=1.8:chroma_spatial=1.8:luma_tmp=6:chroma_tmp=6\"")});
    }

    emit videoEnhancementChanged();
}

QString AppViewModel::hwdecMode() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("hwdec_mode"), QStringLiteral("auto-safe")) : QStringLiteral("auto-safe");
}

void AppViewModel::setHwdecMode(const QString &mode) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("hwdec_mode"), mode);
    if (playerVm_) playerVm_->mpvPlayer()->setProperty(QStringLiteral("hwdec"), QVariant(mode));
    emit hwdecModeChanged();
}

bool AppViewModel::deinterlace() const {
    return settingsRepo_ ? settingsRepo_->getBool(QStringLiteral("deinterlace"), false) : false;
}

void AppViewModel::setDeinterlace(bool enabled) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("deinterlace"), enabled ? QStringLiteral("true") : QStringLiteral("false"));
    if (playerVm_) playerVm_->mpvPlayer()->setProperty(QStringLiteral("deinterlace"), QVariant(enabled ? QStringLiteral("yes") : QStringLiteral("no")));
    emit deinterlaceChanged();
}

bool AppViewModel::toneMapping() const {
    return settingsRepo_ ? settingsRepo_->getBool(QStringLiteral("tone_mapping"), false) : false;
}

void AppViewModel::setToneMapping(bool enabled) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("tone_mapping"), enabled ? QStringLiteral("true") : QStringLiteral("false"));
    applyToneMappingToPlayer();
    emit toneMappingChanged();
}

QString AppViewModel::toneMappingAlgorithm() const {
    return settingsRepo_ ? settingsRepo_->getString(QStringLiteral("tone_mapping_algorithm"), QStringLiteral("auto")) : QStringLiteral("auto");
}

void AppViewModel::setToneMappingAlgorithm(const QString &algorithm) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("tone_mapping_algorithm"), algorithm);
    applyToneMappingToPlayer();
    emit toneMappingAlgorithmChanged();
}

bool AppViewModel::keepLocalCopy() const {
    return settingsRepo_ ? settingsRepo_->getBool(QStringLiteral("keep_local_copy"), false) : false;
}

void AppViewModel::setKeepLocalCopy(bool keep) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("keep_local_copy"), keep ? QStringLiteral("true") : QStringLiteral("false"));
    if (gdriveVm_) {
        gdriveVm_->setDeleteLocalAfterUpload(!keep && recordingDestination() == QStringLiteral("gdrive"));
    }
    emit keepLocalCopyChanged();
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
    if (result.downloadUrl.isEmpty()) {
        emit errorOccurred(QStringLiteral("Subtitle result has no download link"));
        return;
    }
    auto dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
               + QStringLiteral("/subtitles");
    QDir().mkpath(dir);
    auto safeName = QFileInfo(result.fileName).fileName();
    if (safeName.isEmpty()) safeName = QStringLiteral("subtitle.srt");
    auto outputPath = dir + QStringLiteral("/") + safeName;
    if (!QFileInfo(outputPath).absoluteFilePath().startsWith(QFileInfo(dir).absoluteFilePath())) {
        qWarning() << "Subtitle path escaped safe directory, blocked";
        return;
    }

    subtitlesClient_->downloadSubtitle(result.downloadUrl, outputPath);
}

void AppViewModel::fetchSeriesEpisodes(int64_t serverId, const QString &seriesId,
                                        const QString &seriesName, const QString &logoUrl) {
    if (!serverRepo_ || !httpClient_) return;

    if (seriesId.isEmpty()) {
        qWarning("Series ID is empty for '%s'", qPrintable(seriesName));
        return;
    }

    // Store active series dialog state for restoration after returning from player
    setActiveSeriesDialog(seriesName, serverId, seriesId, logoUrl);

    auto srv = serverRepo_->findById(serverId);
    if (!srv) return;

    seriesServerUrl_ = srv->url;
    seriesUsername_ = srv->username;
    seriesPassword_ = srv->password;

    // Try cache first
    if (seriesCacheRepo_) {
        auto cached = seriesCacheRepo_->find(serverId, seriesId);
        if (cached) {
            auto seasons = parseSeriesEpisodes(*cached, seriesName, logoUrl);
            if (!seasons.isEmpty()) {
                pendingSeriesName_ = seriesName;
                pendingSeriesEpisodes_ = seasons;
                emit seriesEpisodesReady(seriesName, seasons);
                return;
            }
        }
    }

    // Cache miss — fetch from API and cache the result
    auto *client = new iptvxs::XtreamClient(
        httpClient_.get(), srv->url, srv->username, srv->password, this);

    connect(client, &iptvxs::XtreamClient::seriesInfoReady, this,
            [this, client, serverId, seriesId, seriesName, logoUrl](const QString &, const QJsonObject &info) {
                client->deleteLater();

                // Cache the raw response
                if (seriesCacheRepo_) {
                    seriesCacheRepo_->store(serverId, seriesId, seriesName, logoUrl, info);
                }

                auto seasons = parseSeriesEpisodes(info, seriesName, logoUrl);
                if (seasons.isEmpty()) {
                    qWarning("No episodes found for series '%s'", qPrintable(seriesName));
                    return;
                }

                pendingSeriesName_ = seriesName;
                pendingSeriesEpisodes_ = seasons;
                emit seriesEpisodesReady(seriesName, seasons);
            });

    connect(client, &iptvxs::XtreamClient::errorOccurred, this,
            [client](const QString &msg) {
                client->deleteLater();
                qWarning("Series info error: %s", qPrintable(msg));
            });

    client->fetchSeriesInfo(seriesId);
}

QVariantList AppViewModel::parseSeriesEpisodes(const QJsonObject &info,
                                                const QString &seriesName,
                                                const QString &logoUrl) {
    auto episodes = info.value(QStringLiteral("episodes")).toObject();
    if (episodes.isEmpty()) {
        return {};
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

    Q_UNUSED(seriesName)
    return seasons;
}

void AppViewModel::ensureDefaultServers() {
    if (!settingsRepo_ || !serverRepo_) {
        return;
    }

    const QString seedUrl = QStringLiteral("https://iptvxs.schelstraete.org/api/v1/playlist.m3u");
    const QString seedKey = QString::fromLatin1(kDefaultFreeServerSeededKey);
    if (settingsRepo_->contains(seedKey)) {
        return;
    }

    const auto servers = serverRepo_->findAll();
    for (const auto &srv : servers) {
        if (srv.isBuiltinFree) {
            settingsRepo_->set(seedKey, true);
            return;
        }
    }

    if (!servers.isEmpty()) {
        settingsRepo_->set(seedKey, true);
        return;
    }

    iptvxs::Server server;
    server.name = QStringLiteral("iptvXS Free");
    server.type = QStringLiteral("m3u");
    server.url = seedUrl;
    server.enabled = true;
    server.isBuiltinFree = true;
    server.isPrimary = (servers.isEmpty());

    const auto id = serverRepo_->create(server);
    if (id > 0) {
        if (server.isPrimary) {
            serverRepo_->setPrimary(id);
        }
        settingsRepo_->set(seedKey, true);
        defaultFreeServerBootstrapPending_ = true;
        qInfo("Seeded default server: iptvXS Free");
    }
}

void AppViewModel::applyToneMappingToPlayer() {
    if (!playerVm_ || !playerVm_->mpvPlayer()->handle()) return;
    auto algo = toneMapping() ? toneMappingAlgorithm() : QStringLiteral("auto");
    auto hdrPeak = toneMapping() ? QStringLiteral("yes") : QStringLiteral("auto");
    const QStringList toneCmd{QStringLiteral("set"), QStringLiteral("tone-mapping"), algo};
    const QStringList hdrCmd{QStringLiteral("set"), QStringLiteral("hdr-compute-peak"), hdrPeak};
    playerVm_->mpvPlayer()->command(toneCmd);
    playerVm_->mpvPlayer()->command(hdrCmd);
    qInfo("Tone mapping %s: algorithm=%s hdr-compute-peak=%s",
          toneMapping() ? "enabled" : "disabled", qPrintable(algo),
          qPrintable(hdrPeak));
}

void AppViewModel::bootstrapDefaultFreeServerSync() {
    if (!serverListVm_ || !settingsRepo_ || !defaultFreeServerBootstrapPending_) {
        return;
    }
    if (settingsRepo_->contains(QString::fromLatin1(kDefaultFreeServerBootstrapDoneKey))) {
        defaultFreeServerBootstrapPending_ = false;
        return;
    }

    const auto builtinId = serverListVm_->builtinFreeServerId();
    if (builtinId <= 0 || serverListVm_->syncing()) {
        return;
    }

    int idx = -1;
    for (int i = 0; i < serverListVm_->count(); ++i) {
        if (serverListVm_->serverIdAt(i) == builtinId) {
            idx = i;
            break;
        }
    }
    if (idx < 0) {
        return;
    }

    if (!hasGatewayApiKey()) {
        defaultFreeServerBootstrapPending_ = false;
        qInfo("Skipping built-in iptvXS Free bootstrap: gateway API key unavailable in this build");
        return;
    }

    defaultFreeServerBootstrapEpgPending_ = true;
    qInfo("Bootstrap syncing built-in iptvXS Free server");
    serverListVm_->syncServer(idx);
}

void AppViewModel::validateServerInput(const QString &type, const QString &url,
                                       const QString &username, const QString &password) {
    if (!httpClient_) {
        emit urlValidationFinished(QStringLiteral("server"), false,
                                   QStringLiteral("HTTP client unavailable"));
        return;
    }

    const auto normalizedUrl = normalizeHttpUrl(url);
    if (normalizedUrl.isEmpty()) {
        emit urlValidationFinished(QStringLiteral("server"), false,
                                   QStringLiteral("Enter a valid URL"));
        return;
    }

    if (type == QStringLiteral("xtream")) {
        auto *client = new iptvxs::XtreamClient(httpClient_.get(), normalizedUrl,
                                                username, password, this);
        connect(client, &iptvxs::XtreamClient::serverInfoReady, this,
                [this, client]() {
                    client->deleteLater();
                    emit urlValidationFinished(QStringLiteral("server"), true, {});
                });
        connect(client, &iptvxs::XtreamClient::errorOccurred, this,
                [this, client](const QString &msg) {
                    client->deleteLater();
                    emit urlValidationFinished(QStringLiteral("server"), false, msg);
                });
        client->fetchServerInfo();
        return;
    }

    auto validateTextPayload = [this, normalizedUrl](ValidationKind kind, const QString &context) {
        QNetworkRequest request{QUrl(normalizedUrl)};
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                             QNetworkRequest::NoLessSafeRedirectPolicy);
        request.setRawHeader("Range", "bytes=0-16383");

        auto *reply = httpClient_->get(request);
        auto state = std::make_shared<ValidationProbeState>();

        auto finishIfValid = [this, reply, state, context, kind]() {
            if (state->resolved) return;

            const auto totalSize = extractTotalSize(reply);
            if (totalSize > kValidationMaxContentBytes) {
                state->resolved = true;
                reply->abort();
                emit urlValidationFinished(context, false,
                                           QStringLiteral("URL is too large (%1 MB)")
                                               .arg(QString::number(totalSize / (1024.0 * 1024.0), 'f', 1)));
                return;
            }

            const auto contentType = contentTypeLower(reply);
            const auto sample = stripBomAndWhitespace(state->sample);
            bool valid = false;
            if (kind == ValidationKind::M3u) {
                valid = looksLikeM3u(sample);
            } else {
                valid = looksLikeXmltv(sample);
            }

            if (!valid && !contentType.isEmpty() && contentTypeLooksBinary(contentType)) {
                state->resolved = true;
                reply->abort();
                emit urlValidationFinished(context, false,
                                           QStringLiteral("URL returned binary content (%1)")
                                               .arg(contentType));
                return;
            }

            if (valid) {
                state->resolved = true;
                reply->abort();
                emit urlValidationFinished(context, true, {});
            }
        };

        connect(reply, &QNetworkReply::metaDataChanged, this,
                [this, reply, state, context, kind, finishIfValid]() mutable {
                    if (state->resolved) return;
                    const auto totalSize = extractTotalSize(reply);
                    if (totalSize > kValidationMaxContentBytes) {
                        state->resolved = true;
                        reply->abort();
                        emit urlValidationFinished(context, false,
                                                   QStringLiteral("URL is too large (%1 MB)")
                                                       .arg(QString::number(totalSize / (1024.0 * 1024.0), 'f', 1)));
                        return;
                    }
                    finishIfValid();
                });

        connect(reply, &QNetworkReply::readyRead, this,
                [this, reply, state, context, kind, finishIfValid]() mutable {
                    if (state->resolved) return;
                    const auto remaining = kValidationSampleBytes - state->sample.size();
                    if (remaining > 0) {
                        state->sample += reply->read(remaining);
                    }
                    if (state->sample.size() > kValidationSampleBytes) {
                        state->resolved = true;
                        reply->abort();
                        emit urlValidationFinished(context, false,
                                                   QStringLiteral("URL does not look like a text playlist/XML feed"));
                        return;
                    }
                    finishIfValid();
                });

        connect(reply, &QNetworkReply::finished, this,
                [this, reply, state, context, kind, finishIfValid]() {
                    reply->deleteLater();
                    if (state->resolved) return;

                    if (reply->error() != QNetworkReply::NoError
                        && reply->error() != QNetworkReply::OperationCanceledError) {
                        emit urlValidationFinished(context, false,
                                                   QStringLiteral("Validation request failed: %1")
                                                       .arg(reply->errorString()));
                        return;
                    }

                    if (state->sample.isEmpty()) {
                        state->sample = reply->readAll();
                    }
                    finishIfValid();
                    if (!state->resolved) {
                        emit urlValidationFinished(context, false,
                                                   kind == ValidationKind::M3u
                                                       ? QStringLiteral("URL does not appear to be an M3U playlist")
                                                       : QStringLiteral("URL does not appear to be XMLTV data"));
                    }
                });
    };

    if (type == QStringLiteral("m3u")) {
        validateTextPayload(ValidationKind::M3u, QStringLiteral("server"));
    } else {
        emit urlValidationFinished(QStringLiteral("server"), false,
                                   QStringLiteral("Unknown server type"));
    }
}

void AppViewModel::validateEpgSourceInput(const QString &url) {
    if (!httpClient_) {
        emit urlValidationFinished(QStringLiteral("epg"), false,
                                   QStringLiteral("HTTP client unavailable"));
        return;
    }

    const auto normalizedUrl = normalizeHttpUrl(url);
    if (normalizedUrl.isEmpty()) {
        emit urlValidationFinished(QStringLiteral("epg"), false,
                                   QStringLiteral("Enter a valid URL"));
        return;
    }

    QNetworkRequest request{QUrl(normalizedUrl)};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setRawHeader("Range", "bytes=0-16383");

    auto *reply = httpClient_->get(request);
    auto state = std::make_shared<ValidationProbeState>();

    auto finishIfValid = [this, reply, state]() {
        if (state->resolved) return;

        const auto totalSize = extractTotalSize(reply);
        if (totalSize > kValidationMaxContentBytes) {
            state->resolved = true;
            reply->abort();
            emit urlValidationFinished(QStringLiteral("epg"), false,
                                       QStringLiteral("URL is too large (%1 MB)")
                                           .arg(QString::number(totalSize / (1024.0 * 1024.0), 'f', 1)));
            return;
        }

        const auto contentType = contentTypeLower(reply);
        const auto sample = stripBomAndWhitespace(state->sample);
        const auto valid = looksLikeXmltv(sample);

        if (!valid && !contentType.isEmpty() && contentTypeLooksBinary(contentType)) {
            state->resolved = true;
            reply->abort();
            emit urlValidationFinished(QStringLiteral("epg"), false,
                                       QStringLiteral("URL returned binary content (%1)")
                                           .arg(contentType));
            return;
        }

        if (valid) {
            state->resolved = true;
            reply->abort();
            emit urlValidationFinished(QStringLiteral("epg"), true, {});
        }
    };

    connect(reply, &QNetworkReply::metaDataChanged, this,
            [this, reply, state, finishIfValid]() mutable {
                if (state->resolved) return;
                const auto totalSize = extractTotalSize(reply);
                if (totalSize > kValidationMaxContentBytes) {
                    state->resolved = true;
                    reply->abort();
                    emit urlValidationFinished(QStringLiteral("epg"), false,
                                               QStringLiteral("URL is too large (%1 MB)")
                                                   .arg(QString::number(totalSize / (1024.0 * 1024.0), 'f', 1)));
                    return;
                }
                finishIfValid();
            });

    connect(reply, &QNetworkReply::readyRead, this,
            [this, reply, state, finishIfValid]() mutable {
                if (state->resolved) return;
                const auto remaining = kValidationSampleBytes - state->sample.size();
                if (remaining > 0) {
                    state->sample += reply->read(remaining);
                }
                if (state->sample.size() > kValidationSampleBytes) {
                    state->resolved = true;
                    reply->abort();
                    emit urlValidationFinished(QStringLiteral("epg"), false,
                                               QStringLiteral("URL does not look like XMLTV data"));
                    return;
                }
                finishIfValid();
            });

    connect(reply, &QNetworkReply::finished, this,
            [this, reply, state, finishIfValid]() {
                reply->deleteLater();
                if (state->resolved) return;

                if (reply->error() != QNetworkReply::NoError
                    && reply->error() != QNetworkReply::OperationCanceledError) {
                    emit urlValidationFinished(QStringLiteral("epg"), false,
                                               QStringLiteral("Validation request failed: %1")
                                                   .arg(reply->errorString()));
                    return;
                }

                if (state->sample.isEmpty()) {
                    state->sample = reply->readAll();
                }
                finishIfValid();
                if (!state->resolved) {
                    emit urlValidationFinished(QStringLiteral("epg"), false,
                                               QStringLiteral("URL does not appear to be XMLTV data"));
                }
            });
}

struct SeriesPrefetchState {
    int64_t serverId;
    QVector<iptvxs::Channel> series;
    std::atomic<int> nextIndex{0};
    std::atomic<int> completed{0};
    std::atomic<int> errors{0};
    static constexpr int kParallelWorkers = 2;
};

void AppViewModel::prefetchSeriesCache(int64_t serverId) {
    if (!channelRepo_ || !serverRepo_ || !seriesCacheRepo_ || !httpClient_) return;

    auto srv = serverRepo_->findById(serverId);
    if (!srv || srv->type != QStringLiteral("xtream")) return;

    auto seriesChannels = channelRepo_->findByServerAndType(serverId, QStringLiteral("series"), -1, 0);
    if (seriesChannels.isEmpty()) return;

    qInfo("Pre-fetching series cache for %lld series on server %lld",
          static_cast<long long>(seriesChannels.size()), static_cast<long long>(serverId));

    auto state = std::make_shared<SeriesPrefetchState>();
    state->serverId = serverId;
    state->series = std::move(seriesChannels);

    for (int i = 0; i < SeriesPrefetchState::kParallelWorkers; ++i) {
        prefetchNextSeries(state);
    }
}

void AppViewModel::prefetchNextSeries(std::shared_ptr<SeriesPrefetchState> state) {
    if (!serverRepo_ || !httpClient_ || !seriesCacheRepo_) return;

    int index = state->nextIndex.fetch_add(1);
    if (index >= state->series.size()) return;

    const auto &ch = state->series.at(index);
    if (ch.externalId.isEmpty()) {
        QMetaObject::invokeMethod(this, [this, state]() {
            prefetchNextSeries(state);
        }, Qt::QueuedConnection);
        return;
    }

    // Skip if already cached — resume where we left off after restart
    if (seriesCacheRepo_->find(state->serverId, ch.externalId)) {
        state->completed.fetch_add(1);
        QMetaObject::invokeMethod(this, [this, state]() {
            prefetchNextSeries(state);
        }, Qt::QueuedConnection);
        return;
    }

    auto srv = serverRepo_->findById(state->serverId);
    if (!srv) return;

    auto *client = new iptvxs::XtreamClient(
        httpClient_.get(), srv->url, srv->username, srv->password, this);

    connect(client, &iptvxs::XtreamClient::seriesInfoReady, this,
            [this, client, state, ch]
            (const QString &, const QJsonObject &info) {
                client->deleteLater();
                if (seriesCacheRepo_ && !info.isEmpty()) {
                    seriesCacheRepo_->store(state->serverId, ch.externalId, ch.name, ch.logoUrl, info);
                }
                int done = state->completed.fetch_add(1) + 1;
                int total = state->series.size();
                if (done % 100 == 0 || done == total) {
                    qInfo("Series cache: %d/%d prefetched (%d errors)",
                          done, total, state->errors.load());
                }
                QTimer::singleShot(50, this, [this, state]() {
                    prefetchNextSeries(state);
                });
            });

    connect(client, &iptvxs::XtreamClient::errorOccurred, this,
            [this, client, state]
            (const QString &msg) {
                client->deleteLater();
                state->errors.fetch_add(1);
                int done = state->completed.fetch_add(1) + 1;
                int total = state->series.size();
                if (done % 100 == 0) {
                    qInfo("Series cache: %d/%d prefetched (%d errors)",
                          done, total, state->errors.load());
                }
                QTimer::singleShot(100, this, [this, state]() {
                    prefetchNextSeries(state);
                });
            });

    client->fetchSeriesInfo(ch.externalId);
}

QVariantMap AppViewModel::channelInfo(int64_t channelId) const {
    QVariantMap result;
    if (!channelRepo_ || channelId <= 0) return result;
    auto ch = channelRepo_->findById(channelId);
    if (!ch) return result;
    result[QStringLiteral("type")] = ch->type;
    result[QStringLiteral("serverId")] = QVariant::fromValue(ch->serverId);
    result[QStringLiteral("externalId")] = ch->externalId;
    result[QStringLiteral("name")] = ch->name;
    result[QStringLiteral("logoUrl")] = ch->logoUrl;
    return result;
}

void AppViewModel::playChannelById(int64_t channelId, int startPositionSecs) {
    if (!channelRepo_ || channelId <= 0) return;
    auto ch = channelRepo_->findById(channelId);
    if (!ch) return;
    playerVm_->play(ch->streamUrl, ch->name, ch->logoUrl, ch->id, ch->epgChannelId,
                    startPositionSecs, true, ch->type == QStringLiteral("live"));
    setCurrentView(QStringLiteral("player"));
}

void AppViewModel::playHistoryEntry(int64_t historyId) {
    if (!historyRepo_ || !playerVm_ || historyId <= 0) return;
    auto entry = historyRepo_->findById(historyId);
    if (!entry) return;

    lastHistoryEntryId_ = entry->id;

    const auto resumePlan = resolveSeriesResumePlan(*entry);
    const auto playUrl = resumePlan.value(QStringLiteral("playUrl")).toString().isEmpty()
        ? entry->streamUrl
        : resumePlan.value(QStringLiteral("playUrl")).toString();
    const auto playTitle = resumePlan.value(QStringLiteral("playTitle")).toString().isEmpty()
        ? entry->channelName
        : resumePlan.value(QStringLiteral("playTitle")).toString();
    const auto playLogo = resumePlan.value(QStringLiteral("playLogo")).toString().isEmpty()
        ? entry->channelLogo
        : resumePlan.value(QStringLiteral("playLogo")).toString();
    const auto startPositionVar = resumePlan.value(QStringLiteral("startPositionSecs"));
    const auto startPositionSecs = startPositionVar.isValid() ? startPositionVar.toInt() : entry->positionSecs;
    const auto jumpedToNext = resumePlan.value(QStringLiteral("jumpedToNext")).toBool();

    if (!jumpedToNext) {
        resumeHistoryPending_ = true;
        historyRepo_->touchEntry(entry->id);
        if (historyVm_) historyVm_->refresh();
    } else if (historyVm_) {
        lastHistoryEntryId_ = 0;
        resumeHistoryPending_ = false;
        historyVm_->refresh();
    }

    if (!playUrl.isEmpty()) {
        if (entry->channelId > 0 && channelRepo_) {
            auto ch = channelRepo_->findById(entry->channelId);
            if (ch && ch->type == QStringLiteral("series") && !ch->externalId.isEmpty()) {
                setActiveSeriesDialog(ch->name, ch->serverId, ch->externalId, ch->logoUrl);
            }
        }
        const bool isLiveEntry = entry->channelType == QStringLiteral("live");
        playerVm_->play(playUrl, playTitle, playLogo, entry->channelId, {},
                        startPositionSecs, true, isLiveEntry);
        iptvxs::HistoryEntry resumeEntry = *entry;
        resumeEntry.streamUrl = playUrl;
        resumeEntry.channelName = playTitle;
        resumeEntry.channelLogo = playLogo;
        resumeEntry.positionSecs = startPositionSecs;
        restoreSeriesAutoNextFromHistory(resumeEntry);
        if (!playerVm_->isLive()) startHistoryFlushTimer();
        setCurrentView(QStringLiteral("player"));
        return;
    }

    if (entry->channelId > 0 && channelRepo_) {
        auto ch = channelRepo_->findById(entry->channelId);
        if (ch) {
            if (ch->type == QStringLiteral("series") && !ch->externalId.isEmpty()) {
                setActiveSeriesDialog(ch->name, ch->serverId, ch->externalId, ch->logoUrl);
            }
            playerVm_->play(ch->streamUrl, ch->name, ch->logoUrl, ch->id,
                            ch->epgChannelId, startPositionSecs, true,
                            ch->type == QStringLiteral("live"));
            iptvxs::HistoryEntry resumeEntry = *entry;
            resumeEntry.streamUrl = ch->streamUrl;
            resumeEntry.channelName = ch->name;
            resumeEntry.channelLogo = ch->logoUrl;
            resumeEntry.positionSecs = startPositionSecs;
            restoreSeriesAutoNextFromHistory(resumeEntry);
            if (!playerVm_->isLive()) startHistoryFlushTimer();
            setCurrentView(QStringLiteral("player"));
        }
    }
}

QVariantMap AppViewModel::resolveSeriesResumePlan(const iptvxs::HistoryEntry &entry) const {
    QVariantMap plan;
    plan[QStringLiteral("playUrl")] = entry.streamUrl;
    plan[QStringLiteral("playTitle")] = entry.channelName;
    plan[QStringLiteral("playLogo")] = entry.channelLogo;
    plan[QStringLiteral("startPositionSecs")] = entry.positionSecs;
    plan[QStringLiteral("jumpedToNext")] = false;

    if (!channelRepo_ || !serverRepo_ || !seriesCacheRepo_) return plan;
    if (!(entry.channelType == QStringLiteral("series") || entry.streamUrl.contains(QStringLiteral("/series/")))) return plan;
    if (entry.channelId <= 0) return plan;

    auto ch = channelRepo_->findById(entry.channelId);
    if (!ch || ch->type != QStringLiteral("series") || ch->externalId.isEmpty()) return plan;
    auto srv = serverRepo_->findById(ch->serverId);
    if (!srv || srv->type != QStringLiteral("xtream") || srv->url.isEmpty()) return plan;

    auto cached = seriesCacheRepo_->find(srv->id, ch->externalId);
    if (!cached) return plan;

    auto seasons = parseSeriesEpisodes(*cached, ch->name, ch->logoUrl);
    if (seasons.isEmpty()) return plan;

    const auto currentUrl = entry.streamUrl.isEmpty() ? QString{} : entry.streamUrl;
    if (currentUrl.isEmpty()) return plan;

    auto buildTitle = [seriesName = ch->name](const QVariantMap &seasonMap, const QVariantMap &epMap, int fallbackEpisodeIndex) {
        auto seasonNum = seasonMap.value(QStringLiteral("season")).toString();
        auto epNum = epMap.value(QStringLiteral("episodeNum")).toString();
        if (epNum.isEmpty()) epNum = QString::number(fallbackEpisodeIndex + 1);
        QString title = seriesName + QStringLiteral(" - S") + seasonNum + QStringLiteral("E") + epNum;
        auto epTitle = epMap.value(QStringLiteral("title")).toString();
        if (!epTitle.isEmpty()) {
            title += QStringLiteral(" - ") + epTitle;
        }
        return title;
    };

    const bool completed = entry.totalDurationSecs > 0
                           && entry.positionSecs >= qMax(1, static_cast<int>(entry.totalDurationSecs * 0.95));

    for (int seasonIndex = 0; seasonIndex < seasons.size(); ++seasonIndex) {
        const auto seasonMap = seasons.at(seasonIndex).toMap();
        const auto episodes = seasonMap.value(QStringLiteral("episodes")).toList();
        for (int episodeIndex = 0; episodeIndex < episodes.size(); ++episodeIndex) {
            const auto epMap = episodes.at(episodeIndex).toMap();
            auto epExt = epMap.value(QStringLiteral("ext")).toString();
            if (epExt.isEmpty()) epExt = QStringLiteral("mkv");
            const auto epUrl = buildSeriesEpisodeUrl(epMap.value(QStringLiteral("id")).toString(), epExt);
            if (epUrl.isEmpty() || epUrl != currentUrl) continue;

            if (completed) {
                QVariantMap nextEpMap;
                QVariantMap nextSeasonMap;
                int nextEpisodeIndex = -1;
                if (episodeIndex + 1 < episodes.size()) {
                    nextEpMap = episodes.at(episodeIndex + 1).toMap();
                    nextSeasonMap = seasonMap;
                    nextEpisodeIndex = episodeIndex + 1;
                } else if (seasonIndex + 1 < seasons.size()) {
                    nextSeasonMap = seasons.at(seasonIndex + 1).toMap();
                    const auto nextEpisodes = nextSeasonMap.value(QStringLiteral("episodes")).toList();
                    if (!nextEpisodes.isEmpty()) {
                        nextEpMap = nextEpisodes.first().toMap();
                        nextEpisodeIndex = 0;
                    }
                }

                if (nextEpisodeIndex >= 0 && !nextEpMap.isEmpty()) {
                    auto nextExt = nextEpMap.value(QStringLiteral("ext")).toString();
                    if (nextExt.isEmpty()) nextExt = QStringLiteral("mkv");
                    const auto nextUrl = buildSeriesEpisodeUrl(nextEpMap.value(QStringLiteral("id")).toString(), nextExt);
                    if (!nextUrl.isEmpty()) {
                        plan[QStringLiteral("playUrl")] = nextUrl;
                        plan[QStringLiteral("playTitle")] = buildTitle(nextSeasonMap, nextEpMap, nextEpisodeIndex);
                        plan[QStringLiteral("playLogo")] = nextEpMap.value(QStringLiteral("logoUrl")).toString();
                        plan[QStringLiteral("startPositionSecs")] = 0;
                        plan[QStringLiteral("jumpedToNext")] = true;
                    }
                }
            }
            return plan;
        }
    }

    return plan;
}

bool AppViewModel::restoreSeriesAutoNextFromHistory(const iptvxs::HistoryEntry &entry) {
    if (!playerVm_ || !channelRepo_ || !serverRepo_ || !seriesCacheRepo_) return false;
    if (entry.channelId <= 0) return false;
    if (!(entry.channelType == QStringLiteral("series") || entry.streamUrl.contains(QStringLiteral("/series/")))) {
        return false;
    }

    auto ch = channelRepo_->findById(entry.channelId);
    if (!ch || ch->type != QStringLiteral("series") || ch->externalId.isEmpty()) return false;

    auto srv = serverRepo_->findById(ch->serverId);
    if (!srv || srv->type != QStringLiteral("xtream") || srv->url.isEmpty()) return false;

    auto cached = seriesCacheRepo_->find(srv->id, ch->externalId);
    if (!cached) return false;

    auto seasons = parseSeriesEpisodes(*cached, ch->name, ch->logoUrl);
    if (seasons.isEmpty()) return false;

    seriesServerUrl_ = srv->url;
    seriesUsername_ = srv->username;
    seriesPassword_ = srv->password;

    const auto currentUrl = entry.streamUrl.isEmpty() ? playerVm_->currentUrl() : entry.streamUrl;
    if (currentUrl.isEmpty()) return false;

    auto makeTitle = [seriesName = ch->name](const QVariantMap &seasonMap, const QVariantMap &epMap, int fallbackEpisodeIndex) {
        auto seasonNum = seasonMap.value(QStringLiteral("season")).toString();
        auto epNum = epMap.value(QStringLiteral("episodeNum")).toString();
        if (epNum.isEmpty()) {
            epNum = QString::number(fallbackEpisodeIndex + 1);
        }
        QString title = seriesName + QStringLiteral(" - S") + seasonNum + QStringLiteral("E") + epNum;
        auto epTitle = epMap.value(QStringLiteral("title")).toString();
        if (!epTitle.isEmpty()) {
            title += QStringLiteral(" - ") + epTitle;
        }
        return title;
    };

    for (int seasonIndex = 0; seasonIndex < seasons.size(); ++seasonIndex) {
        const auto seasonMap = seasons.at(seasonIndex).toMap();
        const auto episodes = seasonMap.value(QStringLiteral("episodes")).toList();
        for (int episodeIndex = 0; episodeIndex < episodes.size(); ++episodeIndex) {
            const auto epMap = episodes.at(episodeIndex).toMap();
            const auto epId = epMap.value(QStringLiteral("id")).toString();
            auto epExt = epMap.value(QStringLiteral("ext")).toString();
            if (epExt.isEmpty()) {
                epExt = QStringLiteral("mkv");
            }
            const auto epUrl = buildSeriesEpisodeUrl(epId, epExt);
            if (epUrl.isEmpty() || epUrl != currentUrl) {
                continue;
            }

            QVariantMap nextEpMap;
            QVariantMap nextSeasonMap;
            int nextEpisodeIndex = -1;
            if (episodeIndex + 1 < episodes.size()) {
                nextEpMap = episodes.at(episodeIndex + 1).toMap();
                nextSeasonMap = seasonMap;
                nextEpisodeIndex = episodeIndex + 1;
            } else if (seasonIndex + 1 < seasons.size()) {
                nextSeasonMap = seasons.at(seasonIndex + 1).toMap();
                const auto nextEpisodes = nextSeasonMap.value(QStringLiteral("episodes")).toList();
                if (!nextEpisodes.isEmpty()) {
                    nextEpMap = nextEpisodes.first().toMap();
                    nextEpisodeIndex = 0;
                }
            }

            if (nextEpisodeIndex >= 0 && !nextEpMap.isEmpty()) {
                auto nextExt = nextEpMap.value(QStringLiteral("ext")).toString();
                if (nextExt.isEmpty()) {
                    nextExt = QStringLiteral("mkv");
                }
                const auto nextUrl = buildSeriesEpisodeUrl(
                    nextEpMap.value(QStringLiteral("id")).toString(),
                    nextExt);
                if (!nextUrl.isEmpty()) {
                    const auto nextTitle = makeTitle(nextSeasonMap, nextEpMap, nextEpisodeIndex);
                    playerVm_->setNextEpisode(nextUrl, nextTitle, nextEpMap.value(QStringLiteral("logoUrl")).toString(), ch->id);
                    if (chromecastMgr_ && chromecastMgr_->connected()) {
                        chromecastMgr_->setNextEpisode(nextUrl, nextTitle);
                    }
                }
            }
            return true;
        }
    }

    return false;
}

void AppViewModel::startHistoryFlushTimer() {
    if (!historyFlushTimer_ || !historyRepo_ || !playerVm_ || playerVm_->isLive() || lastHistoryEntryId_ <= 0) {
        return;
    }
    historyFlushTimer_->start();
}

void AppViewModel::stopHistoryFlushTimer() {
    if (historyFlushTimer_) {
        historyFlushTimer_->stop();
    }
}

void AppViewModel::persistCurrentHistoryPosition() {
    if (!historyRepo_ || lastHistoryEntryId_ <= 0 || playerVm_->isLive()) return;

    auto pos = static_cast<int>(playerVm_->position());
    if (pos <= 0) {
        pos = static_cast<int>(playerVm_->lastPosition());
    }
    auto dur = static_cast<int>(playerVm_->duration());
    if (dur > 0) {
        historyRepo_->updatePosition(lastHistoryEntryId_, pos, dur);
    } else {
        historyRepo_->touchEntry(lastHistoryEntryId_);
    }
    if (historyVm_) historyVm_->refresh();
}

void AppViewModel::playRecordingFromDrive(int64_t recordingId) {
    if (!recordingRepo_ || !gdriveAuth_ || !playerVm_) return;

    auto rec = recordingRepo_->findById(recordingId);
    if (!rec || rec->gdriveFileId.isEmpty()) {
        emit errorOccurred(QStringLiteral("Recording has no Google Drive file"));
        return;
    }

    auto startPlayback = [this, recordingId]() {
        auto rec = recordingRepo_->findById(recordingId);
        if (!rec || rec->gdriveFileId.isEmpty()) {
            emit errorOccurred(QStringLiteral("Recording has no Google Drive file"));
            return;
        }

        auto token = gdriveAuth_->accessToken();
        if (token.isEmpty()) {
            emit errorOccurred(QStringLiteral("Not authenticated with Google Drive"));
            return;
        }

        auto url = QStringLiteral("https://www.googleapis.com/drive/v3/files/%1?alt=media")
                       .arg(rec->gdriveFileId);

        auto *player = playerVm_->mpvPlayer();
        if (player) {
            player->setHttpHeaders({QStringLiteral("Authorization: Bearer %1").arg(token)});
        }

        auto channelName = rec->filePath.isEmpty()
            ? QStringLiteral("Recording %1").arg(recordingId)
            : QFileInfo(rec->filePath).baseName();

        qInfo("Playing recording %lld from Google Drive", static_cast<long long>(recordingId));
        playerVm_->play(url, channelName, {}, 0, {}, 0, true, true);
        setCurrentView(QStringLiteral("player"));

        if (gdrivePlaybackCleanupConnection_) {
            disconnect(gdrivePlaybackCleanupConnection_);
        }
        gdrivePlaybackCleanupConnection_ = connect(playerVm_, &PlayerViewModel::stateChanged, this, [this, player]() {
            if (playerVm_->stopped() && player) {
                player->clearHttpHeaders();
                disconnect(gdrivePlaybackCleanupConnection_);
                gdrivePlaybackCleanupConnection_ = {};
            }
        });
    };

    if (gdriveAuth_->needsRefresh()) {
        if (gdrivePlaybackCleanupConnection_) {
            disconnect(gdrivePlaybackCleanupConnection_);
            gdrivePlaybackCleanupConnection_ = {};
        }

        auto conn = std::make_shared<QMetaObject::Connection>();
        auto errConn = std::make_shared<QMetaObject::Connection>();
        *conn = connect(gdriveAuth_.get(), &iptvxs::GDriveAuth::tokenRefreshed, this,
            [this, startPlayback, conn, errConn]() {
                disconnect(*conn);
                disconnect(*errConn);
                startPlayback();
            });
        *errConn = connect(gdriveAuth_.get(), &iptvxs::GDriveAuth::authenticationFailed, this,
            [this, conn, errConn](const QString &error) {
                disconnect(*conn);
                disconnect(*errConn);
                emit errorOccurred(QStringLiteral("Google Drive auth refresh failed: %1").arg(error));
            });
        gdriveAuth_->refreshTokenIfNeeded();
        return;
    }

    startPlayback();
}

void AppViewModel::setZapContext(const QVariantList &items, int64_t currentChannelId, const QString &title) {
    QVariantList filtered;
    filtered.reserve(items.size());
    for (const auto &value : items) {
        const auto map = value.toMap();
        const auto type = map.value(QStringLiteral("type")).toString();
        const auto channelId = map.value(QStringLiteral("channelId")).toLongLong();
        const auto streamUrl = map.value(QStringLiteral("streamUrl")).toString();
        if (type != QStringLiteral("live") || channelId <= 0 || streamUrl.isEmpty()) {
            continue;
        }
        filtered.append(map);
    }

    zapContextItems_ = filtered;
    zapContextTitle_ = title;
    zapContextIndex_ = -1;
    for (int i = 0; i < zapContextItems_.size(); ++i) {
        const auto map = zapContextItems_.at(i).toMap();
        if (map.value(QStringLiteral("channelId")).toLongLong() == currentChannelId) {
            zapContextIndex_ = i;
            break;
        }
    }
    if (zapContextIndex_ < 0 && !zapContextItems_.isEmpty()) {
        zapContextIndex_ = 0;
    }
    emit zapContextChanged();
}

void AppViewModel::clearZapContext() {
    if (zapContextItems_.isEmpty() && zapContextIndex_ < 0 && zapContextTitle_.isEmpty()) return;
    zapContextItems_.clear();
    zapContextIndex_ = -1;
    zapContextTitle_.clear();
    emit zapContextChanged();
}

bool AppViewModel::hasZapContext() const {
    return !zapContextItems_.isEmpty();
}

QVariantList AppViewModel::zapContext() const {
    return zapContextItems_;
}

int AppViewModel::zapContextIndex() const {
    return zapContextIndex_;
}

QString AppViewModel::zapContextTitle() const {
    return zapContextTitle_;
}

void AppViewModel::zapPlayIndex(int index) {
    if (!playerVm_ || index < 0 || index >= zapContextItems_.size()) return;
    const auto item = zapContextItems_.at(index).toMap();
    const auto channelId = item.value(QStringLiteral("channelId")).toLongLong();
    const auto streamUrl = item.value(QStringLiteral("streamUrl")).toString();
    const auto name = item.value(QStringLiteral("name")).toString();
    const auto logoUrl = item.value(QStringLiteral("logoUrl")).toString();
    const auto epgChannelId = item.value(QStringLiteral("epgChannelId")).toString();
    if (channelId <= 0 || streamUrl.isEmpty() || name.isEmpty()) return;

    zapContextIndex_ = index;
    emit zapContextChanged();
    playerVm_->setReconnecting(true);
    playerVm_->play(streamUrl, name, logoUrl, channelId, epgChannelId, 0, true, true);
    setCurrentView(QStringLiteral("player"));
}

void AppViewModel::zapNext() {
    if (zapContextItems_.isEmpty()) return;
    const int next = qMin(zapContextIndex_ + 1, zapContextItems_.size() - 1);
    zapPlayIndex(next);
}

void AppViewModel::zapPrevious() {
    if (zapContextItems_.isEmpty()) return;
    const int prev = qMax(zapContextIndex_ - 1, 0);
    zapPlayIndex(prev);
}

void AppViewModel::playChannelByName(const QString &name) {
    if (!channelRepo_ || !serverRepo_ || name.isEmpty()) return;
    auto servers = serverRepo_->findAll();
    for (const auto &srv : servers) {
        auto results = channelRepo_->search(srv.id, name, 1, 0);
        if (!results.isEmpty()) {
            const auto &ch = results.first();
            playerVm_->play(ch.streamUrl, ch.name, ch.logoUrl, ch.id, ch.epgChannelId, 0, true,
                            ch.type == QStringLiteral("live"));
            setCurrentView(QStringLiteral("player"));
            return;
        }
    }
}

void AppViewModel::playSeriesEpisode(const QString &episodeId, const QString &ext,
                                      const QString &title, const QString &logoUrl,
                                      int64_t channelId) {
    auto url = QStringLiteral("%1/series/%2/%3/%4.%5")
                   .arg(seriesServerUrl_, seriesUsername_, seriesPassword_, episodeId, ext);
    playerVm_->play(url, title, logoUrl, channelId, {}, 0, true, false);
    setCurrentView(QStringLiteral("player"));
}

bool AppViewModel::isCategoryHidden(int64_t categoryId) const {
    if (!categorySettingsRepo_) return false;
    return categorySettingsRepo_->isHidden(categoryId);
}

void AppViewModel::setActiveSeriesDialog(const QString &name, int64_t serverId, const QString &seriesId, const QString &logoUrl, int64_t channelId) {
    activeSeriesName_ = name;
    activeSeriesServerId_ = serverId;
    activeSeriesId_ = seriesId;
    activeSeriesLogo_ = logoUrl;
    if (channelId > 0) activeSeriesChannelId_ = channelId;
}

void AppViewModel::clearActiveSeriesDialog() {
    activeSeriesName_.clear();
    activeSeriesServerId_ = 0;
    activeSeriesId_.clear();
    activeSeriesLogo_.clear();
    activeSeriesChannelId_ = 0;
}

void AppViewModel::reopenSeriesEpisodes() {
    if (activeSeriesId_.isEmpty()) return;
    fetchSeriesEpisodes(activeSeriesServerId_, activeSeriesId_, activeSeriesName_, activeSeriesLogo_);
}

bool AppViewModel::hasActiveSeriesDialog() const { return !activeSeriesId_.isEmpty(); }
QString AppViewModel::activeSeriesName() const { return activeSeriesName_; }
int64_t AppViewModel::activeSeriesServerId() const { return activeSeriesServerId_; }
QString AppViewModel::activeSeriesId() const { return activeSeriesId_; }
QString AppViewModel::activeSeriesLogo() const { return activeSeriesLogo_; }
int64_t AppViewModel::activeSeriesChannelId() const { return activeSeriesChannelId_; }

bool AppViewModel::hasPendingSeriesEpisodes() const {
    return !pendingSeriesEpisodes_.isEmpty();
}

QString AppViewModel::pendingSeriesName() const {
    return pendingSeriesName_;
}

QVariantList AppViewModel::pendingSeriesEpisodes() const {
    return pendingSeriesEpisodes_;
}

void AppViewModel::clearPendingSeriesEpisodes() {
    pendingSeriesName_.clear();
    pendingSeriesEpisodes_.clear();
}

bool AppViewModel::hasWatched(int64_t channelId) const {
    if (!historyRepo_ || channelId <= 0) return false;
    auto entries = historyRepo_->findRecent(500);
    for (const auto &e : entries) {
        if (e.channelId == channelId) return true;
    }
    return false;
}

bool AppViewModel::hasWatchedUrl(const QString &url) const {
    if (!historyRepo_ || url.isEmpty()) return false;
    auto entries = historyRepo_->findRecent(500);
    for (const auto &e : entries) {
        if (e.streamUrl == url) return true;
    }
    return false;
}

QString AppViewModel::buildSeriesEpisodeUrl(const QString &episodeId, const QString &ext) const {
    if (seriesServerUrl_.isEmpty()) return {};
    return QStringLiteral("%1/series/%2/%3/%4.%5")
               .arg(seriesServerUrl_, seriesUsername_, seriesPassword_, episodeId, ext);
}

QString AppViewModel::currentProgrammeTitle(const QString &epgChannelId) const {
    if (!progRepo_ || epgChannelId.isEmpty()) return {};
    auto current = progRepo_->findCurrent(epgChannelId);
    if (current.isEmpty()) return {};
    return current.first().title;
}

QString AppViewModel::nextProgrammeTitle(const QString &epgChannelId) const {
    if (!progRepo_ || epgChannelId.isEmpty()) return {};
    auto current = progRepo_->findCurrent(epgChannelId);
    if (current.isEmpty()) return {};
    // Find programmes starting after the current one ends
    auto nextStart = current.first().endTime;
    auto programmes = progRepo_->findByChannel(epgChannelId, nextStart, nextStart + 7200);
    if (programmes.isEmpty()) return {};
    return programmes.first().title;
}

QString AppViewModel::nextProgrammeTime(const QString &epgChannelId) const {
    if (!progRepo_ || epgChannelId.isEmpty()) return {};
    auto current = progRepo_->findCurrent(epgChannelId);
    if (current.isEmpty()) return {};
    auto nextStart = current.first().endTime;
    auto programmes = progRepo_->findByChannel(epgChannelId, nextStart, nextStart + 7200);
    if (programmes.isEmpty()) return {};
    auto dt = QDateTime::fromSecsSinceEpoch(programmes.first().startTime);
    return dt.toString(QStringLiteral("HH:mm"));
}

bool AppViewModel::fileExists(const QString &path) const {
    return QFileInfo::exists(path);
}

QString AppViewModel::latestVersion() const { return latestVersion_; }

bool AppViewModel::updateAvailable() const {
    if (latestVersion_.isEmpty() || latestVersion_ == QStringLiteral("unknown")) return false;
    auto strip = [](QString v) { return v.startsWith("v") ? v.mid(1) : v; };
    return strip(latestVersion_) != strip(appVersion());
}

void AppViewModel::checkForUpdates() {
    if (!httpClient_) return;
    QUrl url(QStringLiteral("https://iptvxs.schelstraete.org/api/v1/version"));
    auto *reply = httpClient_->get(url);
    QTimer::singleShot(5000, reply, [reply]() {
        if (!reply->isFinished()) { reply->abort(); }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning("Version check failed: %s", qPrintable(reply->errorString()));
            if (latestVersion_.isEmpty()) {
                latestVersion_ = QStringLiteral("unknown");
                emit latestVersionChanged();
            }
            return;
        }
        auto data = reply->readAll();
        auto doc = QJsonDocument::fromJson(data);
        auto obj = doc.object();
        if (obj.contains("error") || obj.value("latest").toString().isEmpty()) {
            qWarning("Version check: no release found (%s)", data.constData());
            if (latestVersion_.isEmpty() || latestVersion_ == QStringLiteral("checking...")) {
                latestVersion_ = QStringLiteral("unknown");
                emit latestVersionChanged();
            }
            return;
        }
        auto tag = obj.value("latest").toString();
        if (tag != latestVersion_) {
            latestVersion_ = tag;
            emit latestVersionChanged();
            qInfo("Latest version: %s (current: %s)", qPrintable(tag), qPrintable(appVersion()));
        }
    });
}

void AppViewModel::checkForUpdatesWithUI() {
#ifdef Q_OS_WIN
    qInfo("Manual update check requested");
    win_sparkle_check_update_with_ui();
#else
    qInfo("Manual update check requested");
    checkForUpdates();
#endif
}

void AppViewModel::openGitHub() {
    const QString url = QStringLiteral("https://github.com/bschelst/iptvXS");
    if (qEnvironmentVariableIsSet("GAMESCOPE_WAYLAND_DISPLAY")) {
        QProcess::startDetached(QStringLiteral("flatpak-spawn"),
                                {QStringLiteral("--host"),
                                 QStringLiteral("steam"),
                                 QStringLiteral("steam://openurl/") + url});
    } else {
        QDesktopServices::openUrl(QUrl(url));
    }
}

void AppViewModel::openAuthUrlInSteamBrowser(const QString &url) {
    const QString steamUrl = QStringLiteral("steam://openurl/") + url;
    QProcess::startDetached(QStringLiteral("flatpak-spawn"),
                            {QStringLiteral("--host"),
                             QStringLiteral("steam"),
                             steamUrl});
}

void AppViewModel::resetDatabase() {
    if (!database_) return;

    auto path = databaseFilePath();

    database_->close();
    QFile::remove(path);

    databaseReady_ = false;
    emit databaseReadyChanged();

    if (database_->open(path)) {
        auto db = database_->connection();
        settingsRepo_ = std::make_unique<iptvxs::SettingsRepository>(db, this);
        serverRepo_ = std::make_unique<iptvxs::ServerRepository>(db, this);
        epgSourceRepo_ = std::make_unique<iptvxs::EpgSourceRepository>(db, this);
        connect(epgSourceRepo_.get(), &iptvxs::EpgSourceRepository::errorOccurred,
                this, &AppViewModel::errorOccurred);
        categoryRepo_ = std::make_unique<iptvxs::CategoryRepository>(db, this);
        channelRepo_ = std::make_unique<iptvxs::ChannelRepository>(db, this);
        favoriteRepo_ = std::make_unique<iptvxs::FavoriteRepository>(db, this);
        progRepo_ = std::make_unique<iptvxs::ProgrammeRepository>(db, this);
        recordingRepo_ = std::make_unique<iptvxs::RecordingRepository>(db, this);
        historyRepo_ = std::make_unique<iptvxs::HistoryRepository>(db, this);
        groupRepo_ = std::make_unique<iptvxs::ChannelGroupRepository>(db, this);
        connect(groupRepo_.get(), &iptvxs::ChannelGroupRepository::errorOccurred,
                this, &AppViewModel::errorOccurred);
        categorySettingsRepo_ = std::make_unique<iptvxs::CategorySettingsRepository>(db, this);
        seriesCacheRepo_ = std::make_unique<iptvxs::SeriesCacheRepository>(db, this);

        serverListVm_->setRepositories(serverRepo_.get(), categoryRepo_.get(),
                                       channelRepo_.get(), epgSourceRepo_.get());
        epgSourceListVm_->setRepository(epgSourceRepo_.get());
        epgSourceListVm_->setEpgViewModel(epgVm_);
        favoriteListVm_->setRepository(favoriteRepo_.get());
        channelListVm_->setRepository(channelRepo_.get());
    channelListVm_->setFavoriteRepository(favoriteRepo_.get());
        categoryListVm_->setRepository(categoryRepo_.get());
        categoryListVm_->setCategorySettingsRepository(categorySettingsRepo_.get());
        epgVm_->setRepositories(progRepo_.get(), channelRepo_.get(),
                                favoriteRepo_.get());
        historyVm_->setRepository(historyRepo_.get());
        groupListVm_->setRepository(groupRepo_.get());
        groupListVm_->setChannelRepository(channelRepo_.get());
        recordingMgr_->setRepositories(recordingRepo_.get(), channelRepo_.get(),
                                       settingsRepo_.get(), progRepo_.get());
        recordingListVm_->setRepositories(recordingRepo_.get(), channelRepo_.get(), progRepo_.get());
        recordingListVm_->setRecordingManager(recordingMgr_.get());
        speedTestVm_->setChannelRepository(channelRepo_.get());

        databaseReady_ = true;
        emit databaseReadyChanged();
    }
}

QVariantMap AppViewModel::databaseStats() const {
    QVariantMap stats;
    if (!databaseReady_ || !database_) {
        return stats;
    }

    stats["servers"] = serverRepo_ ? serverRepo_->count() : 0;
    stats["recordings"] = recordingRepo_ ? recordingRepo_->count() : 0;
    stats["favourites"] = favoriteRepo_ ? favoriteRepo_->count() : 0;
    stats["groups"] = groupRepo_ ? groupRepo_->groupCount() : 0;
    stats["programmes"] = progRepo_ ? progRepo_->count() : 0;
    stats["history"] = historyRepo_ ? historyRepo_->count() : 0;

    auto db = database_->connection();
    auto countByType = [&](const QString &type) -> int {
        QSqlQuery q(db);
        q.prepare("SELECT COUNT(*) FROM channels c "
                  "JOIN servers s ON c.server_id = s.id "
                  "WHERE c.type = ? AND s.enabled = 1");
        q.addBindValue(type);
        if (q.exec() && q.next()) {
            return q.value(0).toInt();
        }
        return 0;
    };

    stats["channels"] = countByType("live");
    stats["movies"] = countByType("vod");
    stats["series"] = countByType("series");

    return stats;
}

QVariantMap AppViewModel::runMaintenance() {
    QVariantMap results;
    if (!databaseReady_ || !database_) return results;

    auto db = database_->connection();
    int totalCleaned = 0;

    // 1. Purge EPG programmes older than 7 days
    if (progRepo_) {
        auto cutoff = QDateTime::currentSecsSinceEpoch() - 7 * 86400;
        progRepo_->deleteOlderThan(cutoff);
        QSqlQuery q(db);
        q.exec("SELECT changes()");
        int epgPurged = q.next() ? q.value(0).toInt() : 0;
        results["epg_purged"] = epgPurged;
        totalCleaned += epgPurged;
    }

    // 2. Remove orphaned favorites (channel no longer exists)
    {
        QSqlQuery q(db);
        q.exec("DELETE FROM favorites WHERE channel_id NOT IN (SELECT id FROM channels)");
        q.exec("SELECT changes()");
        int favOrphans = q.next() ? q.value(0).toInt() : 0;
        results["favorites_orphaned"] = favOrphans;
        totalCleaned += favOrphans;
    }

    // 3. Remove orphaned history (channel no longer exists)
    {
        QSqlQuery q(db);
        q.exec("DELETE FROM history WHERE channel_id != 0 AND channel_id NOT IN (SELECT id FROM channels)");
        q.exec("SELECT changes()");
        int histOrphans = q.next() ? q.value(0).toInt() : 0;
        results["history_orphaned"] = histOrphans;
        totalCleaned += histOrphans;
    }

    // 4. Remove channels from disabled servers
    {
        QSqlQuery q(db);
        q.exec("DELETE FROM channels WHERE server_id IN (SELECT id FROM servers WHERE enabled = 0)");
        q.exec("SELECT changes()");
        int disabledCh = q.next() ? q.value(0).toInt() : 0;
        results["disabled_server_channels"] = disabledCh;
        totalCleaned += disabledCh;
    }

    // 5. Prune logo cache (older than 30 days or exceeding max size)
    if (logoCache_) {
        auto maxMb = settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("logo_cache_max_mb"), 500) : 500;
        logoCache_->pruneExpired(30, static_cast<qint64>(maxMb) * 1024 * 1024);
        results["logo_cache_pruned"] = true;
    }

    // 6. Clear series cache for disabled servers
    if (seriesCacheRepo_) {
        QSqlQuery q(db);
        q.exec("SELECT id FROM servers WHERE enabled = 0");
        while (q.next()) {
            seriesCacheRepo_->removeByServer(q.value(0).toLongLong());
        }
        results["series_cache_cleaned"] = true;
    }

    // 7. ANALYZE then VACUUM
    {
        QSqlQuery q(db);
        q.exec("ANALYZE");
        results["analyzed"] = true;
    }
    // VACUUM cannot run inside a transaction, run separately.
    {
        QSqlQuery q(db);
        if (q.exec("VACUUM")) {
            results["vacuumed"] = true;
        } else {
            results["vacuumed"] = false;
            qWarning() << "VACUUM failed:" << q.lastError().text();
        }
    }

    // Store last maintenance timestamp
    if (settingsRepo_) {
        settingsRepo_->set(QStringLiteral("last_maintenance"),
                           static_cast<int>(QDateTime::currentSecsSinceEpoch()));
    }

    results["total_cleaned"] = totalCleaned;
    qWarning() << "Maintenance completed:" << results;
    return results;
}
