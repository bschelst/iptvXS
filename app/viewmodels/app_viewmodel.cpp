#include "app_viewmodel.h"

AppViewModel::AppViewModel(QObject *parent) : QObject(parent) {}

AppViewModel::~AppViewModel() = default;

bool AppViewModel::initialize(const QString &dbPath) {
    database_ = std::make_unique<iptvxs::Database>(this);

    connect(database_.get(), &iptvxs::Database::errorOccurred, this, &AppViewModel::errorOccurred);

    if (!database_->open(dbPath)) {
        return false;
    }

    settings_ = std::make_unique<iptvxs::SettingsRepository>(database_->connection(), this);
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

iptvxs::SettingsRepository *AppViewModel::settings() const { return settings_.get(); }

