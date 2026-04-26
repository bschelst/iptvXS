// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QString>
#include <cstdint>

namespace iptvxs {

struct Category {
    int64_t id{0};
    int64_t serverId{0};
    QString externalId;
    QString name;
    QString type; // "live", "vod", "series"
};

} // namespace iptvxs
