#pragma once

#include <QString>
#include <cstdint>

namespace iptvxs {

struct Programme {
    int64_t id{0};
    QString epgChannelId;
    QString title;
    QString description;
    int64_t startTime{0};
    int64_t endTime{0};
};

} // namespace iptvxs
