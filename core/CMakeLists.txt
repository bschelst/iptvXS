find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED mpv)

add_library(iptvxs-core STATIC
    src/db/database.cpp
    src/db/settings_repository.cpp
    src/db/server_repository.cpp
    src/db/category_repository.cpp
    src/db/channel_repository.cpp
    src/db/favorite_repository.cpp
    src/net/http_client.cpp
    src/api/xtream_client.cpp
    src/api/xtream_response.cpp
    src/parser/m3u_parser.cpp
    src/parser/xmltv_parser.cpp
    src/db/programme_repository.cpp
    src/db/recording_repository.cpp
    src/recording/recording_manager.cpp
    src/gdrive/gdrive_auth.cpp
    src/gdrive/gdrive_uploader.cpp
    src/player/mpv_player.cpp
    include/iptvxs/db/database.h
    include/iptvxs/db/settings_repository.h
    include/iptvxs/db/server_repository.h
    include/iptvxs/db/category_repository.h
    include/iptvxs/db/channel_repository.h
    include/iptvxs/db/favorite_repository.h
    include/iptvxs/net/http_client.h
    include/iptvxs/api/xtream_client.h
    include/iptvxs/parser/m3u_parser.h
    include/iptvxs/parser/xmltv_parser.h
    include/iptvxs/db/programme_repository.h
    include/iptvxs/db/recording_repository.h
    include/iptvxs/recording/recording_manager.h
    include/iptvxs/gdrive/gdrive_auth.h
    include/iptvxs/gdrive/gdrive_uploader.h
    include/iptvxs/player/mpv_player.h
)

target_include_directories(iptvxs-core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_include_directories(iptvxs-core
    PRIVATE
        ${MPV_INCLUDE_DIRS}
)

target_link_libraries(iptvxs-core
    PUBLIC
        Qt6::Core
        Qt6::Sql
        Qt6::Network
        ${MPV_LIBRARIES}
)
