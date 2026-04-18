#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>

#include "iptvxs/db/database.h"
#include "iptvxs/db/category_repository.h"
#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/favorite_repository.h"
#include "iptvxs/db/programme_repository.h"
#include "iptvxs/db/recording_repository.h"
#include "iptvxs/db/server_repository.h"
#include "iptvxs/db/settings_repository.h"
#include "iptvxs/recording/recording_manager.h"
#include "iptvxs/gdrive/gdrive_auth.h"
#include "iptvxs/gdrive/gdrive_uploader.h"

#include "category_list_viewmodel.h"
#include "epg_viewmodel.h"
#include "channel_list_viewmodel.h"
#include "favorite_list_viewmodel.h"
#include "player_viewmodel.h"
#include "gdrive_viewmodel.h"
#include "recording_list_viewmodel.h"
#include "server_list_viewmodel.h"

class AppViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(bool databaseReady READ databaseReady NOTIFY databaseReadyChanged)
    Q_PROPERTY(QString currentView READ currentView WRITE setCurrentView NOTIFY currentViewChanged)
    Q_PROPERTY(ServerListViewModel *serverList READ serverList CONSTANT)
    Q_PROPERTY(CategoryListViewModel *categoryList READ categoryList CONSTANT)
    Q_PROPERTY(ChannelListViewModel *channelList READ channelList CONSTANT)
    Q_PROPERTY(PlayerViewModel *player READ player CONSTANT)
    Q_PROPERTY(FavoriteListViewModel *favoriteList READ favoriteList CONSTANT)
    Q_PROPERTY(EpgViewModel *epg READ epg CONSTANT)
    Q_PROPERTY(RecordingListViewModel *recordingList READ recordingList CONSTANT)
    Q_PROPERTY(GDriveViewModel *gdrive READ gdrive CONSTANT)

public:
    explicit AppViewModel(QObject *parent = nullptr);
    ~AppViewModel() override;

    bool initialize(const QString &dbPath);

    QString appName() const;
    QString appVersion() const;
    bool databaseReady() const;
    QString currentView() const;
    void setCurrentView(const QString &view);

    iptvxs::Database *database() const;
    iptvxs::SettingsRepository *settings() const;
    ServerListViewModel *serverList() const;
    CategoryListViewModel *categoryList() const;
    ChannelListViewModel *channelList() const;
    PlayerViewModel *player() const;
    FavoriteListViewModel *favoriteList() const;
    EpgViewModel *epg() const;
    RecordingListViewModel *recordingList() const;
    GDriveViewModel *gdrive() const;

signals:
    void databaseReadyChanged();
    void currentViewChanged();
    void errorOccurred(const QString &message);

private:
    std::unique_ptr<iptvxs::Database> database_;
    std::unique_ptr<iptvxs::SettingsRepository> settingsRepo_;
    std::unique_ptr<iptvxs::ServerRepository> serverRepo_;
    std::unique_ptr<iptvxs::CategoryRepository> categoryRepo_;
    std::unique_ptr<iptvxs::ChannelRepository> channelRepo_;
    std::unique_ptr<iptvxs::FavoriteRepository> favoriteRepo_;
    std::unique_ptr<iptvxs::ProgrammeRepository> progRepo_;
    std::unique_ptr<iptvxs::RecordingRepository> recordingRepo_;
    std::unique_ptr<iptvxs::RecordingManager> recordingMgr_;
    std::unique_ptr<iptvxs::GDriveAuth> gdriveAuth_;
    std::unique_ptr<iptvxs::GDriveUploader> gdriveUploader_;
    std::unique_ptr<iptvxs::HttpClient> httpClient_;

    ServerListViewModel *serverListVm_;
    CategoryListViewModel *categoryListVm_;
    ChannelListViewModel *channelListVm_;
    PlayerViewModel *playerVm_;
    FavoriteListViewModel *favoriteListVm_;
    EpgViewModel *epgVm_;
    RecordingListViewModel *recordingListVm_;
    GDriveViewModel *gdriveVm_;

    bool databaseReady_{false};
    QString currentView_{"home"};
};
