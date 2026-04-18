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
        qml/components/Sidebar.qml
        qml/components/TopBar.qml
        qml/themes/Theme.qml
    SOURCES
        viewmodels/app_viewmodel.h
        viewmodels/app_viewmodel.cpp
)

target_include_directories(iptvxs
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/viewmodels
)

target_link_libraries(iptvxs
    PRIVATE
        iptvxs-core
        Qt6::Quick
        Qt6::QuickControls2
)

install(TARGETS iptvxs
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
