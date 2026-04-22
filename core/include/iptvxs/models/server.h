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
    QString epgUrl;
    int64_t lastSyncedAt{0};
    int64_t createdAt{0};
    bool enabled{true};
    bool isPrimary{false};
};

} // namespace iptvxs
