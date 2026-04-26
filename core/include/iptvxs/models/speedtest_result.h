// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
#pragma once

#include <cstdint>

namespace iptvxs {

struct SpeedtestResult {
    double downloadMbps{0.0};
    double uploadMbps{0.0};
    int64_t latencyMs{0};
    int64_t testedAt{0};
};

} // namespace iptvxs
