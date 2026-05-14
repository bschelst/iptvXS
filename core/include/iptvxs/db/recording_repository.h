// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QVector>
#include <optional>

#include "iptvxs/models/recording.h"

namespace iptvxs {

class RecordingRepository : public QObject {
    Q_OBJECT

public:
    explicit RecordingRepository(QSqlDatabase db, QObject *parent = nullptr);

    int64_t create(const Recording &recording);
    bool update(const Recording &recording);
    bool remove(int64_t id);

    std::optional<Recording> findById(int64_t id) const;
    QVector<Recording> findAll() const;
    QVector<Recording> findByStatus(const QString &status) const;
    QVector<Recording> search(const QString &query, int limit = 100, int offset = 0) const;
    QVector<Recording> findScheduled(int64_t fromTime, int64_t toTime) const;
    QVector<Recording> findByChannel(int64_t channelId) const;

    bool updateStatus(int64_t id, const QString &status, const QString &errorMessage = {});
    bool updateFileSize(int64_t id, int64_t fileSizeBytes);
    bool updateFilePath(int64_t id, const QString &filePath);
    bool updateEndTime(int64_t id, int64_t endTime);
    bool updateUploadUrl(int64_t id, const QString &uploadUrl);
    bool updateThumbnailUrl(int64_t id, const QString &url);
    bool setPinned(int64_t id, bool pinned);

    int count() const;
    int countByStatus(const QString &status) const;

signals:
    void recordingsChanged();
    void errorOccurred(const QString &message);

private:
    Recording recordingFromQuery(const QSqlQuery &q) const;
    QSqlDatabase db_;
};

} // namespace iptvxs
