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
    src/net/speed_test_runner.cpp
    src/player/mpv_player.cpp
    src/api/opensubtitles_client.cpp
    src/db/history_repository.cpp
    src/db/channel_group_repository.cpp
    src/cache/logo_cache.cpp
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
    include/iptvxs/net/speed_test_runner.h
    include/iptvxs/player/mpv_player.h
    include/iptvxs/api/opensubtitles_client.h
    include/iptvxs/db/history_repository.h
    include/iptvxs/db/channel_group_repository.h
    include/iptvxs/models/channel_group.h
    include/iptvxs/cache/logo_cache.h
)

target_include_directories(iptvxs-core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_include_directories(iptvxs-core
    PRIVATE
        ${MPV_INCLUDE_DIRS}
)

# Bundled Google Drive OAuth client ID (Desktop app type). PKCE flow — no secret.
# Override per build if forking: cmake -DIPTVXS_GDRIVE_CLIENT_ID=xxx.apps.googleusercontent.com ..
set(IPTVXS_GDRIVE_CLIENT_ID
    "703922347851-rhr3erji70jmte5n7rk3nsg8ovne4fdo.apps.googleusercontent.com"
    CACHE STRING "Google Drive OAuth 2.0 Desktop client ID")
# Google's token endpoint requires client_secret even for Desktop clients that
# use PKCE. Google's own docs note the secret "is not treated as a secret" for
# installed apps — the real protection comes from PKCE's code_verifier.
set(IPTVXS_GDRIVE_CLIENT_SECRET
    "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"
    CACHE STRING "Google Drive OAuth 2.0 Desktop client secret (non-confidential for Desktop clients)")
target_compile_definitions(iptvxs-core
    PUBLIC
        IPTVXS_GDRIVE_CLIENT_ID="${IPTVXS_GDRIVE_CLIENT_ID}"
        IPTVXS_GDRIVE_CLIENT_SECRET="${IPTVXS_GDRIVE_CLIENT_SECRET}"
)

target_link_libraries(iptvxs-core
    PUBLIC
        Qt6::Core
        Qt6::Sql
        Qt6::Network
        ${MPV_LIBRARIES}
)
