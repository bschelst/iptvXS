// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QString>
#include <cstdint>

#include "iptvxs/models/channel.h"

namespace iptvxs {

struct ChannelGroup {
    int64_t id{0};
    QString name;
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
