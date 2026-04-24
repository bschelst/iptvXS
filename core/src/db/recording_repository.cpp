#include "iptvxs/db/recording_repository.h"

#include <QSqlError>
#include <QSqlQuery>

namespace iptvxs {

RecordingRepository::RecordingRepository(QSqlDatabase db, QObject *parent)
    : QObject(parent), db_(db) {}

int64_t RecordingRepository::create(const Recording &recording) {
    QSqlQuery q(db_);
    q.prepare(R"(
        INSERT INTO recordings (channel_id, programme_id, status, file_path, quality,
                                start_time, end_time, file_size_bytes, gdrive_file_id,
                                gdrive_upload_url, error_message, pinned, thumbnail_url)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    )");
    q.addBindValue(static_cast<qlonglong>(recording.channelId));
    q.addBindValue(recording.programmeId > 0
                       ? QVariant(static_cast<qlonglong>(recording.programmeId))
                       : QVariant());
    q.addBindValue(recording.status);
    q.addBindValue(recording.filePath);
    q.addBindValue(recording.quality);
    q.addBindValue(static_cast<qlonglong>(recording.startTime));
    q.addBindValue(recording.endTime > 0
                       ? QVariant(static_cast<qlonglong>(recording.endTime))
                       : QVariant());
    q.addBindValue(static_cast<qlonglong>(recording.fileSizeBytes));
    q.addBindValue(recording.gdriveFileId);
    q.addBindValue(recording.gdriveUploadUrl);
    q.addBindValue(recording.errorMessage);
    q.addBindValue(recording.pinned ? 1 : 0);
    q.addBindValue(recording.thumbnailUrl);

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to create recording: %1").arg(q.lastError().text()));
        return -1;
    }

    emit recordingsChanged();
    return q.lastInsertId().toLongLong();
}

bool RecordingRepository::update(const Recording &recording) {
    QSqlQuery q(db_);
    q.prepare(R"(
        UPDATE recordings SET
            channel_id = ?, programme_id = ?, status = ?, file_path = ?,
            quality = ?, start_time = ?, end_time = ?, file_size_bytes = ?,
            gdrive_file_id = ?, gdrive_upload_url = ?, error_message = ?,
            pinned = ?, thumbnail_url = ?
        WHERE id = ?
    )");
    q.addBindValue(static_cast<qlonglong>(recording.channelId));
    q.addBindValue(recording.programmeId > 0
                       ? QVariant(static_cast<qlonglong>(recording.programmeId))
                       : QVariant());
    q.addBindValue(recording.status);
    q.addBindValue(recording.filePath);
    q.addBindValue(recording.quality);
    q.addBindValue(static_cast<qlonglong>(recording.startTime));
    q.addBindValue(recording.endTime > 0
                       ? QVariant(static_cast<qlonglong>(recording.endTime))
                       : QVariant());
    q.addBindValue(static_cast<qlonglong>(recording.fileSizeBytes));
    q.addBindValue(recording.gdriveFileId);
    q.addBindValue(recording.gdriveUploadUrl);
    q.addBindValue(recording.errorMessage);
    q.addBindValue(recording.pinned ? 1 : 0);
    q.addBindValue(recording.thumbnailUrl);
    q.addBindValue(static_cast<qlonglong>(recording.id));

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to update recording: %1").arg(q.lastError().text()));
        return false;
    }

    emit recordingsChanged();
    return true;
}

bool RecordingRepository::remove(int64_t id) {
    QSqlQuery q(db_);
    q.prepare("DELETE FROM recordings WHERE id = ?");
    q.addBindValue(static_cast<qlonglong>(id));

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to delete recording: %1").arg(q.lastError().text()));
        return false;
    }

    if (q.numRowsAffected() > 0) {
        emit recordingsChanged();
    }

    return true;
}

std::optional<Recording> RecordingRepository::findById(int64_t id) const {
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, channel_id, programme_id, status, file_path, quality,
               start_time, end_time, file_size_bytes, gdrive_file_id,
               gdrive_upload_url, error_message, created_at, pinned,
               thumbnail_url
        FROM recordings WHERE id = ?
    )");
    q.addBindValue(static_cast<qlonglong>(id));

    if (!q.exec() || !q.next()) {
        return std::nullopt;
    }

    return recordingFromQuery(q);
}

QVector<Recording> RecordingRepository::findAll() const {
    QVector<Recording> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, channel_id, programme_id, status, file_path, quality,
               start_time, end_time, file_size_bytes, gdrive_file_id,
               gdrive_upload_url, error_message, created_at, pinned,
               thumbnail_url
        FROM recordings
        ORDER BY start_time DESC
    )");

    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        results.append(recordingFromQuery(q));
    }

    return results;
}

QVector<Recording> RecordingRepository::findByStatus(const QString &status) const {
    QVector<Recording> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, channel_id, programme_id, status, file_path, quality,
               start_time, end_time, file_size_bytes, gdrive_file_id,
               gdrive_upload_url, error_message, created_at, pinned,
               thumbnail_url
        FROM recordings WHERE status = ?
        ORDER BY start_time DESC
    )");
    q.addBindValue(status);

    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        results.append(recordingFromQuery(q));
    }

    return results;
}

QVector<Recording> RecordingRepository::findScheduled(int64_t fromTime, int64_t toTime) const {
    QVector<Recording> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, channel_id, programme_id, status, file_path, quality,
               start_time, end_time, file_size_bytes, gdrive_file_id,
               gdrive_upload_url, error_message, created_at, pinned,
               thumbnail_url
        FROM recordings
        WHERE status = 'scheduled' AND start_time >= ? AND start_time <= ?
        ORDER BY start_time ASC
    )");
    q.addBindValue(static_cast<qlonglong>(fromTime));
    q.addBindValue(static_cast<qlonglong>(toTime));

    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        results.append(recordingFromQuery(q));
    }

    return results;
}

QVector<Recording> RecordingRepository::findByChannel(int64_t channelId) const {
    QVector<Recording> results;
    QSqlQuery q(db_);
    q.prepare(R"(
        SELECT id, channel_id, programme_id, status, file_path, quality,
               start_time, end_time, file_size_bytes, gdrive_file_id,
               gdrive_upload_url, error_message, created_at, pinned,
               thumbnail_url
        FROM recordings WHERE channel_id = ?
        ORDER BY start_time DESC
    )");
    q.addBindValue(static_cast<qlonglong>(channelId));

    if (!q.exec()) {
        return results;
    }

    while (q.next()) {
        results.append(recordingFromQuery(q));
    }

    return results;
}

bool RecordingRepository::updateStatus(int64_t id, const QString &status,
                                       const QString &errorMessage) {
    QSqlQuery q(db_);
    q.prepare("UPDATE recordings SET status = ?, error_message = ? WHERE id = ?");
    q.addBindValue(status);
    q.addBindValue(errorMessage);
    q.addBindValue(static_cast<qlonglong>(id));

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to update recording status: %1").arg(q.lastError().text()));
        return false;
    }

    emit recordingsChanged();
    return true;
}

bool RecordingRepository::updateFileSize(int64_t id, int64_t fileSizeBytes) {
    QSqlQuery q(db_);
    q.prepare("UPDATE recordings SET file_size_bytes = ? WHERE id = ?");
    q.addBindValue(static_cast<qlonglong>(fileSizeBytes));
    q.addBindValue(static_cast<qlonglong>(id));

    if (!q.exec()) {
        return false;
    }

    return true;
}

bool RecordingRepository::updateFilePath(int64_t id, const QString &filePath) {
    QSqlQuery q(db_);
    q.prepare("UPDATE recordings SET file_path = ? WHERE id = ?");
    q.addBindValue(filePath);
    q.addBindValue(static_cast<qlonglong>(id));

    if (!q.exec()) {
        return false;
    }

    return true;
}

bool RecordingRepository::updateEndTime(int64_t id, int64_t endTime) {
    QSqlQuery q(db_);
    q.prepare("UPDATE recordings SET end_time = ? WHERE id = ?");
    q.addBindValue(static_cast<qlonglong>(endTime));
    q.addBindValue(static_cast<qlonglong>(id));
    if (!q.exec()) return false;
    emit recordingsChanged();
    return true;
}

int RecordingRepository::count() const {
    QSqlQuery q(db_);
    if (!q.exec("SELECT COUNT(*) FROM recordings")) {
        return 0;
    }
    if (q.next()) {
        return q.value(0).toInt();
    }
    return 0;
}

int RecordingRepository::countByStatus(const QString &status) const {
    QSqlQuery q(db_);
    q.prepare("SELECT COUNT(*) FROM recordings WHERE status = ?");
    q.addBindValue(status);
    if (!q.exec() || !q.next()) {
        return 0;
    }
    return q.value(0).toInt();
}

Recording RecordingRepository::recordingFromQuery(const QSqlQuery &q) const {
    Recording rec;
    rec.id = q.value(0).toLongLong();
    rec.channelId = q.value(1).toLongLong();
    rec.programmeId = q.value(2).toLongLong();
    rec.status = q.value(3).toString();
    rec.filePath = q.value(4).toString();
    rec.quality = q.value(5).toString();
    rec.startTime = q.value(6).toLongLong();
    rec.endTime = q.value(7).toLongLong();
    rec.fileSizeBytes = q.value(8).toLongLong();
    rec.gdriveFileId = q.value(9).toString();
    rec.gdriveUploadUrl = q.value(10).toString();
    rec.errorMessage = q.value(11).toString();
    rec.createdAt = q.value(12).toLongLong();
    rec.pinned = q.value(13).toBool();
    rec.thumbnailUrl = q.value(14).toString();
    return rec;
}

bool RecordingRepository::updateThumbnailUrl(int64_t id, const QString &url) {
    QSqlQuery q(db_);
    q.prepare("UPDATE recordings SET thumbnail_url = ? WHERE id = ?");
    q.addBindValue(url);
    q.addBindValue(static_cast<qlonglong>(id));
    return q.exec();
}

bool RecordingRepository::updateUploadUrl(int64_t id, const QString &uploadUrl) {
    QSqlQuery q(db_);
    q.prepare("UPDATE recordings SET gdrive_upload_url = ? WHERE id = ?");
    q.addBindValue(uploadUrl);
    q.addBindValue(static_cast<qlonglong>(id));
    return q.exec();
}

bool RecordingRepository::setPinned(int64_t id, bool pinned) {
    QSqlQuery q(db_);
    q.prepare("UPDATE recordings SET pinned = ? WHERE id = ?");
    q.addBindValue(pinned ? 1 : 0);
    q.addBindValue(static_cast<qlonglong>(id));

    if (!q.exec()) {
        emit errorOccurred(
            QStringLiteral("Failed to update recording pinned state: %1").arg(q.lastError().text()));
        return false;
    }

    emit recordingsChanged();
    return true;
}

} // namespace iptvxs
