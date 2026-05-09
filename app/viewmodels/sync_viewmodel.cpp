// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "sync_viewmodel.h"

#include <QDateTime>

SyncViewModel::SyncViewModel(QObject *parent)
    : QObject(parent) {}

void SyncViewModel::setService(iptvxs::SyncService *service, const QString &dbPath) {
    service_ = service;
    dbPath_ = dbPath;
    if (!service_) return;
    connect(service_, &iptvxs::SyncService::enabledChanged,
            this, &SyncViewModel::enabledChanged);
    connect(service_, &iptvxs::SyncService::folderNameChanged,
            this, &SyncViewModel::folderNameChanged);
    connect(service_, &iptvxs::SyncService::backupFolderNameChanged,
            this, &SyncViewModel::backupFolderNameChanged);
    connect(service_, &iptvxs::SyncService::lastSyncedAtChanged,
            this, &SyncViewModel::lastSyncedAtChanged);
    connect(service_, &iptvxs::SyncService::lastBackupAtChanged,
            this, &SyncViewModel::lastBackupChanged);
    connect(service_, &iptvxs::SyncService::lastStatusChanged,
            this, &SyncViewModel::lastStatusChanged);
    connect(service_, &iptvxs::SyncService::inProgressChanged,
            this, &SyncViewModel::inProgressChanged);
    connect(service_, &iptvxs::SyncService::backupInProgressChanged,
            this, [this]() {
                if (service_ && service_->backupInProgress()) {
                    backupStatus_ = tr("Uploading…");
                    emit backupStatusChanged();
                }
                emit backupInProgressChanged();
            });
    connect(service_, &iptvxs::SyncService::backupCompleted,
            this, [this](bool ok, const QString &message) {
                backupStatus_ = ok ? tr("Backup uploaded")
                                   : tr("Backup failed: %1").arg(message);
                emit backupStatusChanged();
                emit backupCompleted(ok, message);
            });
}

bool SyncViewModel::enabled() const {
    return service_ ? service_->enabled() : false;
}

void SyncViewModel::setEnabled(bool on) {
    if (service_) service_->setEnabled(on);
}

QString SyncViewModel::folderName() const {
    return service_ ? service_->folderName() : QString();
}

void SyncViewModel::setFolderName(const QString &name) {
    if (service_) service_->setFolderName(name);
}

QString SyncViewModel::backupFolderName() const {
    return service_ ? service_->backupFolderName() : QString();
}

void SyncViewModel::setBackupFolderName(const QString &name) {
    if (service_) service_->setBackupFolderName(name);
}

QString SyncViewModel::lastSyncedDisplay() const {
    if (!service_) return tr("Never");
    const auto ts = service_->lastSyncedAt();
    if (ts <= 0) return tr("Never");
    return QDateTime::fromSecsSinceEpoch(ts).toString(QStringLiteral("yyyy-MM-dd HH:mm"));
}

QString SyncViewModel::lastStatus() const {
    return service_ ? service_->lastStatus() : QString();
}

bool SyncViewModel::inProgress() const {
    return service_ ? service_->inProgress() : false;
}

bool SyncViewModel::backupInProgress() const {
    return service_ ? service_->backupInProgress() : false;
}

QString SyncViewModel::backupStatus() const { return backupStatus_; }

QString SyncViewModel::lastBackupDisplay() const {
    const auto ts = service_ ? service_->lastBackupAt() : 0;
    if (ts <= 0) return tr("Never");
    return QDateTime::fromSecsSinceEpoch(ts)
        .toString(QStringLiteral("yyyy-MM-dd HH:mm"));
}

void SyncViewModel::syncNow() {
    if (service_) service_->syncNow();
}

void SyncViewModel::backupDatabase() {
    if (!service_ || dbPath_.isEmpty()) {
        emit backupCompleted(false, tr("Database path not set"));
        return;
    }
    // SyncService now drives lastBackupAt + backupCompleted signals itself,
    // so this lambda is just a no-op forwarder for the legacy callback API.
    service_->backupDatabase(dbPath_,
                             [](bool, const QString &, const QString &) {});
}
