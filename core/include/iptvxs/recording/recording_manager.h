#pragma once

#include <QHash>
#include <QObject>
#include <QProcess>
#include <QTimer>

#include "iptvxs/db/channel_repository.h"
#include "iptvxs/db/programme_repository.h"
#include "iptvxs/db/recording_repository.h"
#include "iptvxs/db/settings_repository.h"

namespace iptvxs {

class RecordingManager : public QObject {
    Q_OBJECT

public:
    explicit RecordingManager(QObject *parent = nullptr);
    ~RecordingManager() override;

    void setRepositories(RecordingRepository *recordingRepo,
                         ChannelRepository *channelRepo,
                         SettingsRepository *settingsRepo,
                         ProgrammeRepository *progRepo = nullptr);

    void start();
    void stop();

    bool startRecording(int64_t recordingId);
    bool stopRecording(int64_t recordingId);
    bool isRecording(int64_t recordingId) const;
    int activeCount() const;

    QString recordingDirectory() const;

signals:
    void recordingStarted(int64_t recordingId);
    void recordingStopped(int64_t recordingId);
    void recordingFailed(int64_t recordingId, const QString &error);
    void errorOccurred(const QString &message);

private slots:
    void checkScheduledRecordings();
    void onProcessFinished(int64_t recordingId, int exitCode, QProcess::ExitStatus exitStatus);

private:
    QString buildFilePath(const Recording &recording, const Channel &channel) const;
    QStringList buildFfmpegArgs(const QString &streamUrl, const QString &outputPath) const;

    RecordingRepository *recordingRepo_{nullptr};
    ChannelRepository *channelRepo_{nullptr};
    SettingsRepository *settingsRepo_{nullptr};
    ProgrammeRepository *progRepo_{nullptr};
    QTimer schedulerTimer_;
    QHash<int64_t, QProcess *> activeProcesses_;
};

} // namespace iptvxs
