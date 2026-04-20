#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/recording_repository.h"
#include "iptvxs/recording/recording_manager.h"

class RecordingListViewModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool empty READ empty NOTIFY countChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY activeCountChanged)
    Q_PROPERTY(QString filterStatus READ filterStatus WRITE setFilterStatus NOTIFY filterStatusChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        ChannelIdRole,
        ChannelNameRole,
        StatusRole,
        FilePathRole,
        QualityRole,
        StartTimeRole,
        EndTimeRole,
        FileSizeRole,
        ErrorMessageRole,
        CreatedAtRole,
        IsActiveRole
    };

    explicit RecordingListViewModel(QObject *parent = nullptr);

    void setRepositories(iptvxs::RecordingRepository *recordingRepo,
                         iptvxs::ChannelRepository *channelRepo);
    void setRecordingManager(iptvxs::RecordingManager *manager);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const;
    bool empty() const;
    int activeCount() const;
    QString filterStatus() const;
    void setFilterStatus(const QString &status);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void scheduleRecording(int64_t channelId, int64_t startTime,
                                       int64_t endTime, const QString &quality = "original");
    Q_INVOKABLE void startNow(int64_t channelId, int64_t durationSecs = 0,
                              const QString &quality = "original");
    Q_INVOKABLE int64_t startStreamRecording(int64_t channelId, const QString &filePath);
    Q_INVOKABLE void completeStreamRecording(int64_t recordingId, int64_t endTime,
                                              const QString &filePath);
    Q_INVOKABLE void stopRecording(int64_t recordingId);
    Q_INVOKABLE void deleteRecording(int64_t recordingId);
    Q_INVOKABLE void deleteRecordingWithFile(int64_t recordingId);
    Q_INVOKABLE qint64 totalRecordingBytes() const;
    Q_INVOKABLE bool isChannelRecording(int64_t channelId) const;
    Q_INVOKABLE void stopChannelRecording(int64_t channelId);
    Q_INVOKABLE void addCompletedRecording(int64_t channelId, int64_t startTime,
                                           int64_t endTime, const QString &filePath);
    Q_INVOKABLE void clearError(int64_t recordingId);
    Q_INVOKABLE QString formatFileSize(int64_t bytes) const;
    Q_INVOKABLE QString formatDateTime(int64_t timestamp) const;
    Q_INVOKABLE QString formatDuration(int64_t startTime, int64_t endTime) const;

signals:
    void countChanged();
    void activeCountChanged();
    void filterStatusChanged();
    void recordingCreated(int64_t recordingId);

private:
    struct RecordingEntry {
        iptvxs::Recording recording;
        QString channelName;
    };

    void loadRecordings();
    QString channelNameForId(int64_t channelId) const;

    iptvxs::RecordingRepository *recordingRepo_{nullptr};
    iptvxs::ChannelRepository *channelRepo_{nullptr};
    iptvxs::RecordingManager *manager_{nullptr};
    QVector<RecordingEntry> recordings_;
    QString filterStatus_;
};
