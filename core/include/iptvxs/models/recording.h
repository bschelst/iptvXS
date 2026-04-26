// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QString>
#include <cstdint>

namespace iptvxs {

struct Recording {
    int64_t id{0};
    int64_t channelId{0};
    int64_t programmeId{0};
    QString status; // "scheduled", "recording", "completed", "failed", "uploading", "uploaded"
    QString filePath;
    QString quality; // "original", "720p", "480p"
    int64_t startTime{0};
    int64_t endTime{0};
    int64_t fileSizeBytes{0};
    QString gdriveFileId;
    QString gdriveUploadUrl;
    QString errorMessage;
    int64_t createdAt{0};
    bool pinned{false};
    QString thumbnailUrl;
};

} // namespace iptvxs
