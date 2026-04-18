#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>

#include "iptvxs/db/database.h"
#include "iptvxs/db/settings_repository.h"

class AppViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString appName READ appName CONSTANT)
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    Q_PROPERTY(bool databaseReady READ databaseReady NOTIFY databaseReadyChanged)
    Q_PROPERTY(QString currentView READ currentView WRITE setCurrentView NOTIFY currentViewChanged)

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

signals:
    void databaseReadyChanged();
    void currentViewChanged();
    void errorOccurred(const QString &message);

private:
    std::unique_ptr<iptvxs::Database> database_;
    std::unique_ptr<iptvxs::SettingsRepository> settings_;
    bool databaseReady_{false};
    QString currentView_{"home"};
};

