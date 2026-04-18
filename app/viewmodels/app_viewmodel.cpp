#include "app_viewmodel.h"

AppViewModel::AppViewModel(QObject *parent)
    : QObject(parent),
      serverListVm_(new ServerListViewModel(this)),
      categoryListVm_(new CategoryListViewModel(this)),
      channelListVm_(new ChannelListViewModel(this)),
      playerVm_(new PlayerViewModel(this)),
      favoriteListVm_(new FavoriteListViewModel(this)) {}

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

    serverListVm_->setRepositories(serverRepo_.get(), categoryRepo_.get(),
                                   channelRepo_.get());
    favoriteListVm_->setRepository(favoriteRepo_.get());
    categoryListVm_->setRepository(categoryRepo_.get());
    channelListVm_->setRepository(channelRepo_.get());

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

QString AppViewModel::appName() const { return QStringLiteral("iptvxs"); }

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
