#include "iptvxs/recording/recording_manager.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>

namespace iptvxs {

RecordingManager::RecordingManager(QObject *parent) : QObject(parent) {
    schedulerTimer_.setInterval(30000);
    connect(&schedulerTimer_, &QTimer::timeout, this,
            &RecordingManager::checkScheduledRecordings);
}

RecordingManager::~RecordingManager() {
    stop();
}

void RecordingManager::setRepositories(RecordingRepository *recordingRepo,
                                       ChannelRepository *channelRepo,
                                       SettingsRepository *settingsRepo,
                                       ProgrammeRepository *progRepo) {
    recordingRepo_ = recordingRepo;
    channelRepo_ = channelRepo;
    settingsRepo_ = settingsRepo;
    progRepo_ = progRepo;
}

void RecordingManager::start() {
    schedulerTimer_.start();
    checkScheduledRecordings();
}

void RecordingManager::stop() {
    schedulerTimer_.stop();

    const auto ids = activeProcesses_.keys();
    for (auto id : ids) {
        stopRecording(id);
    }
}

bool RecordingManager::startRecording(int64_t recordingId) {
    if (activeProcesses_.contains(recordingId)) {
        return true;
    }

    if (!recordingRepo_) {
        return false;
    }

    auto recording = recordingRepo_->findById(recordingId);
    if (!recording) {
        emit errorOccurred(QStringLiteral("Recording %1 not found").arg(recordingId));
        return false;
    }

    auto channel = channelRepo_->findById(recording->channelId);
    if (!channel) {
        recordingRepo_->updateStatus(recordingId, QStringLiteral("failed"),
                                     QStringLiteral("Channel not found"));
        emit recordingFailed(recordingId, QStringLiteral("Channel not found"));
        return false;
    }

    auto filePath = buildFilePath(*recording, *channel);
    QDir().mkpath(QFileInfo(filePath).absolutePath());

    auto args = buildFfmpegArgs(channel->streamUrl, filePath);

    auto *process = new QProcess(this);
    process->setProcessChannelMode(QProcess::MergedChannels);

    connect(process,
            QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, recordingId](int exitCode, QProcess::ExitStatus exitStatus) {
                onProcessFinished(recordingId, exitCode, exitStatus);
            });

    connect(process, &QProcess::errorOccurred, this,
            [this, recordingId](QProcess::ProcessError error) {
                Q_UNUSED(error)
                auto *proc = activeProcesses_.take(recordingId);
                if (proc) {
                    recordingRepo_->updateStatus(recordingId, QStringLiteral("failed"),
                                                 proc->errorString());
                    emit recordingFailed(recordingId, proc->errorString());
                    proc->deleteLater();
                }
            });

    activeProcesses_.insert(recordingId, process);
    recordingRepo_->updateStatus(recordingId, QStringLiteral("recording"));
    recordingRepo_->updateFilePath(recordingId, filePath);

    connect(process, &QProcess::started, this, [this, recordingId]() {
        emit recordingStarted(recordingId);
    });

    process->start(QStringLiteral("ffmpeg"), args);
    return true;
}

bool RecordingManager::stopRecording(int64_t recordingId) {
    auto *process = activeProcesses_.take(recordingId);
    if (!process) {
        return false;
    }

    process->write("q");
    if (!process->waitForFinished(5000)) {
        process->terminate();
        if (!process->waitForFinished(3000)) {
            process->kill();
            process->waitForFinished(1000);
        }
    }

    process->deleteLater();

    if (recordingRepo_) {
        auto now = QDateTime::currentSecsSinceEpoch();
        recordingRepo_->updateEndTime(recordingId, now);

        auto recording = recordingRepo_->findById(recordingId);
        if (recording && !recording->filePath.isEmpty()) {
            QFileInfo fileInfo(recording->filePath);
            if (fileInfo.exists()) {
                recordingRepo_->updateFileSize(recordingId, fileInfo.size());
            }
        }
        recordingRepo_->updateStatus(recordingId, QStringLiteral("completed"));
    }

    emit recordingStopped(recordingId);
    return true;
}

bool RecordingManager::isRecording(int64_t recordingId) const {
    return activeProcesses_.contains(recordingId);
}

int RecordingManager::activeCount() const {
    return activeProcesses_.size();
}

QString RecordingManager::recordingDirectory() const {
    if (settingsRepo_) {
        auto dir = settingsRepo_->getString(QStringLiteral("recording_directory"));
        if (!dir.isEmpty()) {
            return dir;
        }
    }

    return QStandardPaths::writableLocation(QStandardPaths::MoviesLocation)
           + QStringLiteral("/iptvxs");
}

void RecordingManager::checkScheduledRecordings() {
    if (!recordingRepo_) {
        return;
    }

    auto now = QDateTime::currentSecsSinceEpoch();
    auto upcoming = recordingRepo_->findScheduled(0, now);

    for (const auto &rec : upcoming) {
        if (!activeProcesses_.contains(rec.id)) {
            startRecording(rec.id);
        }
    }

    const auto activeIds = activeProcesses_.keys();
    for (auto id : activeIds) {
        auto rec = recordingRepo_->findById(id);
        if (rec && rec->endTime > 0 && now >= rec->endTime) {
            stopRecording(id);
        }

        if (rec && !rec->filePath.isEmpty()) {
            QFileInfo fileInfo(rec->filePath);
            if (fileInfo.exists()) {
                recordingRepo_->updateFileSize(id, fileInfo.size());
            }
        }
    }
}

void RecordingManager::onProcessFinished(int64_t recordingId, int exitCode,
                                         QProcess::ExitStatus exitStatus) {
    auto *process = activeProcesses_.take(recordingId);
    if (!process) {
        return;
    }

    if (recordingRepo_) {
        auto now = QDateTime::currentSecsSinceEpoch();
        recordingRepo_->updateEndTime(recordingId, now);

        auto recording = recordingRepo_->findById(recordingId);
        if (recording && !recording->filePath.isEmpty()) {
            QFileInfo fileInfo(recording->filePath);
            if (fileInfo.exists()) {
                recordingRepo_->updateFileSize(recordingId, fileInfo.size());
            }
        }

        if (exitStatus == QProcess::CrashExit || exitCode != 0) {
            auto output = QString::fromUtf8(process->readAll());
            auto errorMsg = output.right(500);
            recordingRepo_->updateStatus(recordingId, QStringLiteral("failed"), errorMsg);
            emit recordingFailed(recordingId, errorMsg);
        } else {
            recordingRepo_->updateStatus(recordingId, QStringLiteral("completed"));
            emit recordingStopped(recordingId);
        }
    }

    process->deleteLater();
}

QString RecordingManager::buildFilePath(const Recording &recording,
                                        const Channel &channel) const {
    auto dir = recordingDirectory();
    auto dt = QDateTime::fromSecsSinceEpoch(recording.startTime);
    auto datePart = dt.toString(QStringLiteral("yyyy-MM-dd"));
    auto timePart = dt.toString(QStringLiteral("HHmmss"));

    auto safeName = channel.name;
    safeName.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9_-]")),
                     QStringLiteral("_"));

    QString progPart;
    if (progRepo_ && !channel.epgChannelId.isEmpty()) {
        auto programmes = progRepo_->findByChannel(channel.epgChannelId,
                                                   recording.startTime,
                                                   recording.startTime + 1);
        if (!programmes.empty()) {
            progPart = programmes.front().title;
            progPart.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9_-]")),
                             QStringLiteral("_"));
        }
    }

    if (progPart.isEmpty()) {
        return QStringLiteral("%1/%2_%3_%4.mkv").arg(dir, datePart, timePart, safeName);
    }
    return QStringLiteral("%1/%2_%3_%4_%5.mkv").arg(dir, datePart, timePart, safeName, progPart);
}

QStringList RecordingManager::buildFfmpegArgs(const QString &streamUrl,
                                              const QString &outputPath) const {
    return {
        QStringLiteral("-y"),
        QStringLiteral("-i"), streamUrl,
        QStringLiteral("-c"), QStringLiteral("copy"),
        QStringLiteral("-movflags"), QStringLiteral("+faststart"),
        outputPath
    };
}

} // namespace iptvxs
