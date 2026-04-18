cmake_minimum_required(VERSION 3.22)

project(iptvxs
    VERSION 0.1.0
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

    install(FILES packaging/linux/io.github.bschelst.iptvxs.desktop
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/applications)

    install(FILES packaging/linux/io.github.bschelst.iptvxs.metainfo.xml
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/metainfo)

    install(FILES packaging/linux/io.github.bschelst.iptvxs.svg
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps)
endif()

set(CPACK_PACKAGE_NAME "iptvxs")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Cross-platform IPTV viewer")
set(CPACK_PACKAGE_CONTACT "Bart Schelstraete <bart.schelstraete@gmail.com>")
set(CPACK_PACKAGE_VENDOR "bschelst")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
set(CPACK_STRIP_FILES ON)

set(CPACK_DEBIAN_PACKAGE_DEPENDS
    "libqt6core6, libqt6gui6, libqt6network6, libqt6qml6, libqt6quick6, libqt6sql6, libmpv2, ffmpeg")
set(CPACK_DEBIAN_PACKAGE_SECTION "video")

set(CPACK_RPM_PACKAGE_REQUIRES
    "qt6-qtbase, qt6-qtdeclarative, mpv-libs, ffmpeg-free")
set(CPACK_RPM_PACKAGE_LICENSE "MIT")

include(CPack)
