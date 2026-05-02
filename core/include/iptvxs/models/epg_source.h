// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <QString>
#include <cstdint>

namespace iptvxs {

struct EpgSource {
    int64_t id{0};
    QString name;
    QString url;
    int64_t lastSyncedAt{0};
    int64_t createdAt{0};
    bool enabled{true};
    bool isPrimary{false};
};

} // namespace iptvxs
