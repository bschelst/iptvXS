qt_policy(SET QTP0004 OLD)

qt_add_executable(iptvxs
    main.cpp
)

set_target_properties(iptvxs PROPERTIES
    QT_QML_IMPORT_NO_IMPORT_SCAN ON
)

set_source_files_properties(qml/themes/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(iptvxs
    URI app.iptvxs
    VERSION 1.0
    NO_IMPORT_SCAN
    QML_FILES
        qml/Main.qml
        qml/views/HomeView.qml
        qml/views/ServersView.qml
        qml/views/ChannelsView.qml
        qml/views/SettingsView.qml
        qml/views/PlayerView.qml
        qml/views/FavoritesView.qml
        qml/views/EpgView.qml
        qml/components/Sidebar.qml
        qml/components/TopBar.qml
        qml/components/AddServerDialog.qml
        qml/components/StyledTextField.qml
        qml/themes/Theme.qml
    SOURCES
        viewmodels/app_viewmodel.h
        viewmodels/app_viewmodel.cpp
        viewmodels/server_list_viewmodel.h
        viewmodels/server_list_viewmodel.cpp
        viewmodels/category_list_viewmodel.h
        viewmodels/category_list_viewmodel.cpp
        viewmodels/channel_list_viewmodel.h
        viewmodels/channel_list_viewmodel.cpp
        viewmodels/favorite_list_viewmodel.h
        viewmodels/favorite_list_viewmodel.cpp
        viewmodels/epg_viewmodel.h
        viewmodels/epg_viewmodel.cpp
        viewmodels/player_viewmodel.h
        viewmodels/player_viewmodel.cpp
        viewmodels/mpv_video_item.h
        viewmodels/mpv_video_item.cpp
)

target_include_directories(iptvxs
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/viewmodels
)

find_package(Qt6 REQUIRED COMPONENTS OpenGL Widgets)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED mpv)

target_include_directories(iptvxs
    PRIVATE
        ${MPV_INCLUDE_DIRS}
)

target_link_libraries(iptvxs
    PRIVATE
        iptvxs-core
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::OpenGL
        Qt6::Widgets
        ${MPV_LIBRARIES}
)

install(TARGETS iptvxs
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
