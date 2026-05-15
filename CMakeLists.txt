cmake_minimum_required(VERSION 3.22)

find_package(Git QUIET)
set(IPTVXS_VERSION "0.4.1")
if(GIT_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" describe --tags --match "v*" --abbrev=0
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE IPTVXS_GIT_TAG
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(IPTVXS_GIT_TAG MATCHES "^v([0-9]+\\.[0-9]+\\.[0-9]+)$")
        set(IPTVXS_VERSION "${CMAKE_MATCH_1}")
    endif()
endif()

project(iptvxs
    VERSION ${IPTVXS_VERSION}
    DESCRIPTION "Cross-platform IPTV viewer"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(Qt6 6.5 REQUIRED COMPONENTS
    Core
    Sql
    Network
    Quick
    QuickControls2
    Concurrent
)

qt_standard_project_setup(REQUIRES 6.5)

option(IPTVXS_BUILD_TESTS "Build unit tests" ON)

add_subdirectory(core)
add_subdirectory(app)

if(IPTVXS_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)
    string(TIMESTAMP IPTVXS_RELEASE_DATE "%Y-%m-%d" UTC)
    set(IPTVXS_RELEASE_NOTES_SUMMARY "Built from git tag v${IPTVXS_VERSION}.")
    set(IPTVXS_RELEASE_NOTES "      <li>Built from git tag v${IPTVXS_VERSION}.</li>")
    configure_file(
        packaging/linux/org.schelstraete.iptvxs.metainfo.xml.in
        ${CMAKE_CURRENT_BINARY_DIR}/packaging/linux/org.schelstraete.iptvxs.metainfo.xml
        @ONLY
    )

    install(FILES packaging/linux/org.schelstraete.iptvxs.desktop
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)

    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/packaging/linux/org.schelstraete.iptvxs.metainfo.xml
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/metainfo)

    install(FILES packaging/linux/org.schelstraete.iptvxs.svg
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps)
    install(FILES packaging/linux/org.schelstraete.iptvxs.png
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/256x256/apps)
endif()

set(CPACK_PACKAGE_NAME "iptvxs")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Cross-platform IPTV viewer")
set(CPACK_PACKAGE_CONTACT "Schelstraete Bart <bart@schelstraete.org>")
set(CPACK_PACKAGE_VENDOR "bschelst")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
set(CPACK_STRIP_FILES ON)

set(CPACK_DEBIAN_PACKAGE_DEPENDS
    "libqt6core6, libqt6gui6, libqt6network6, libqt6qml6, libqt6quick6, libqt6sql6, libmpv2, ffmpeg")
set(CPACK_DEBIAN_PACKAGE_SECTION "video")

set(CPACK_RPM_PACKAGE_REQUIRES
    "qt6-qtbase, qt6-qtdeclarative, mpv-libs, ffmpeg-free")
set(CPACK_RPM_PACKAGE_LICENSE "GPL-3.0")

include(CPack)
