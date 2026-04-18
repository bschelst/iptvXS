#pragma once

#include <QString>
#include <cstdint>

namespace iptvxs {

struct Server {
    int64_t id{0};
    QString name;
    QString type; // "xtream", "m3u"
    QString url;
    QString username;
    QString password;
    QString userAgent;
    int64_t lastSyncedAt{0};
    int64_t createdAt{0};
};

} // namespace iptvxs
