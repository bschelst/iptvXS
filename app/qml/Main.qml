import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

ApplicationWindow {
    id: window

    visible: true
    width: 1280
    height: 800
    minimumWidth: 900
    minimumHeight: 600
    title: "iptvXS"
    color: Theme.background

    property var viewTitles: ({
        "home": "Home",
        "channels": "Channels",
        "vod": "Video on Demand",
        "favorites": "Favorites",
        "epg": "TV Guide",
        "recordings": "Recordings",
        "speedtest": "Speed Test",
        "settings": "Settings",
        "servers": "Servers",
        "log": "Application Log"
    })

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.fillHeight: true
            visible: !appViewModel || !appViewModel.videoFullscreen

            onItemClicked: function(name) {
                if (appViewModel) {
                    appViewModel.currentView = name
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            TopBar {
                id: topBar
                Layout.fillWidth: true
                title: viewTitles[sidebar.activeItem] || "Home"
                visible: !appViewModel || !appViewModel.videoFullscreen

                onToggleSidebar: sidebar.collapsed = !sidebar.collapsed
            }

            Loader {
                id: viewLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "views/HomeView.qml"

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animFast
                    }
                }
            }
        }
    }

    function viewForName(name: string): string {
        switch (name) {
        case "home":
            return "views/HomeView.qml"
        case "servers":
            return "views/ServersView.qml"
        case "channels":
            return "views/ChannelsView.qml"
        case "vod":
            return "views/VodView.qml"
        case "favorites":
            return "views/FavoritesView.qml"
        case "epg":
            return "views/EpgView.qml"
        case "recordings":
            return "views/RecordingsView.qml"
        case "speedtest":
            return "views/SpeedTestView.qml"
        case "settings":
            return "views/SettingsView.qml"
        case "log":
            return "views/LogView.qml"
        case "player":
            return "views/PlayerView.qml"
        default:
            return "views/HomeView.qml"
        }
    }

    Connections {
        target: appViewModel
        function onCurrentViewChanged() {
            var view = appViewModel.currentView
            sidebar.activeItem = view
            viewLoader.setSource(viewForName(view))
        }
        function onDatabaseReadyChanged() {
            if (appViewModel.databaseReady) {
                var savedTheme = appViewModel.theme
                if (savedTheme) Theme.applyTheme(savedTheme)
            }
        }
    }

    Component.onCompleted: {
        if (appViewModel && appViewModel.databaseReady) {
            var savedTheme = appViewModel.theme
            if (savedTheme) Theme.applyTheme(savedTheme)
        }
    }

    Shortcut {
        sequence: "F11"
        onActivated: {
            if (window.visibility === Window.FullScreen) {
                window.showNormal()
            } else {
                window.showFullScreen()
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (appViewModel && appViewModel.currentView === "player") {
                var prev = appViewModel.previousView()
                if (prev && prev !== "player") {
                    appViewModel.currentView = prev
                } else {
                    appViewModel.currentView = "channels"
                }
            } else if (window.visibility === Window.FullScreen) {
                window.showNormal()
            }
        }
    }

    property var navItems: ["home", "servers", "channels", "vod", "favorites", "epg", "recordings", "speedtest", "settings"]

    Shortcut {
        sequences: ["F1"]
        onActivated: navigateSidebar(-1)
    }
    Shortcut {
        sequences: ["F2"]
        onActivated: navigateSidebar(1)
    }

    Shortcut {
        sequences: ["Ctrl+Left", "PgUp"]
        onActivated: navigateSidebar(-1)
    }
    Shortcut {
        sequences: ["Ctrl+Right", "PgDown"]
        onActivated: navigateSidebar(1)
    }

    function navigateSidebar(delta) {
        var idx = navItems.indexOf(sidebar.activeItem)
        if (idx < 0) idx = 0
        idx = Math.max(0, Math.min(navItems.length - 1, idx + delta))
        sidebar.activeItem = navItems[idx]
        if (appViewModel) appViewModel.currentView = navItems[idx]
    }
}
