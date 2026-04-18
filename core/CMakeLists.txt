add_library(iptvxs-core STATIC
    src/db/database.cpp
    src/db/settings_repository.cpp
    src/db/server_repository.cpp
    src/db/category_repository.cpp
    src/db/channel_repository.cpp
    src/net/http_client.cpp
    src/api/xtream_client.cpp
    src/api/xtream_response.cpp
    src/parser/m3u_parser.cpp
    include/iptvxs/db/database.h
    include/iptvxs/db/settings_repository.h
    include/iptvxs/db/server_repository.h
    include/iptvxs/db/category_repository.h
    include/iptvxs/db/channel_repository.h
    include/iptvxs/net/http_client.h
    include/iptvxs/api/xtream_client.h
    include/iptvxs/parser/m3u_parser.h
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
