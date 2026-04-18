#include "app_viewmodel.h"
#include "log_viewmodel.h"

#include <QDesktopServices>
#include <QDir>
#include <QFile>
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
                                   settingsRepo_.get());
    recordingListVm_->setRepositories(recordingRepo_.get(), channelRepo_.get());
    recordingListVm_->setRecordingManager(recordingMgr_.get());
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
        currentView_ = view;
        emit currentViewChanged();
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
