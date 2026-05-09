// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QTimer>

#include "iptvxs/gdrive/gdrive_auth.h"
#include "iptvxs/gdrive/gdrive_sync_io.h"
#include "iptvxs/security/credential_vault.h"

namespace iptvxs {

// Coordinates Google Drive cross-device sync of favorites/history/groups/
// servers. Uses snapshot.cpp for serialization + LWW merge and gdrive_sync_io
// for HTTP. Owns an hourly scheduler. Logs every step via qInfo so the
// in-app LogView surfaces the activity.
class SyncService : public QObject {
    Q_OBJECT

public:
    SyncService(QSqlDatabase db, GDriveAuth *auth, CredentialVault *vault,
                QObject *parent = nullptr);

    bool enabled() const;
    void setEnabled(bool on);

    QString folderName() const;
    void setFolderName(const QString &name);

    qint64 lastSyncedAt() const;
    QString lastStatus() const;
    bool inProgress() const;

    QString deviceUuid() const;

    // Manual trigger. No-op if a sync is already running. Triggers a hourly
    // tick refresh too.
    void syncNow();

    // Manual: copy SQLite file → encrypt → upload to GDrive folder.
    using BackupCallback = std::function<void(bool ok, const QString &message,
                                              const QString &fileId)>;
    void backupDatabase(const QString &dbPath, BackupCallback cb);

    // Tombstone GC — delete rows where deleted_at is older than `cutoffSecs`
    // unix epoch. Default is 30d.
    void garbageCollectTombstones(qint64 cutoffSecs);

signals:
    void enabledChanged();
    void folderNameChanged();
    void lastSyncedAtChanged();
    void lastStatusChanged();
    void inProgressChanged();
    void syncCompleted(bool ok, const QString &message);

private:
    void scheduleNext();
    void runCycle(bool manual);
    void resolveFolderThen(std::function<void(const QString &folderId)> next);
    QString readSyncState(const QString &key) const;
    void writeSyncState(const QString &key, const QString &value);

    QSqlDatabase db_;
    GDriveAuth *auth_;
    CredentialVault *vault_;
    GDriveSyncIO io_;
    QTimer hourlyTimer_;

    bool enabled_{false};
    QString folderName_{QStringLiteral("iptvXS-sync")};
    qint64 lastSyncedAt_{0};
    QString lastStatus_;
    bool inProgress_{false};
    QString deviceUuid_;

    static constexpr int kSyncFileSchemaVersion = 1;
    static constexpr const char *kSyncFileName = "iptvxs-sync.json.enc";
    static constexpr int kHourlyMs = 60 * 60 * 1000;
};

} // namespace iptvxs
