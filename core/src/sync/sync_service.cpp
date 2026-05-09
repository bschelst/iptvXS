// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/sync/sync_service.h"

#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>

#include "iptvxs/sync/snapshot.h"

namespace iptvxs {

namespace {
constexpr const char *kKeyDeviceUuid = "device_uuid";
constexpr const char *kKeyLastSyncedAt = "last_synced_at";
constexpr const char *kKeyEnabled = "sync_enabled";
constexpr const char *kKeyFolderName = "sync_folder_name";
constexpr const char *kKeySyncFileId = "sync_file_id";

const QStringList kTombstoneTables = {
    QStringLiteral("favorites"), QStringLiteral("history"),
    QStringLiteral("channel_groups"), QStringLiteral("group_members"),
    QStringLiteral("servers")
};
} // namespace

SyncService::SyncService(QSqlDatabase db, GDriveAuth *auth, CredentialVault *vault,
                         QObject *parent)
    : QObject(parent), db_(std::move(db)), auth_(auth), vault_(vault), io_(auth, this) {
    deviceUuid_ = readSyncState(QLatin1String(kKeyDeviceUuid));
    if (deviceUuid_.isEmpty()) {
        deviceUuid_ = QUuid::createUuid().toString(QUuid::WithoutBraces);
        writeSyncState(QLatin1String(kKeyDeviceUuid), deviceUuid_);
    }
    enabled_ = readSyncState(QLatin1String(kKeyEnabled)) == QLatin1String("1");
    const auto storedFolder = readSyncState(QLatin1String(kKeyFolderName));
    if (!storedFolder.isEmpty()) folderName_ = storedFolder;
    lastSyncedAt_ = readSyncState(QLatin1String(kKeyLastSyncedAt)).toLongLong();

    hourlyTimer_.setInterval(kHourlyMs);
    hourlyTimer_.setSingleShot(false);
    connect(&hourlyTimer_, &QTimer::timeout, this, [this]() { runCycle(false); });
    if (enabled_) hourlyTimer_.start();
}

bool SyncService::enabled() const { return enabled_; }
QString SyncService::folderName() const { return folderName_; }
qint64 SyncService::lastSyncedAt() const { return lastSyncedAt_; }
QString SyncService::lastStatus() const { return lastStatus_; }
bool SyncService::inProgress() const { return inProgress_; }
QString SyncService::deviceUuid() const { return deviceUuid_; }

void SyncService::setEnabled(bool on) {
    if (enabled_ == on) return;
    enabled_ = on;
    writeSyncState(QLatin1String(kKeyEnabled), on ? QStringLiteral("1") : QStringLiteral("0"));
    if (on) {
        qInfo("[SYNC] enabled — scheduling hourly sync");
        hourlyTimer_.start();
        runCycle(false);
    } else {
        qInfo("[SYNC] disabled");
        hourlyTimer_.stop();
    }
    emit enabledChanged();
}

void SyncService::setFolderName(const QString &name) {
    const auto trimmed = name.trimmed();
    if (trimmed.isEmpty() || trimmed == folderName_) return;
    folderName_ = trimmed;
    writeSyncState(QLatin1String(kKeyFolderName), folderName_);
    writeSyncState(QLatin1String(kKeySyncFileId), {});
    emit folderNameChanged();
    qInfo("[SYNC] folder name changed to '%s'", qPrintable(folderName_));
}

void SyncService::syncNow() {
    if (!enabled_) {
        qInfo("[SYNC] manual sync ignored - sync is disabled");
        return;
    }
    if (inProgress_) {
        qInfo("[SYNC] manual sync ignored - already in progress");
        return;
    }
    runCycle(true);
}

void SyncService::resolveFolderThen(std::function<void(const QString &)> next) {
    io_.ensureFolder(folderName_, [this, next](const QString &folderId, const QString &err) {
        if (!err.isEmpty()) {
            qWarning("[SYNC] failed to resolve folder '%s': %s",
                     qPrintable(folderName_), qPrintable(err));
            lastStatus_ = QStringLiteral("Folder error: %1").arg(err);
            emit lastStatusChanged();
            inProgress_ = false;
            emit inProgressChanged();
            emit syncCompleted(false, lastStatus_);
            return;
        }
        next(folderId);
    });
}

void SyncService::runCycle(bool manual) {
    if (inProgress_) return;
    if (!auth_ || !auth_->isAuthenticated()) {
        qInfo("[SYNC] skipping - not authenticated with Google Drive");
        return;
    }
    inProgress_ = true;
    emit inProgressChanged();
    const auto startMs = QDateTime::currentMSecsSinceEpoch();
    qInfo("[SYNC] starting (%s)", manual ? "manual" : "scheduled");

    resolveFolderThen([this, startMs](const QString &folderId) {
        io_.findFile(folderId, QString::fromLatin1(kSyncFileName),
            [this, folderId, startMs](const QString &existingFileId, const QString &err) {
                if (!err.isEmpty()) {
                    qWarning("[SYNC] findFile failed: %s", qPrintable(err));
                }

                auto finishWithUpload = [this, folderId, existingFileId, startMs]() {
                    const auto outBytes = exportSnapshot(db_, vault_, deviceUuid_);
                    qInfo("[SYNC] uploading snapshot (%lld bytes)",
                          static_cast<long long>(outBytes.size()));
                    io_.uploadBytes(outBytes,
                                    QString::fromLatin1(kSyncFileName),
                                    QByteArrayLiteral("application/json"),
                                    folderId,
                                    existingFileId,
                                    [this, startMs](const QString &fileId, const QString &uerr) {
                                        if (!uerr.isEmpty()) {
                                            qWarning("[SYNC] upload failed: %s",
                                                     qPrintable(uerr));
                                            lastStatus_ = QStringLiteral("Upload failed: %1").arg(uerr);
                                            emit lastStatusChanged();
                                            inProgress_ = false;
                                            emit inProgressChanged();
                                            emit syncCompleted(false, lastStatus_);
                                            return;
                                        }
                                        if (!fileId.isEmpty()) {
                                            writeSyncState(QLatin1String(kKeySyncFileId), fileId);
                                        }
                                        const auto now = QDateTime::currentSecsSinceEpoch();
                                        lastSyncedAt_ = now;
                                        writeSyncState(QLatin1String(kKeyLastSyncedAt),
                                                       QString::number(now));
                                        const auto ms = QDateTime::currentMSecsSinceEpoch() - startMs;
                                        lastStatus_ = QStringLiteral("Synced in %1 ms").arg(ms);
                                        qInfo("[SYNC] complete in %lld ms",
                                              static_cast<long long>(ms));
                                        emit lastSyncedAtChanged();
                                        emit lastStatusChanged();
                                        inProgress_ = false;
                                        emit inProgressChanged();
                                        emit syncCompleted(true, lastStatus_);
                                    });
                };

                if (existingFileId.isEmpty()) {
                    qInfo("[SYNC] no existing remote snapshot - creating fresh");
                    finishWithUpload();
                    return;
                }

                io_.downloadFile(existingFileId,
                    [this, finishWithUpload](const QByteArray &data, const QString &derr) {
                        if (!derr.isEmpty()) {
                            qWarning("[SYNC] download failed: %s - proceeding with upload only",
                                     qPrintable(derr));
                        } else if (!data.isEmpty()) {
                            const auto stats = importSnapshot(db_, vault_, data);
                            qInfo("[SYNC] merged remote: favorites=%d history=%d "
                                  "groups=%d members=%d servers=%d tombstones=%d",
                                  stats.favoritesPulled, stats.historyPulled,
                                  stats.channelGroupsPulled, stats.groupMembersPulled,
                                  stats.serversPulled, stats.tombstonesApplied);
                        }
                        finishWithUpload();
                    });
            });
    });
}

void SyncService::backupDatabase(const QString &dbPath, BackupCallback cb) {
    if (!auth_ || !auth_->isAuthenticated()) {
        if (cb) cb(false, QStringLiteral("Not authenticated with Google Drive"), {});
        return;
    }
    QFile f(dbPath);
    if (!f.open(QIODevice::ReadOnly)) {
        if (cb) cb(false, QStringLiteral("Cannot read DB file: %1").arg(dbPath), {});
        return;
    }
    const auto bytes = f.readAll();
    f.close();
    qInfo("[SYNC] starting database backup (%lld bytes)",
          static_cast<long long>(bytes.size()));

    const auto stamp = QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss");
    const auto fileName = QStringLiteral("iptvXS-backup-%1.db").arg(stamp);

    resolveFolderThen([this, bytes, fileName, cb](const QString &folderId) {
        io_.uploadBytes(bytes, fileName,
                        QByteArrayLiteral("application/x-sqlite3"),
                        folderId, {},
                        [this, cb, fileName](const QString &fileId, const QString &err) {
                            if (!err.isEmpty()) {
                                qWarning("[SYNC] backup upload failed: %s",
                                         qPrintable(err));
                                if (cb) cb(false, err, {});
                                return;
                            }
                            qInfo("[SYNC] database backup '%s' uploaded - fileId=%s",
                                  qPrintable(fileName), qPrintable(fileId));
                            writeSyncState(QStringLiteral("last_backup_at"),
                                           QString::number(QDateTime::currentSecsSinceEpoch()));
                            writeSyncState(QStringLiteral("last_backup_file_id"), fileId);
                            if (cb) cb(true, fileName, fileId);
                        });
    });
}

void SyncService::garbageCollectTombstones(qint64 cutoffSecs) {
    int totalDeleted = 0;
    for (const auto &table : kTombstoneTables) {
        QSqlQuery q(db_);
        q.prepare(QStringLiteral("DELETE FROM %1 "
                                 "WHERE deleted_at IS NOT NULL AND deleted_at < ?")
                      .arg(table));
        q.addBindValue(static_cast<qlonglong>(cutoffSecs));
        if (q.exec()) totalDeleted += q.numRowsAffected();
    }
    if (totalDeleted > 0) {
        qInfo("[SYNC] tombstone GC: removed %d rows older than %lld",
              totalDeleted, static_cast<long long>(cutoffSecs));
    }
}

QString SyncService::readSyncState(const QString &key) const {
    QSqlQuery q(db_);
    q.prepare("SELECT value FROM sync_state WHERE key = ?");
    q.addBindValue(key);
    if (!q.exec() || !q.next()) return {};
    return q.value(0).toString();
}

void SyncService::writeSyncState(const QString &key, const QString &value) {
    QSqlQuery q(db_);
    q.prepare("INSERT INTO sync_state (key, value) VALUES (?, ?) "
              "ON CONFLICT(key) DO UPDATE SET value = excluded.value");
    q.addBindValue(key);
    q.addBindValue(value);
    if (!q.exec()) {
        qWarning("[SYNC] writeSyncState(%s) failed: %s",
                 qPrintable(key), qPrintable(q.lastError().text()));
    }
}

} // namespace iptvxs
