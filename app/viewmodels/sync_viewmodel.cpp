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
    connect(service_, &iptvxs::SyncService::lastSyncedAtChanged,
            this, &SyncViewModel::lastSyncedAtChanged);
    connect(service_, &iptvxs::SyncService::lastStatusChanged,
            this, &SyncViewModel::lastStatusChanged);
    connect(service_, &iptvxs::SyncService::inProgressChanged,
            this, &SyncViewModel::inProgressChanged);
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

QString SyncViewModel::lastBackupDisplay() const {
    if (lastBackupAt_ <= 0) return tr("Never");
    return QDateTime::fromSecsSinceEpoch(lastBackupAt_)
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
    service_->backupDatabase(dbPath_, [this](bool ok, const QString &msg, const QString &) {
        if (ok) {
            lastBackupAt_ = QDateTime::currentSecsSinceEpoch();
            emit lastBackupChanged();
        }
        emit backupCompleted(ok, msg);
    });
}
