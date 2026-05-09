// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QString>

#include "iptvxs/sync/sync_service.h"

class SyncViewModel : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString folderName READ folderName WRITE setFolderName NOTIFY folderNameChanged)
    Q_PROPERTY(QString backupFolderName READ backupFolderName WRITE setBackupFolderName NOTIFY backupFolderNameChanged)
    Q_PROPERTY(QString lastSyncedDisplay READ lastSyncedDisplay NOTIFY lastSyncedAtChanged)
    Q_PROPERTY(QString lastStatus READ lastStatus NOTIFY lastStatusChanged)
    Q_PROPERTY(bool inProgress READ inProgress NOTIFY inProgressChanged)
    Q_PROPERTY(bool backupInProgress READ backupInProgress NOTIFY backupInProgressChanged)
    Q_PROPERTY(QString backupStatus READ backupStatus NOTIFY backupStatusChanged)
    Q_PROPERTY(QString lastBackupDisplay READ lastBackupDisplay NOTIFY lastBackupChanged)

public:
    explicit SyncViewModel(QObject *parent = nullptr);

    void setService(iptvxs::SyncService *service, const QString &dbPath);

    bool enabled() const;
    void setEnabled(bool on);

    QString folderName() const;
    void setFolderName(const QString &name);

    QString backupFolderName() const;
    void setBackupFolderName(const QString &name);

    QString lastSyncedDisplay() const;
    QString lastStatus() const;
    bool inProgress() const;
    bool backupInProgress() const;
    QString backupStatus() const;
    QString lastBackupDisplay() const;

    Q_INVOKABLE void syncNow();
    Q_INVOKABLE void backupDatabase();

signals:
    void enabledChanged();
    void folderNameChanged();
    void backupFolderNameChanged();
    void lastSyncedAtChanged();
    void lastStatusChanged();
    void inProgressChanged();
    void backupInProgressChanged();
    void backupStatusChanged();
    void lastBackupChanged();
    void backupCompleted(bool ok, const QString &message);

private:
    iptvxs::SyncService *service_{nullptr};
    QString dbPath_;
    QString backupStatus_;
};
