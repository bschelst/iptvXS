#include "app_viewmodel.h"
#include "log_viewmodel.h"

#include <QDateTime>
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
      speedTestVm_(new SpeedTestViewModel(this)),
      historyVm_(new HistoryViewModel(this)) {}

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
    historyRepo_ = std::make_unique<iptvxs::HistoryRepository>(db, this);
    historyVm_->setRepository(historyRepo_.get());
    recordingMgr_ = std::make_unique<iptvxs::RecordingManager>(this);
    httpClient_ = std::make_unique<iptvxs::HttpClient>(this);
    speedTestRunner_ = std::make_unique<iptvxs::SpeedTestRunner>(this);

    serverListVm_->setRepositories(serverRepo_.get(), categoryRepo_.get(),
                                   channelRepo_.get());
    favoriteListVm_->setRepository(favoriteRepo_.get());
    epgVm_->setRepositories(progRepo_.get(), channelRepo_.get(),
                            favoriteRepo_.get());
    connect(favoriteListVm_, &FavoriteListViewModel::favoriteToggled,
            epgVm_, [this](int64_t, bool) { epgVm_->refresh(); });
    epgVm_->setHttpClient(httpClient_.get());
    categoryListVm_->setRepository(categoryRepo_.get());
    channelListVm_->setRepository(channelRepo_.get());
    recordingMgr_->setRepositories(recordingRepo_.get(), channelRepo_.get(),
                                   settingsRepo_.get(), progRepo_.get());
    recordingListVm_->setRepositories(recordingRepo_.get(), channelRepo_.get());
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

    connect(serverListVm_, &ServerListViewModel::syncFinished, this,
            [this](int64_t) {
                if (!autoSyncInProgress_) return;
                ++autoSyncServerCursor_;
                if (autoSyncServerCursor_ < serverListVm_->count()) {
                    qInfo("Auto channel sync: next server (%d/%d)",
                          autoSyncServerCursor_ + 1, serverListVm_->count());
                    serverListVm_->syncServer(autoSyncServerCursor_);
                    return;
                }
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
            epgVm_->syncEpg(serverListVm_->epgUrlAt(next));
            return;
        }
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
            [](const QUrl &url) { QDesktopServices::openUrl(url); });

    speedTestVm_->setRunner(speedTestRunner_.get());
    speedTestVm_->setChannelRepository(channelRepo_.get());

    gdriveVm_->setAuth(gdriveAuth_.get());
    gdriveVm_->setUploader(gdriveUploader_.get());
    gdriveVm_->setRecordingRepository(recordingRepo_.get());
    gdriveVm_->setSettingsRepository(settingsRepo_.get());
    gdriveVm_->setDeleteLocalAfterUpload(recordingDestination() == QStringLiteral("gdrive"));
    gdriveVm_->resumePendingUploads();

    connect(serverListVm_, &ServerListViewModel::syncFinished, this,
            [this](int64_t serverId) {
                if (channelListVm_->serverId() == serverId) {
                    channelListVm_->refresh();
                }
                if (categoryListVm_->serverId() == serverId) {
                    categoryListVm_->refresh();
                }
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
            if (playerVm_->channelId() > 0) {
                historyRepo_->addEntry(playerVm_->channelId());
            } else if (!playerVm_->channelName().isEmpty()) {
                auto type = playerVm_->isLive() ? QStringLiteral("live") : QStringLiteral("vod");
                historyRepo_->addEntry(playerVm_->channelName(), playerVm_->channelLogo(),
                                        type, playerVm_->currentUrl());
            }
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

    databaseReady_ = true;
    emit databaseReadyChanged();

    rescheduleAutoSyncChannels();
    rescheduleAutoSyncEpg();

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

HistoryViewModel *AppViewModel::history() const { return historyVm_; }

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
    rescheduleAutoSyncChannels();
}

int AppViewModel::autoSyncEpgInterval() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("auto_sync_epg_hours"), 0) : 0;
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
    autoSyncServerCursor_ = 0;
    qInfo("Auto channel sync starting for %d server(s)", n);
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
    epgVm_->syncEpg(serverListVm_->epgUrlAt(autoSyncEpgCursor_));
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
        gdriveVm_->setDeleteLocalAfterUpload(normalized == QStringLiteral("gdrive"));
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

qint64 AppViewModel::maxRecordingSizeGb() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("max_recording_size_gb"), 0) : 0;
}

void AppViewModel::setMaxRecordingSizeGb(qint64 gb) {
    if (!settingsRepo_) return;
    settingsRepo_->set(QStringLiteral("max_recording_size_gb"), static_cast<int>(gb));
    emit maxRecordingSizeGbChanged();
}

int AppViewModel::gridColumns() const {
    return settingsRepo_ ? settingsRepo_->getInt(QStringLiteral("grid_columns"), 2) : 2;
}

void AppViewModel::setGridColumns(int cols) {
    if (!settingsRepo_) return;
    cols = qBound(1, cols, 4);
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
                                  QStringLiteral("lavfi=[hqdn3d=1.2:1.2:4:4]")});
    } else if (preset == QStringLiteral("strong")) {
        mpv->setProperty(QStringLiteral("deband"), QVariant(true));
        mpv->setProperty(QStringLiteral("deband-iterations"), QVariant(2));
        mpv->setProperty(QStringLiteral("deband-threshold"), QVariant(48));
        mpv->setProperty(QStringLiteral("deband-range"), QVariant(16));
        mpv->setProperty(QStringLiteral("scale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("cscale"), QVariant(QStringLiteral("ewa_lanczossharp")));
        mpv->setProperty(QStringLiteral("sigmoid-upscaling"), QVariant(true));
        mpv->command(QStringList{QStringLiteral("vf"), QStringLiteral("set"),
                                  QStringLiteral("lavfi=[hqdn3d=1.8:1.8:6:6]")});
    }

    emit videoEnhancementChanged();
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

void AppViewModel::playChannelById(int64_t channelId) {
    if (!channelRepo_ || channelId <= 0) return;
    auto ch = channelRepo_->findById(channelId);
    if (!ch) return;
    playerVm_->play(ch->streamUrl, ch->name, ch->logoUrl, ch->id);
    setCurrentView(QStringLiteral("player"));
}

void AppViewModel::playChannelByName(const QString &name) {
    if (!channelRepo_ || !serverRepo_ || name.isEmpty()) return;
    auto servers = serverRepo_->findAll();
    for (const auto &srv : servers) {
        auto results = channelRepo_->search(srv.id, name, 1, 0);
        if (!results.isEmpty()) {
            const auto &ch = results.first();
            playerVm_->play(ch.streamUrl, ch.name, ch.logoUrl, ch.id);
            setCurrentView(QStringLiteral("player"));
            return;
        }
    }
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
