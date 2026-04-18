#pragma once

#include <QString>
#include <cstdint>

namespace iptvxs {

struct Channel {
    int64_t id{0};
    int64_t serverId{0};
    int64_t categoryId{0};
    QString externalId;
    QString name;
    QString streamUrl;
    QString logoUrl;
    QString epgChannelId;
    QString type; // "live", "vod", "series"
    int64_t addedAt{0};
};

} // namespace iptvxs
