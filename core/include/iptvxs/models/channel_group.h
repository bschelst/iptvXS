// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QString>
#include <cstdint>

#include "iptvxs/models/channel.h"

namespace iptvxs {

struct ChannelGroup {
    int64_t id{0};
    QString name;
    QString kind{"static"}; // "static" or "dynamic"
    QString filterScope{"any"}; // "any", "live", "vod", "series"
    QString filterField{"name"}; // "name", "category", "server"
    QString filterOperator{"contains"}; // "contains", "not_contains", "starts_with", "equals"
    QString filterValue;
    int position{0};
    int64_t createdAt{0};
};

struct GroupMember {
    int64_t id{0};
    int64_t groupId{0};
    int64_t channelId{0};
    int position{0};
    Channel channel; // joined data
};

} // namespace iptvxs
