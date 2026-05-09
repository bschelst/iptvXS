// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#include "iptvxs/sync/sync_service.h"

#include <QByteArray>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUuid>

#include "iptvxs/sync/snapshot.h"

namespace iptvxs {

namespace {
constexpr const char *kKeyDeviceUuid = "device_uuid";
constexpr const char *kKeyLastSyncedAt = "last_synced_at";
constexpr const char *kKeyLastBackupAt = "last_backup_at";
constexpr const char *kKeyEnabled = "sync_enabled";
constexpr const char *kKeyFolderName = "sync_folder_name";
constexpr const char *kKeyBackupFolderName = "backup_folder_name";
constexpr const char *kKeySyncFileId = "sync_file_id";

const QStringList kTombstoneTables = {
    QStringLiteral("favorites"), QStringLiteral("history"),
    QStringLiteral("channel_groups"), QStringLiteral("group_members"),
    QStringLiteral("servers")
};

// Migrate legacy flat folder names to nested paths under iptvXS/.
QString migrateLegacyFolderName(const QString &stored, const QString &nestedDefault) {
    static const QHash<QString, QString> kLegacy = {
        {QStringLiteral("iptvXS-sync"),    QStringLiteral("iptvXS/sync")},
        {QStringLiteral("iptvxs-sync"),    QStringLiteral("iptvXS/sync")},
        {QStringLiteral("iptvXS-backup"),  QStringLiteral("iptvXS/backup")},
        {QStringLiteral("iptvxs-backup"),  QStringLiteral("iptvXS/backup")},
    };
    if (stored.isEmpty()) return nestedDefault;
    const auto it = kLegacy.find(stored);
    if (it != kLegacy.end()) return it.value();
    return stored;
}
} // namespace

SyncService::SyncService(QSqlDatabase db, GDriveAuth *auth, CredentialVault *vault,
                         GDriveUploader *uploader, QObject *parent)
    : QObject(parent), db_(std::move(db)), auth_(auth), vault_(vault),
      uploader_(uploader), io_(auth, this) {
    if (uploader_) {
        // Route resumable-upload completion/failure back to whichever pending
        // BackupCallback corresponds to that synthetic recordingId.
        connect(uploader_, &GDriveUploader::uploadCompleted, this,
                [this](int64_t recordingId, const QString &fileId) {
                    if (!pendingBackups_.contains(recordingId)) return;
                    auto cb = pendingBackups_.take(recordingId);
                    qInfo("[SYNC] backup complete via resumable upload: id=%lld file=%s",
                          static_cast<long long>(recordingId), qPrintable(fileId));
                    const auto now = QDateTime::currentSecsSinceEpoch();
                    writeSyncState(QLatin1String(kKeyLastBackupAt),
                                   QString::number(now));
                    writeSyncState(QStringLiteral("last_backup_file_id"), fileId);
                    lastBackupAt_ = now;
                    emit lastBackupAtChanged();
                    if (pendingBackupTempFiles_.contains(recordingId)) {
                        QFile::remove(pendingBackupTempFiles_.take(recordingId));
                    }
                    setBackupInProgress(false);
                    const auto msg = QStringLiteral("Backup uploaded");
                    if (cb) cb(true, msg, fileId);
                    emit backupCompleted(true, msg);
                });
        connect(uploader_, &GDriveUploader::uploadFailed, this,
                [this](int64_t recordingId, const QString &error) {
                    if (!pendingBackups_.contains(recordingId)) return;
                    auto cb = pendingBackups_.take(recordingId);
                    qWarning("[SYNC] backup upload failed: %s", qPrintable(error));
                    if (pendingBackupTempFiles_.contains(recordingId)) {
                        QFile::remove(pendingBackupTempFiles_.take(recordingId));
                    }
                    setBackupInProgress(false);
                    if (cb) cb(false, error, {});
                    emit backupCompleted(false, error);
                });
    }
    deviceUuid_ = readSyncState(QLatin1String(kKeyDeviceUuid));
    if (deviceUuid_.isEmpty()) {
        deviceUuid_ = QUuid::createUuid().toString(QUuid::WithoutBraces);
        writeSyncState(QLatin1String(kKeyDeviceUuid), deviceUuid_);
    }
    enabled_ = readSyncState(QLatin1String(kKeyEnabled)) == QLatin1String("1");
    folderName_ = migrateLegacyFolderName(readSyncState(QLatin1String(kKeyFolderName)),
                                          folderName_);
    backupFolderName_ = migrateLegacyFolderName(
        readSyncState(QLatin1String(kKeyBackupFolderName)), backupFolderName_);
    lastSyncedAt_ = readSyncState(QLatin1String(kKeyLastSyncedAt)).toLongLong();
    lastBackupAt_ = readSyncState(QLatin1String(kKeyLastBackupAt)).toLongLong();

    hourlyTimer_.setInterval(kHourlyMs);
    hourlyTimer_.setSingleShot(false);
    connect(&hourlyTimer_, &QTimer::timeout, this, [this]() { runCycle(false); });
    if (enabled_) hourlyTimer_.start();
}

bool SyncService::enabled() const { return enabled_; }
QString SyncService::folderName() const { return folderName_; }
QString SyncService::backupFolderName() const { return backupFolderName_; }
qint64 SyncService::lastSyncedAt() const { return lastSyncedAt_; }
qint64 SyncService::lastBackupAt() const { return lastBackupAt_; }
QString SyncService::lastStatus() const { return lastStatus_; }
bool SyncService::inProgress() const { return inProgress_; }
bool SyncService::backupInProgress() const { return backupInProgress_; }
QString SyncService::deviceUuid() const { return deviceUuid_; }

void SyncService::setBackupInProgress(bool on) {
    if (backupInProgress_ == on) return;
    backupInProgress_ = on;
    emit backupInProgressChanged();
}

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

void SyncService::setBackupFolderName(const QString &name) {
    const auto trimmed = name.trimmed();
    if (trimmed.isEmpty() || trimmed == backupFolderName_) return;
    backupFolderName_ = trimmed;
    writeSyncState(QLatin1String(kKeyBackupFolderName), backupFolderName_);
    emit backupFolderNameChanged();
    qInfo("[SYNC] backup folder name changed to '%s'", qPrintable(backupFolderName_));
}

void SyncService::resolveBackupFolderThen(std::function<void(const QString &)> next,
                                          BackupCallback cb) {
    io_.ensureFolder(backupFolderName_,
        [this, next, cb](const QString &folderId, const QString &err) {
            if (!err.isEmpty()) {
                qWarning("[SYNC] failed to resolve backup folder '%s': %s",
                         qPrintable(backupFolderName_), qPrintable(err));
                setBackupInProgress(false);
                QString friendly = err;
                if (err.contains(QStringLiteral("authentication"), Qt::CaseInsensitive)
                    || err.contains(QStringLiteral("unauthorized"), Qt::CaseInsensitive)) {
                    friendly = tr("Google Drive sign-in expired — please log out and back in.");
                }
                if (cb) cb(false, friendly, {});
                emit backupCompleted(false, friendly);
                return;
            }
            next(folderId);
        });
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
            // Rewrite Qt's terse network error into something actionable
            // for the user on the Settings → Sync status line.
            QString friendly = err;
            if (err.contains(QStringLiteral("authentication"), Qt::CaseInsensitive)
                || err.contains(QStringLiteral("unauthorized"), Qt::CaseInsensitive)) {
                friendly = tr("Google Drive sign-in expired — please log out and back in.");
            }
            lastStatus_ = friendly;
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
    auto fail = [this, cb](const QString &msg) {
        setBackupInProgress(false);
        if (cb) cb(false, msg, {});
        emit backupCompleted(false, msg);
    };

    if (backupInProgress_) {
        fail(QStringLiteral("Backup already in progress"));
        return;
    }
    if (!auth_ || !auth_->isAuthenticated()) {
        fail(QStringLiteral("Not authenticated with Google Drive"));
        return;
    }
    if (!uploader_) {
        fail(QStringLiteral("Resumable uploader unavailable"));
        return;
    }
    QFileInfo fi(dbPath);
    if (!fi.exists()) {
        fail(QStringLiteral("DB file not found: %1").arg(dbPath));
        return;
    }

    setBackupInProgress(true);
    qInfo("[SYNC] starting database backup (raw=%lld bytes) — compressing",
          static_cast<long long>(fi.size()));

    QFile src(dbPath);
    if (!src.open(QIODevice::ReadOnly)) {
        fail(QStringLiteral("Cannot read DB: %1").arg(src.errorString()));
        return;
    }
    const auto raw = src.readAll();
    src.close();
    // qCompress = zlib deflate with a 4-byte length prefix (Qt-specific).
    // .qcz extension keeps users from assuming the file is a real .gz.
    const auto compressed = qCompress(raw, 9);
    if (compressed.isEmpty()) {
        fail(QStringLiteral("Compression failed"));
        return;
    }

    const auto cacheRoot =
        QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(cacheRoot);
    const auto stamp = QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss");
    const auto fileName = QStringLiteral("iptvXS-backup-%1.db.qcz").arg(stamp);
    const auto tempPath = cacheRoot + QLatin1Char('/') + fileName;

    QFile out(tempPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        fail(QStringLiteral("Cannot write temp file: %1").arg(out.errorString()));
        return;
    }
    if (out.write(compressed) != compressed.size()) {
        out.close();
        QFile::remove(tempPath);
        fail(QStringLiteral("Short write to temp file"));
        return;
    }
    out.close();

    const double ratio = raw.isEmpty() ? 0.0
                         : 100.0 * (1.0 - static_cast<double>(compressed.size()) /
                                              static_cast<double>(raw.size()));
    qInfo("[SYNC] compressed backup: %lld → %lld bytes (%.1f%% saved)",
          static_cast<long long>(raw.size()),
          static_cast<long long>(compressed.size()), ratio);

    resolveBackupFolderThen([this, tempPath, fileName, cb](const QString &folderId) {
        const auto rid = backupRecordingIdSeq_--;
        pendingBackups_.insert(rid, cb);
        pendingBackupTempFiles_.insert(rid, tempPath);
        // Route through GDriveUploader (resumable, chunked) — Drive's
        // multipart endpoint caps at 5 MB which is way under our DB size.
        uploader_->uploadFile(rid, tempPath, fileName, folderId);
    }, cb);
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
