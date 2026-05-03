if(WIN32)
    find_package(mpv CONFIG QUIET)
    if(NOT mpv_FOUND)
        find_path(MPV_INCLUDE_DIRS mpv/client.h)
        find_library(MPV_LIBRARIES NAMES mpv libmpv)
    endif()
    find_package(OpenSSL REQUIRED)
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(MPV REQUIRED mpv)
    pkg_check_modules(LIBSECRET REQUIRED IMPORTED_TARGET libsecret-1)
    find_package(OpenSSL REQUIRED)
endif()

add_library(iptvxs-core STATIC
    src/db/database.cpp
    src/db/settings_repository.cpp
    src/db/server_repository.cpp
    src/db/epg_source_repository.cpp
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
    src/db/category_settings_repository.cpp
    src/db/series_cache_repository.cpp
    src/cache/logo_cache.cpp
    src/cast/chromecast_manager.cpp
    src/cast/hls_proxy.cpp
    src/security/credential_vault.cpp
    include/iptvxs/db/database.h
    include/iptvxs/db/settings_repository.h
    include/iptvxs/db/server_repository.h
    include/iptvxs/db/epg_source_repository.h
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
    include/iptvxs/db/category_settings_repository.h
    include/iptvxs/db/series_cache_repository.h
    include/iptvxs/models/epg_source.h
    include/iptvxs/models/channel_group.h
    include/iptvxs/cache/logo_cache.h
    include/iptvxs/cast/chromecast_manager.h
    include/iptvxs/cast/hls_proxy.h
    include/iptvxs/security/credential_vault.h
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
# Read gateway API key from .secrets file if not provided via -D flag
set(IPTVXS_GATEWAY_API_KEY "" CACHE STRING "API key for the iptvXS gateway")
if(NOT IPTVXS_GATEWAY_API_KEY AND EXISTS "${CMAKE_SOURCE_DIR}/.secrets")
    file(STRINGS "${CMAKE_SOURCE_DIR}/.secrets" _secrets_lines)
    foreach(_line ${_secrets_lines})
        if(_line MATCHES "^IPTVXS_GATEWAY_API_KEY=(.+)$")
            set(IPTVXS_GATEWAY_API_KEY "${CMAKE_MATCH_1}" CACHE STRING "" FORCE)
        endif()
    endforeach()
endif()
set(IPTVXS_GATEWAY_URL "https://iptvxs.schelstraete.org" CACHE STRING "iptvXS gateway URL")

target_compile_definitions(iptvxs-core
    PUBLIC
        IPTVXS_GDRIVE_CLIENT_ID="${IPTVXS_GDRIVE_CLIENT_ID}"
        IPTVXS_GDRIVE_CLIENT_SECRET="${IPTVXS_GDRIVE_CLIENT_SECRET}"
        IPTVXS_GATEWAY_API_KEY="${IPTVXS_GATEWAY_API_KEY}"
        IPTVXS_GATEWAY_URL="${IPTVXS_GATEWAY_URL}"
)

target_link_libraries(iptvxs-core
    PUBLIC
        Qt6::Core
        Qt6::Sql
        Qt6::Network
        OpenSSL::Crypto
        ${MPV_LIBRARIES}
)

if(WIN32)
    target_link_libraries(iptvxs-core PUBLIC ws2_32)
    target_link_libraries(iptvxs-core PUBLIC crypt32)
else()
    target_link_libraries(iptvxs-core PUBLIC PkgConfig::LIBSECRET)
endif()
