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

    enforceStorageLimit();

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
    safeName.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9_. -]")),
                     QStringLiteral("_"));
    safeName.replace(QRegularExpression(QStringLiteral("_{2,}")), QStringLiteral("_"));
    safeName = safeName.trimmed();
    if (safeName.isEmpty()) safeName = QStringLiteral("recording");

    QString progPart;
    if (progRepo_ && !channel.epgChannelId.isEmpty()) {
        auto programmes = progRepo_->findByChannel(channel.epgChannelId,
                                                   recording.startTime,
                                                   recording.startTime + 1);
        if (!programmes.empty()) {
            progPart = programmes.front().title;
            progPart.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9_. -]")),
                             QStringLiteral("_"));
            progPart.replace(QRegularExpression(QStringLiteral("_{2,}")), QStringLiteral("_"));
            progPart = progPart.trimmed();
        }
    }

    QString base;
    if (progPart.isEmpty()) {
        base = QStringLiteral("%1/%2_%3_%4").arg(dir, datePart, timePart, safeName);
    } else {
        base = QStringLiteral("%1/%2_%3_%4_%5").arg(dir, datePart, timePart, safeName, progPart);
    }

    QString path = base + QStringLiteral(".mkv");
    int counter = 1;
    while (QFileInfo::exists(path)) {
        path = QStringLiteral("%1_%2.mkv").arg(base).arg(counter++);
    }
    return path;
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

void RecordingManager::enforceStorageLimit() {
    if (!settingsRepo_ || !recordingRepo_) return;

    auto maxGb = settingsRepo_->getInt(QStringLiteral("max_recording_size_gb"), 0);
    if (maxGb <= 0) return;

    qint64 maxBytes = static_cast<qint64>(maxGb) * 1024LL * 1024LL * 1024LL;
    auto recordings = recordingRepo_->findAll();

    qint64 totalBytes = 0;
    for (const auto &r : recordings) {
        if (r.status == QStringLiteral("recording")) continue;
        if (!r.filePath.isEmpty()) {
            QFileInfo fi(r.filePath);
            totalBytes += fi.exists() ? fi.size() : r.fileSizeBytes;
        }
    }

    if (totalBytes <= maxBytes) return;

    std::sort(recordings.begin(), recordings.end(),
              [](const Recording &a, const Recording &b) { return a.createdAt < b.createdAt; });

    for (const auto &r : recordings) {
        if (totalBytes <= maxBytes) break;
        if (r.pinned) continue;
        if (r.status == QStringLiteral("recording")) continue;
        if (r.filePath.isEmpty()) continue;

        QFileInfo fi(r.filePath);
        if (fi.exists() && fi.isFile() && !fi.isSymLink()
            && fi.absoluteFilePath().contains(QStringLiteral("iptvxs"))) {
            qint64 fileSize = fi.size();
            QFile::remove(fi.absoluteFilePath());
            totalBytes -= fileSize;
            qInfo("Auto-deleted old recording: %s (%lld bytes)",
                  qPrintable(fi.fileName()), static_cast<long long>(fileSize));
        }
        recordingRepo_->remove(r.id);
    }
}

} // namespace iptvxs
