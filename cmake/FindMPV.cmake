find_package(PkgConfig QUIET)

if(PkgConfig_FOUND)
    pkg_check_modules(PC_MPV QUIET mpv)
endif()

find_path(MPV_INCLUDE_DIR
    NAMES mpv/client.h
    HINTS ${PC_MPV_INCLUDE_DIRS}
    PATHS /usr/include /usr/local/include
)

find_library(MPV_LIBRARY
    NAMES mpv
    HINTS ${PC_MPV_LIBRARY_DIRS}
    PATHS /usr/lib /usr/local/lib /usr/lib/x86_64-linux-gnu
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(MPV
    REQUIRED_VARS MPV_LIBRARY MPV_INCLUDE_DIR
)

if(MPV_FOUND AND NOT TARGET MPV::MPV)
    add_library(MPV::MPV UNKNOWN IMPORTED)
    set_target_properties(MPV::MPV PROPERTIES
        IMPORTED_LOCATION "${MPV_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${MPV_INCLUDE_DIR}"
    )
endif()

mark_as_advanced(MPV_INCLUDE_DIR MPV_LIBRARY)
