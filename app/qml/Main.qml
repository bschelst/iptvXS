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
    title: "iptvxs"
    color: Theme.background

    property var viewTitles: ({
        "home": "Home",
        "channels": "Channels",
        "favorites": "Favorites",
        "epg": "TV Guide",
        "recordings": "Recordings",
        "history": "History",
        "speedtest": "Speed Test",
        "settings": "Settings",
        "servers": "Servers"
    })

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: sidebar
            Layout.fillHeight: true

            onItemClicked: function(name) {
                if (appViewModel) {
                    appViewModel.currentView = name
                }
                viewLoader.setSource(viewForName(name))
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

                onToggleSidebar: sidebar.collapsed = !sidebar.collapsed
                onSearchTextChanged: function(text) {
                    if (appViewModel && appViewModel.channelList) {
                        appViewModel.channelList.searchQuery = text
                    }
                }
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
        case "favorites":
            return "views/FavoritesView.qml"
        case "settings":
            return "views/SettingsView.qml"
        case "player":
            return "views/PlayerView.qml"
        default:
            return "views/HomeView.qml"
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
            if (window.visibility === Window.FullScreen) {
                window.showNormal()
            }
        }
    }
}
