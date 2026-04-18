#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>

#include "iptvxs/db/database.h"
#include "iptvxs/db/category_repository.h"
#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/favorite_repository.h"
#include "iptvxs/db/server_repository.h"
#include "iptvxs/db/settings_repository.h"

#include "category_list_viewmodel.h"
#include "channel_list_viewmodel.h"
#include "favorite_list_viewmodel.h"
#include "player_viewmodel.h"
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

    ServerListViewModel *serverListVm_;
    CategoryListViewModel *categoryListVm_;
    ChannelListViewModel *channelListVm_;
    PlayerViewModel *playerVm_;
    FavoriteListViewModel *favoriteListVm_;

    bool databaseReady_{false};
    QString currentView_{"home"};
};
