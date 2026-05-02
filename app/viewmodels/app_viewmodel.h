// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <atomic>
#include <memory>
#include <QJsonObject>
#include <QMetaObject>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QTimer>

#include "iptvxs/db/database.h"
#include "iptvxs/db/category_repository.h"
#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/epg_source_repository.h"
#include "iptvxs/db/favorite_repository.h"
#include "iptvxs/db/programme_repository.h"
#include "iptvxs/db/recording_repository.h"
#include "iptvxs/db/server_repository.h"
#include "iptvxs/db/settings_repository.h"
#include "iptvxs/recording/recording_manager.h"
#include "iptvxs/db/history_repository.h"
#include "iptvxs/api/opensubtitles_client.h"
#include "iptvxs/api/xtream_client.h"
#include "iptvxs/gdrive/gdrive_auth.h"
#include "iptvxs/gdrive/gdrive_uploader.h"
#include "iptvxs/net/speed_test_runner.h"
#include "iptvxs/db/category_settings_repository.h"
#include "iptvxs/db/channel_group_repository.h"
#include "iptvxs/db/series_cache_repository.h"
#include "iptvxs/cache/logo_cache.h"
#include "iptvxs/cast/chromecast_manager.h"

#include "category_list_viewmodel.h"
#include "epg_source_list_viewmodel.h"
#include "group_list_viewmodel.h"
#include "epg_viewmodel.h"
#include "channel_list_viewmodel.h"
#include "favorite_list_viewmodel.h"
#include "player_viewmodel.h"
#include "gdrive_viewmodel.h"
#include "recording_list_viewmodel.h"
#include "server_list_viewmodel.h"
#include "speed_test_viewmodel.h"
#include "history_viewmodel.h"
#include "log_viewmodel.h"

class AppViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(bool databaseReady READ databaseReady NOTIFY databaseReadyChanged)
    Q_PROPERTY(QString currentView READ currentView WRITE setCurrentView NOTIFY currentViewChanged)
    Q_PROPERTY(bool videoFullscreen READ videoFullscreen WRITE setVideoFullscreen NOTIFY videoFullscreenChanged)
    Q_PROPERTY(QString pendingPlayUrl MEMBER pendingPlayUrl_ NOTIFY pendingPlayChanged)
    Q_PROPERTY(QString pendingPlayName MEMBER pendingPlayName_ NOTIFY pendingPlayChanged)
    Q_PROPERTY(ServerListViewModel *serverList READ serverList CONSTANT)
    Q_PROPERTY(CategoryListViewModel *categoryList READ categoryList CONSTANT)
    Q_PROPERTY(EpgSourceListViewModel *epgSourceList READ epgSourceList CONSTANT)
    Q_PROPERTY(ChannelListViewModel *channelList READ channelList CONSTANT)
    Q_PROPERTY(PlayerViewModel *player READ player CONSTANT)
    Q_PROPERTY(FavoriteListViewModel *favoriteList READ favoriteList CONSTANT)
    Q_PROPERTY(EpgViewModel *epg READ epg CONSTANT)
    Q_PROPERTY(RecordingListViewModel *recordingList READ recordingList CONSTANT)
    Q_PROPERTY(GDriveViewModel *gdrive READ gdrive CONSTANT)
    Q_PROPERTY(SpeedTestViewModel *speedTest READ speedTest CONSTANT)
    Q_PROPERTY(HistoryViewModel *history READ history CONSTANT)
    Q_PROPERTY(LogViewModel *log READ log CONSTANT)
    Q_PROPERTY(int autoSyncInterval READ autoSyncInterval WRITE setAutoSyncInterval NOTIFY autoSyncIntervalChanged)
    Q_PROPERTY(int autoSyncEpgInterval READ autoSyncEpgInterval WRITE setAutoSyncEpgInterval NOTIFY autoSyncEpgIntervalChanged)
    Q_PROPERTY(QString databasePath READ databasePath CONSTANT)
    Q_PROPERTY(QString databaseSize READ databaseSize NOTIFY databaseReadyChanged)
    Q_PROPERTY(QString recordingDirectory READ recordingDirectory WRITE setRecordingDirectory NOTIFY recordingDirectoryChanged)
    Q_PROPERTY(QString recordingDestination READ recordingDestination WRITE setRecordingDestination NOTIFY recordingDestinationChanged)
    Q_PROPERTY(int bufferSeconds READ bufferSeconds WRITE setBufferSeconds NOTIFY bufferSecondsChanged)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(QString subtitleLanguage READ subtitleLanguage WRITE setSubtitleLanguage NOTIFY subtitleLanguageChanged)
    Q_PROPERTY(QString subtitleLanguageSecondary READ subtitleLanguageSecondary WRITE setSubtitleLanguageSecondary NOTIFY subtitleLanguageSecondaryChanged)
    Q_PROPERTY(bool subtitlesEnabled READ subtitlesEnabled WRITE setSubtitlesEnabled NOTIFY subtitlesEnabledChanged)
    Q_PROPERTY(int subtitleSize READ subtitleSize WRITE setSubtitleSize NOTIFY subtitleSizeChanged)
    Q_PROPERTY(QString subtitleColor READ subtitleColor WRITE setSubtitleColor NOTIFY subtitleColorChanged)
    Q_PROPERTY(QString subtitleBgColor READ subtitleBgColor WRITE setSubtitleBgColor NOTIFY subtitleBgColorChanged)
    Q_PROPERTY(qint64 maxRecordingSizeGb READ maxRecordingSizeGb WRITE setMaxRecordingSizeGb NOTIFY maxRecordingSizeGbChanged)
    Q_PROPERTY(int epgRecordingLeadTime READ epgRecordingLeadTime WRITE setEpgRecordingLeadTime NOTIFY epgRecordingLeadTimeChanged)
    Q_PROPERTY(int epgRecordingOverrun READ epgRecordingOverrun WRITE setEpgRecordingOverrun NOTIFY epgRecordingOverrunChanged)
    Q_PROPERTY(int gridColumns READ gridColumns WRITE setGridColumns NOTIFY gridColumnsChanged)
    Q_PROPERTY(bool closeToTray READ closeToTray WRITE setCloseToTray NOTIFY closeToTrayChanged)
    Q_PROPERTY(QString videoEnhancement READ videoEnhancement WRITE setVideoEnhancement NOTIFY videoEnhancementChanged)
    Q_PROPERTY(QString hwdecMode READ hwdecMode WRITE setHwdecMode NOTIFY hwdecModeChanged)
    Q_PROPERTY(bool deinterlace READ deinterlace WRITE setDeinterlace NOTIFY deinterlaceChanged)
    Q_PROPERTY(bool keepLocalCopy READ keepLocalCopy WRITE setKeepLocalCopy NOTIFY keepLocalCopyChanged)
    Q_PROPERTY(GroupListViewModel *groupList READ groupList CONSTANT)
    Q_PROPERTY(iptvxs::LogoCache *logoCache READ logoCache CONSTANT)
    Q_PROPERTY(int logoCacheMaxMb READ logoCacheMaxMb WRITE setLogoCacheMaxMb NOTIFY logoCacheMaxMbChanged)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY latestVersionChanged)
    Q_PROPERTY(iptvxs::ChromecastManager *chromecast READ chromecast CONSTANT)
    Q_PROPERTY(bool chromecastEnabled READ chromecastEnabled WRITE setChromecastEnabled NOTIFY chromecastEnabledChanged)

public:
    explicit AppViewModel(QObject *parent = nullptr);
    ~AppViewModel() override;

    bool initialize(const QString &dbPath);
    void setLogViewModel(LogViewModel *logVm);

    QString appName() const;
    QString appVersion() const;
    bool databaseReady() const;
    QString currentView() const;
    void setCurrentView(const QString &view);
    Q_INVOKABLE QString previousView() const;

    iptvxs::Database *database() const;
    iptvxs::SettingsRepository *settings() const;
    ServerListViewModel *serverList() const;
    CategoryListViewModel *categoryList() const;
    EpgSourceListViewModel *epgSourceList() const;
    ChannelListViewModel *channelList() const;
    PlayerViewModel *player() const;
    FavoriteListViewModel *favoriteList() const;
    EpgViewModel *epg() const;
    RecordingListViewModel *recordingList() const;
    GDriveViewModel *gdrive() const;
    SpeedTestViewModel *speedTest() const;
    HistoryViewModel *history() const;
    LogViewModel *log() const;
    GroupListViewModel *groupList() const;
    iptvxs::LogoCache *logoCache() const;
    iptvxs::ChromecastManager *chromecast() const;
    bool chromecastEnabled() const;
    void setChromecastEnabled(bool enabled);
    int logoCacheMaxMb() const;
    void setLogoCacheMaxMb(int mb);

    int autoSyncInterval() const;
    void setAutoSyncInterval(int hours);
    int autoSyncEpgInterval() const;
    void setAutoSyncEpgInterval(int hours);

    QString databasePath() const;
    QString databaseSize() const;
    QString recordingDirectory() const;
    QString recordingDestination() const;
    void setRecordingDestination(const QString &dest);
    void setRecordingDirectory(const QString &path);

    int bufferSeconds() const;
    void setBufferSeconds(int seconds);

    QString theme() const;
    void setTheme(const QString &name);
    QString subtitleLanguage() const;
    void setSubtitleLanguage(const QString &lang);
    QString subtitleLanguageSecondary() const;
    void setSubtitleLanguageSecondary(const QString &lang);
    bool subtitlesEnabled() const;
    void setSubtitlesEnabled(bool enabled);
    int subtitleSize() const;
    void setSubtitleSize(int size);
    QString subtitleColor() const;
    void setSubtitleColor(const QString &color);
    QString subtitleBgColor() const;
    void setSubtitleBgColor(const QString &color);

    qint64 maxRecordingSizeGb() const;
    void setMaxRecordingSizeGb(qint64 gb);
    int epgRecordingLeadTime() const;
    void setEpgRecordingLeadTime(int minutes);
    int epgRecordingOverrun() const;
    void setEpgRecordingOverrun(int minutes);
    int gridColumns() const;
    void setGridColumns(int cols);
    bool closeToTray() const;
    void setCloseToTray(bool enabled);
    QString videoEnhancement() const;
    void setVideoEnhancement(const QString &preset);
    QString hwdecMode() const;
    void setHwdecMode(const QString &mode);
    bool deinterlace() const;
    void setDeinterlace(bool enabled);
    bool keepLocalCopy() const;
    void setKeepLocalCopy(bool keep);

    QString latestVersion() const;
    bool updateAvailable() const;
    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void openGitHub();

    Q_INVOKABLE bool fileExists(const QString &path) const;
    Q_INVOKABLE void resetDatabase();
    Q_INVOKABLE void searchSubtitles(const QString &query);
    Q_INVOKABLE void loadSubtitleResult(int index);
    Q_INVOKABLE void fetchSeriesEpisodes(int64_t serverId, const QString &seriesId,
                                          const QString &seriesName, const QString &logoUrl);
    Q_INVOKABLE QVariantMap channelInfo(int64_t channelId) const;
    Q_INVOKABLE void playChannelById(int64_t channelId, int startPositionSecs = 0);
    Q_INVOKABLE void playHistoryEntry(int64_t historyId);
    Q_INVOKABLE void playChannelByName(const QString &name);
    Q_INVOKABLE void playSeriesEpisode(const QString &episodeId, const QString &ext,
                                        const QString &title, const QString &logoUrl,
                                        int64_t channelId = 0);
    Q_INVOKABLE void playRecordingFromDrive(int64_t recordingId);
    Q_INVOKABLE bool isCategoryHidden(int64_t categoryId) const;
    Q_INVOKABLE void setActiveSeriesDialog(const QString &name, int64_t serverId, const QString &seriesId, const QString &logoUrl);
    Q_INVOKABLE void clearActiveSeriesDialog();
    Q_INVOKABLE void reopenSeriesEpisodes();
    Q_INVOKABLE bool hasActiveSeriesDialog() const;
    Q_INVOKABLE QString activeSeriesName() const;
    Q_INVOKABLE int64_t activeSeriesServerId() const;
    Q_INVOKABLE QString activeSeriesId() const;
    Q_INVOKABLE QString activeSeriesLogo() const;
    Q_INVOKABLE bool hasWatched(int64_t channelId) const;
    Q_INVOKABLE bool hasWatchedUrl(const QString &url) const;
    Q_INVOKABLE QString buildSeriesEpisodeUrl(const QString &episodeId, const QString &ext) const;
    Q_INVOKABLE QString currentProgrammeTitle(const QString &epgChannelId) const;
    Q_INVOKABLE QString nextProgrammeTitle(const QString &epgChannelId) const;
    Q_INVOKABLE QString nextProgrammeTime(const QString &epgChannelId) const;
    Q_INVOKABLE QVariantMap databaseStats() const;
    Q_INVOKABLE QVariantMap runMaintenance();
    Q_INVOKABLE void validateServerInput(const QString &type, const QString &url,
                                         const QString &username, const QString &password);
    Q_INVOKABLE void validateEpgSourceInput(const QString &url);

signals:
    void databaseReadyChanged();
    void currentViewChanged();
    void videoFullscreenChanged();
    void pendingPlayChanged();
    void autoSyncIntervalChanged();
    void autoSyncEpgIntervalChanged();
    void recordingDirectoryChanged();
    void recordingDestinationChanged();
    void bufferSecondsChanged();
    void themeChanged();
    void subtitleLanguageChanged();
    void subtitleLanguageSecondaryChanged();
    void subtitlesEnabledChanged();
    void subtitleSizeChanged();
    void subtitleColorChanged();
    void subtitleBgColorChanged();
    void maxRecordingSizeGbChanged();
    void epgRecordingLeadTimeChanged();
    void epgRecordingOverrunChanged();
    void gridColumnsChanged();
    void closeToTrayChanged();
    void videoEnhancementChanged();
    void hwdecModeChanged();
    void deinterlaceChanged();
    void keepLocalCopyChanged();
    void errorOccurred(const QString &message);
    void subtitlesFound(int count);
    void subtitleLoaded(const QString &filePath);
    void seriesEpisodesReady(const QString &seriesName, const QVariantList &seasons);
    void latestVersionChanged();
    void logoCacheMaxMbChanged();
    void chromecastEnabledChanged();
    void showAuthHint(const QString &url);
    void urlValidationFinished(const QString &context, bool ok, const QString &message);

public slots:
    void openAuthUrlInSteamBrowser(const QString &url);

private:
    void ensureDefaultServers();
    void bootstrapDefaultFreeServerSync();

    std::unique_ptr<iptvxs::Database> database_;
    std::unique_ptr<iptvxs::SettingsRepository> settingsRepo_;
    std::unique_ptr<iptvxs::ServerRepository> serverRepo_;
    std::unique_ptr<iptvxs::CategoryRepository> categoryRepo_;
    std::unique_ptr<iptvxs::ChannelRepository> channelRepo_;
    std::unique_ptr<iptvxs::EpgSourceRepository> epgSourceRepo_;
    std::unique_ptr<iptvxs::FavoriteRepository> favoriteRepo_;
    std::unique_ptr<iptvxs::ProgrammeRepository> progRepo_;
    std::unique_ptr<iptvxs::RecordingRepository> recordingRepo_;
    std::unique_ptr<iptvxs::RecordingManager> recordingMgr_;
    std::unique_ptr<iptvxs::GDriveAuth> gdriveAuth_;
    std::unique_ptr<iptvxs::GDriveUploader> gdriveUploader_;
    QMetaObject::Connection gdrivePlaybackCleanupConnection_;
    std::unique_ptr<iptvxs::HttpClient> httpClient_;
    std::unique_ptr<iptvxs::SpeedTestRunner> speedTestRunner_;

    ServerListViewModel *serverListVm_;
    CategoryListViewModel *categoryListVm_;
    EpgSourceListViewModel *epgSourceListVm_;
    ChannelListViewModel *channelListVm_;
    PlayerViewModel *playerVm_;
    FavoriteListViewModel *favoriteListVm_;
    EpgViewModel *epgVm_;
    RecordingListViewModel *recordingListVm_;
    GDriveViewModel *gdriveVm_;
    SpeedTestViewModel *speedTestVm_;
    HistoryViewModel *historyVm_;
    GroupListViewModel *groupListVm_;
    LogViewModel *logVm_{nullptr};

    bool databaseReady_{false};
    QString currentView_{"home"};
    QString previousView_{"home"};

    QTimer *autoSyncTimer_{nullptr};
    QTimer *autoSyncEpgTimer_{nullptr};
    QTimer *autoSyncWatchdog_{nullptr};
    QTimer *autoSyncEpgWatchdog_{nullptr};
    QTimer *historyFlushTimer_{nullptr};
    int autoSyncServerCursor_{0};
    int autoSyncEpgCursor_{0};
    bool autoSyncInProgress_{false};
    bool autoSyncEpgInProgress_{false};
    bool defaultFreeServerBootstrapPending_{false};
    bool defaultFreeServerBootstrapEpgPending_{false};
    int64_t lastHistoryEntryId_{0};
    bool resumeHistoryPending_{false};

    static QVariantList parseSeriesEpisodes(const QJsonObject &info,
                                              const QString &seriesName,
                                              const QString &logoUrl);
    QVariantMap resolveSeriesResumePlan(const iptvxs::HistoryEntry &entry) const;
    bool restoreSeriesAutoNextFromHistory(const iptvxs::HistoryEntry &entry);
    void startHistoryFlushTimer();
    void stopHistoryFlushTimer();
    void persistCurrentHistoryPosition();
    void prefetchSeriesCache(int64_t serverId);
    void prefetchNextSeries(std::shared_ptr<struct SeriesPrefetchState> state);
    void rescheduleAutoSyncChannels();
    void rescheduleAutoSyncEpg();
    void advanceAutoSyncToNextEnabled();
    void runAutoSyncChannels();
    void runAutoSyncEpg();
    bool videoFullscreen_{false};
    QString pendingPlayUrl_;
    QString pendingPlayName_;
    std::unique_ptr<iptvxs::CategorySettingsRepository> categorySettingsRepo_;
    std::unique_ptr<iptvxs::HistoryRepository> historyRepo_;
    std::unique_ptr<iptvxs::ChannelGroupRepository> groupRepo_;
    std::unique_ptr<iptvxs::LogoCache> logoCache_;
    iptvxs::ChromecastManager *chromecastMgr_;
    std::unique_ptr<iptvxs::SeriesCacheRepository> seriesCacheRepo_;
    std::unique_ptr<iptvxs::OpenSubtitlesClient> subtitlesClient_;
    QVector<iptvxs::SubtitleResult> lastSubResults_;
    QString seriesServerUrl_;
    QString latestVersion_;
    QString seriesUsername_;
    QString seriesPassword_;
    QString activeSeriesName_;
    int64_t activeSeriesServerId_{0};
    QString activeSeriesId_;
    QString activeSeriesLogo_;

public:
    bool videoFullscreen() const;
    void setVideoFullscreen(bool fs);
};
