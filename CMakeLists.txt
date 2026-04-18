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
