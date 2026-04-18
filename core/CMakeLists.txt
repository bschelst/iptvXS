add_library(iptvxs-core STATIC
    src/db/database.cpp
    src/db/settings_repository.cpp
    include/iptvxs/db/database.h
    include/iptvxs/db/settings_repository.h
)

target_include_directories(iptvxs-core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(iptvxs-core
    PUBLIC
        Qt6::Core
        Qt6::Sql
        Qt6::Network
)
