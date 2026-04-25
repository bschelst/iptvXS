#include "recording_list_viewmodel.h"

#include <QDate>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>

RecordingListViewModel::RecordingListViewModel(QObject *parent)
    : QAbstractListModel(parent) {}

void RecordingListViewModel::setRepositories(iptvxs::RecordingRepository *recordingRepo,
                                             iptvxs::ChannelRepository *channelRepo,
                                             iptvxs::ProgrammeRepository *progRepo) {
    recordingRepo_ = recordingRepo;
    channelRepo_ = channelRepo;
    progRepo_ = progRepo;
    if (recordingRepo_) {
        connect(recordingRepo_, &iptvxs::RecordingRepository::recordingsChanged, this,
                &RecordingListViewModel::loadRecordings);
        loadRecordings();
    }
}

void RecordingListViewModel::setRecordingManager(iptvxs::RecordingManager *manager) {
    manager_ = manager;
    if (manager_) {
        connect(manager_, &iptvxs::RecordingManager::recordingStarted, this,
                [this]() { emit activeCountChanged(); loadRecordings(); });
        connect(manager_, &iptvxs::RecordingManager::recordingStopped, this,
                [this]() { emit activeCountChanged(); loadRecordings(); });
        connect(manager_, &iptvxs::RecordingManager::recordingFailed, this,
                [this]() { emit activeCountChanged(); loadRecordings(); });
    }
}

int RecordingListViewModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) {
        return 0;
    }
    return static_cast<int>(recordings_.size());
}

QVariant RecordingListViewModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= recordings_.size()) {
        return {};
    }

    const auto &entry = recordings_.at(index.row());
    const auto &rec = entry.recording;

    switch (role) {
    case IdRole:
        return QVariant::fromValue(rec.id);
    case ChannelIdRole:
        return QVariant::fromValue(rec.channelId);
    case ChannelNameRole:
        return entry.channelName;
    case StatusRole:
        return rec.status;
    case FilePathRole:
        return rec.filePath;
    case QualityRole:
        return rec.quality;
    case StartTimeRole:
        return QVariant::fromValue(rec.startTime);
    case EndTimeRole:
        return QVariant::fromValue(rec.endTime);
    case FileSizeRole:
        return QVariant::fromValue(rec.fileSizeBytes);
    case ErrorMessageRole:
        return rec.errorMessage;
    case CreatedAtRole:
        return QVariant::fromValue(rec.createdAt);
    case IsActiveRole:
        return manager_ ? manager_->isRecording(rec.id) : false;
    case PinnedRole:
        return rec.pinned;
    case ThumbnailUrlRole:
        return rec.thumbnailUrl;
    case ProgrammeTitleRole:
        return entry.programmeTitle;
    case ChannelLogoRole:
        return entry.channelLogo;
    case DateSectionRole:
        return entry.dateSection;
    case ShowDateHeaderRole:
        return entry.showDateHeader;
    default:
        return {};
    }
}

QHash<int, QByteArray> RecordingListViewModel::roleNames() const {
    return {
        {IdRole, "recordingId"},
        {ChannelIdRole, "channelId"},
        {ChannelNameRole, "channelName"},
        {StatusRole, "status"},
        {FilePathRole, "filePath"},
        {QualityRole, "quality"},
        {StartTimeRole, "startTime"},
        {EndTimeRole, "endTime"},
        {FileSizeRole, "fileSize"},
        {ErrorMessageRole, "errorMessage"},
        {CreatedAtRole, "createdAt"},
        {IsActiveRole, "isActive"},
        {PinnedRole, "pinned"},
        {ThumbnailUrlRole, "thumbnailUrl"},
        {ProgrammeTitleRole, "programmeTitle"},
        {ChannelLogoRole, "channelLogo"},
        {DateSectionRole, "dateSection"},
        {ShowDateHeaderRole, "showDateHeader"},
    };
}

int RecordingListViewModel::count() const {
    return static_cast<int>(recordings_.size());
}

bool RecordingListViewModel::empty() const {
    return recordings_.isEmpty();
}

int RecordingListViewModel::activeCount() const {
    return manager_ ? manager_->activeCount() : 0;
}

int RecordingListViewModel::modelRevision() const {
    return modelRevision_;
}

QString RecordingListViewModel::filterStatus() const {
    return filterStatus_;
}

void RecordingListViewModel::setFilterStatus(const QString &status) {
    if (filterStatus_ != status) {
        filterStatus_ = status;
        emit filterStatusChanged();
        loadRecordings();
    }
}

void RecordingListViewModel::refresh() {
    loadRecordings();
}

void RecordingListViewModel::scheduleRecording(int64_t channelId, int64_t startTime,
                                               int64_t endTime, const QString &quality) {
    if (!recordingRepo_) {
        return;
    }

    iptvxs::Recording rec;
    rec.channelId = channelId;
    rec.status = QStringLiteral("scheduled");
    rec.quality = quality;
    rec.startTime = startTime;
    rec.endTime = endTime;

    recordingRepo_->create(rec);
}

void RecordingListViewModel::startNow(int64_t channelId, int64_t durationSecs,
                                       const QString &quality) {
    if (!recordingRepo_ || !manager_) {
        return;
    }

    iptvxs::Recording rec;
    rec.channelId = channelId;
    rec.status = QStringLiteral("scheduled");
    rec.quality = quality;
    rec.startTime = QDateTime::currentSecsSinceEpoch();
    if (durationSecs > 0) {
        rec.endTime = rec.startTime + durationSecs;
    }

    if (progRepo_ && channelRepo_) {
        auto ch = channelRepo_->findById(channelId);
        if (ch && !ch->epgChannelId.isEmpty()) {
            auto progs = progRepo_->findCurrent(ch->epgChannelId);
            if (!progs.isEmpty()) {
                rec.programmeId = progs.first().id;
            }
        }
    }

    auto id = recordingRepo_->create(rec);
    if (id > 0) {
        manager_->startRecording(id);
    }
}

void RecordingListViewModel::stopRecording(int64_t recordingId) {
    if (manager_) {
        manager_->stopRecording(recordingId);
    }
}

void RecordingListViewModel::deleteRecording(int64_t recordingId) {
    if (manager_ && manager_->isRecording(recordingId)) {
        manager_->stopRecording(recordingId);
    }
    if (recordingRepo_) {
        qInfo("Manual deletion of recording %lld (DB entry only)",
              static_cast<long long>(recordingId));
        recordingRepo_->remove(recordingId);
    }
}

void RecordingListViewModel::deleteRecordingWithFile(int64_t recordingId) {
    if (manager_ && manager_->isRecording(recordingId)) {
        manager_->stopRecording(recordingId);
    }
    if (recordingRepo_) {
        auto rec = recordingRepo_->findById(recordingId);
        if (rec && !rec->filePath.isEmpty()) {
            QFileInfo fi(rec->filePath);
            if (fi.exists() && fi.isFile() && !fi.isSymLink()
                && fi.absoluteFilePath().contains(QStringLiteral("iptvxs"), Qt::CaseInsensitive)
                && !fi.fileName().contains(QStringLiteral("*"))
                && !fi.fileName().contains(QStringLiteral("?"))) {
                QFile::remove(fi.absoluteFilePath());
                qInfo("Manual deletion of recording %lld with file: %s",
                      static_cast<long long>(recordingId), qPrintable(fi.absoluteFilePath()));
            }
        }
        recordingRepo_->remove(recordingId);
    }
}

void RecordingListViewModel::deleteLocalFile(int64_t recordingId) {
    if (!recordingRepo_) return;
    auto rec = recordingRepo_->findById(recordingId);
    if (!rec || rec->filePath.isEmpty()) return;

    QFileInfo fi(rec->filePath);
    if (fi.exists() && fi.isFile() && !fi.isSymLink()
        && fi.absoluteFilePath().contains(QStringLiteral("iptvxs"), Qt::CaseInsensitive)) {
        QFile::remove(fi.absoluteFilePath());
        qInfo("Deleted local file for recording %lld: %s",
              static_cast<long long>(recordingId), qPrintable(fi.absoluteFilePath()));
    }

    iptvxs::Recording updated = *rec;
    updated.filePath.clear();
    updated.fileSizeBytes = 0;
    recordingRepo_->update(updated);
    loadRecordings();
}

qint64 RecordingListViewModel::totalRecordingBytes() const {
    qint64 total = 0;
    for (const auto &entry : recordings_) {
        const auto &r = entry.recording;
        if (r.status == QStringLiteral("uploaded") && !r.filePath.isEmpty()) {
            QFileInfo fi(r.filePath);
            if (fi.exists()) total += fi.size();
        } else if (r.status != QStringLiteral("uploaded")) {
            if (r.fileSizeBytes > 0) {
                total += r.fileSizeBytes;
            } else if (!r.filePath.isEmpty()) {
                QFileInfo fi(r.filePath);
                if (fi.exists()) total += fi.size();
            }
        }
    }
    return total;
}

bool RecordingListViewModel::isChannelRecording(int64_t channelId) const {
    if (!recordingRepo_) return false;
    auto recs = recordingRepo_->findByChannel(channelId);
    for (const auto &r : recs) {
        if (r.status == QStringLiteral("recording")) return true;
    }
    return false;
}

void RecordingListViewModel::stopChannelRecording(int64_t channelId) {
    if (!recordingRepo_ || !manager_) return;
    auto recs = recordingRepo_->findByChannel(channelId);
    for (const auto &r : recs) {
        if (r.status == QStringLiteral("recording")) {
            manager_->stopRecording(r.id);
        }
    }
}

int64_t RecordingListViewModel::startStreamRecording(int64_t channelId,
                                                      const QString &filePath) {
    if (!recordingRepo_) return 0;

    iptvxs::Recording rec;
    rec.channelId = channelId;
    rec.status = QStringLiteral("recording");
    rec.quality = QStringLiteral("original");
    rec.startTime = QDateTime::currentSecsSinceEpoch();
    rec.filePath = filePath;

    auto id = recordingRepo_->create(rec);
    if (id > 0 && channelRepo_) {
        auto ch = channelRepo_->findById(channelId);
        if (ch && !ch->logoUrl.isEmpty()) {
            recordingRepo_->updateThumbnailUrl(id, ch->logoUrl);
        }
    }
    loadRecordings();
    emit activeCountChanged();
    return id;
}

void RecordingListViewModel::completeStreamRecording(int64_t recordingId, int64_t endTime,
                                                      const QString &filePath) {
    if (!recordingRepo_) return;

    auto rec = recordingRepo_->findById(recordingId);
    if (!rec) return;

    auto updated = *rec;
    updated.status = QStringLiteral("completed");
    updated.endTime = endTime;
    if (!filePath.isEmpty()) updated.filePath = filePath;

    QFileInfo fi(updated.filePath);
    if (fi.exists()) updated.fileSizeBytes = fi.size();

    recordingRepo_->update(updated);
    loadRecordings();
    emit activeCountChanged();
    if (recordingId > 0) emit recordingCreated(recordingId);
}

void RecordingListViewModel::addCompletedRecording(int64_t channelId, int64_t startTime,
                                                    int64_t endTime, const QString &filePath) {
    if (!recordingRepo_) return;

    iptvxs::Recording rec;
    rec.channelId = channelId;
    rec.status = QStringLiteral("completed");
    rec.quality = QStringLiteral("original");
    rec.startTime = startTime;
    rec.endTime = endTime;
    rec.filePath = filePath;

    QFileInfo fi(filePath);
    if (fi.exists()) rec.fileSizeBytes = fi.size();

    auto newId = recordingRepo_->create(rec);
    loadRecordings();
    if (newId > 0) emit recordingCreated(newId);
}

void RecordingListViewModel::clearError(int64_t recordingId) {
    if (recordingRepo_) {
        recordingRepo_->updateStatus(recordingId, QStringLiteral("failed"), QString());
        loadRecordings();
    }
}

QString RecordingListViewModel::formatFileSize(int64_t bytes) const {
    if (bytes <= 0) {
        return QStringLiteral("—");
    }
    const QStringList units = {
        QStringLiteral("B"), QStringLiteral("KB"), QStringLiteral("MB"), QStringLiteral("GB")
    };
    double size = static_cast<double>(bytes);
    int unitIndex = 0;
    while (size >= 1024.0 && unitIndex < units.size() - 1) {
        size /= 1024.0;
        ++unitIndex;
    }
    return QStringLiteral("%1 %2").arg(size, 0, 'f', unitIndex == 0 ? 0 : 1).arg(units[unitIndex]);
}

QString RecordingListViewModel::formatDateTime(int64_t timestamp) const {
    if (timestamp <= 0) {
        return QStringLiteral("—");
    }
    return QDateTime::fromSecsSinceEpoch(timestamp).toString(QStringLiteral("dd MMM yyyy HH:mm"));
}

namespace {
QString recordingDateSection(int64_t timestamp) {
    if (timestamp <= 0) {
        return QStringLiteral("Unknown");
    }

    const auto date = QDateTime::fromSecsSinceEpoch(timestamp).date();
    const auto today = QDate::currentDate();
    if (date == today) {
        return QStringLiteral("Today");
    }
    if (date == today.addDays(-1)) {
        return QStringLiteral("Yesterday");
    }
    return date.toString(QStringLiteral("dd MMM yyyy"));
}
} // namespace

QString RecordingListViewModel::formatDuration(int64_t startTime, int64_t endTime) const {
    if (startTime <= 0) {
        return QStringLiteral("—");
    }
    auto end = endTime > 0 ? endTime : QDateTime::currentSecsSinceEpoch();
    auto secs = end - startTime;
    if (secs < 0) {
        return QStringLiteral("—");
    }
    auto hours = secs / 3600;
    auto mins = (secs % 3600) / 60;
    auto s = secs % 60;
    if (hours > 0) {
        return QStringLiteral("%1h %2m").arg(hours).arg(mins, 2, 10, QChar('0'));
    }
    return QStringLiteral("%1m %2s").arg(mins).arg(s, 2, 10, QChar('0'));
}

void RecordingListViewModel::loadRecordings() {
    if (!recordingRepo_) {
        return;
    }

    beginResetModel();
    recordings_.clear();

    auto recs = filterStatus_.isEmpty()
                    ? recordingRepo_->findAll()
                    : recordingRepo_->findByStatus(filterStatus_);

    QString previousSection;
    for (const auto &rec : recs) {
        RecordingEntry entry;
        entry.recording = rec;
        entry.channelName = channelNameForId(rec.channelId);
        if (channelRepo_) {
            auto ch = channelRepo_->findById(rec.channelId);
            if (ch) entry.channelLogo = ch->logoUrl;
        }
        if (progRepo_) {
            if (rec.programmeId > 0) {
                auto prog = progRepo_->findById(rec.programmeId);
                if (prog) {
                    entry.programmeTitle = prog->title;
                }
            }
            if (entry.programmeTitle.isEmpty() && channelRepo_) {
                auto ch = channelRepo_->findById(rec.channelId);
                if (ch && !ch->epgChannelId.isEmpty()) {
                    auto fromTime = rec.startTime > 0 ? rec.startTime - 1800 : 0;
                    auto toTime = rec.endTime > 0 ? rec.endTime + 1800 : rec.startTime + 7200;
                    auto progs = progRepo_->findByChannel(ch->epgChannelId, fromTime, toTime);
                    if (!progs.isEmpty()) {
                        entry.programmeTitle = progs.first().title;
                    }
                }
            }
        }
        entry.dateSection = recordingDateSection(rec.startTime);
        entry.showDateHeader = entry.dateSection != previousSection;
        previousSection = entry.dateSection;
        recordings_.append(entry);
    }

    endResetModel();
    emit countChanged();
    ++modelRevision_;
    emit modelRevisionChanged();
}

void RecordingListViewModel::togglePin(int64_t recordingId) {
    if (!recordingRepo_) return;
    auto rec = recordingRepo_->findById(recordingId);
    if (!rec) return;
    recordingRepo_->setPinned(recordingId, !rec->pinned);
    loadRecordings();
}

QVariantList RecordingListViewModel::recordingSections() const {
    QVariantList sections;
    QString lastSection;
    for (const auto &entry : recordings_) {
        if (entry.dateSection == lastSection) {
            continue;
        }
        lastSection = entry.dateSection;
        sections.append(entry.dateSection);
    }
    return sections;
}

QVariantList RecordingListViewModel::recordingsForSection(const QString &section) const {
    QVariantList items;
    if (section.isEmpty()) return items;

    for (const auto &entry : recordings_) {
        if (entry.dateSection != section) continue;
        const auto &rec = entry.recording;
        QVariantMap item;
        item[QStringLiteral("recordingId")] = QVariant::fromValue(rec.id);
        item[QStringLiteral("channelId")] = QVariant::fromValue(rec.channelId);
        item[QStringLiteral("channelName")] = entry.channelName;
        item[QStringLiteral("status")] = rec.status;
        item[QStringLiteral("filePath")] = rec.filePath;
        item[QStringLiteral("quality")] = rec.quality;
        item[QStringLiteral("startTime")] = QVariant::fromValue(rec.startTime);
        item[QStringLiteral("endTime")] = QVariant::fromValue(rec.endTime);
        item[QStringLiteral("fileSize")] = QVariant::fromValue(rec.fileSizeBytes);
        item[QStringLiteral("errorMessage")] = rec.errorMessage;
        item[QStringLiteral("createdAt")] = QVariant::fromValue(rec.createdAt);
        item[QStringLiteral("isActive")] = manager_ ? manager_->isRecording(rec.id) : false;
        item[QStringLiteral("pinned")] = rec.pinned;
        item[QStringLiteral("thumbnailUrl")] = rec.thumbnailUrl;
        item[QStringLiteral("programmeTitle")] = entry.programmeTitle;
        item[QStringLiteral("channelLogo")] = entry.channelLogo;
        item[QStringLiteral("dateSection")] = entry.dateSection;
        items.append(item);
    }
    return items;
}

QString RecordingListViewModel::channelNameForId(int64_t channelId) const {
    if (!channelRepo_) {
        return QStringLiteral("Unknown");
    }
    auto channel = channelRepo_->findById(channelId);
    return channel ? channel->name : QStringLiteral("Unknown");
}
