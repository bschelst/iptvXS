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

    onClosing: function(close) {
        if (appViewModel && appViewModel.closeToTray) {
            close.accepted = false
            window.hide()
            return
        }
        if (appViewModel && appViewModel.recordingList.activeCount > 0) {
            close.accepted = false
            closeConfirmDialog.visible = true
        }
    }

    property var viewTitles: ({
        "home": "Home",
        "channels": "Channels",
        "vod": "Video on Demand",
        "favorites": "Favorites",
        "epg": "TV Guide",
        "recordings": "Recordings",
        "history": "Play History",
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
        case "history":
            return "views/HistoryView.qml"
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

    // --- Single persistent video surface with PIP ---
    property bool _inPlayer: appViewModel && appViewModel.currentView === "player"
    property bool _playing: appViewModel && !appViewModel.player.stopped
    property bool _pipMode: _playing && !_inPlayer

    Rectangle {
        id: videoContainer
        visible: _playing
        color: "#000000"
        clip: _pipMode
        radius: _pipMode ? Theme.borderRadius : 0

        x: _pipMode ? (parent.width - 320 - Theme.spacingMd) : (sidebar.visible ? sidebar.width : 0)
        y: _pipMode ? (parent.height - 180 - Theme.spacingMd) : (topBar.visible ? topBar.height : 0)
        width: _pipMode ? 320 : (parent.width - x)
        height: _pipMode ? 180 : (parent.height - y)
        z: _pipMode ? 100 : -1

        MpvVideoItem {
            anchors.fill: parent
            player: appViewModel ? appViewModel.player.mpvPlayer : null
        }

        MouseArea {
            anchors.fill: parent
            visible: _pipMode
            cursorShape: Qt.PointingHandCursor
            onClicked: { if (appViewModel) appViewModel.currentView = "player" }
        }

        Rectangle {
            visible: _pipMode
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            width: 24; height: 24; radius: 12
            color: pipCloseHov ? Theme.error : "#80000000"
            property bool pipCloseHov: false
            z: 2

            Text {
                anchors.centerIn: parent
                text: "✕"; font.pixelSize: 12; font.bold: true; color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.pipCloseHov = true
                onExited: parent.pipCloseHov = false
                onClicked: { if (appViewModel) appViewModel.player.stop() }
            }
        }

        Rectangle {
            visible: _pipMode
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24
            color: "#a0000000"
            z: 2

            Text {
                anchors.centerIn: parent
                text: appViewModel ? appViewModel.player.channelName : ""
                font.pixelSize: 11; color: "#ffffff"
                elide: Text.ElideRight
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
            }
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

    property var navItems: ["home", "servers", "channels", "vod", "favorites", "epg", "recordings", "history", "speedtest", "settings"]

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

    Rectangle {
        id: closeConfirmDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 200

        MouseArea { anchors.fill: parent; onClicked: closeConfirmDialog.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: 400
            height: closeConfirmCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.error; border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: closeConfirmCol
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                Text {
                    text: "Recording in Progress"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: {
                        var n = appViewModel ? appViewModel.recordingList.activeCount : 0
                        return "You have " + n + " active recording" + (n > 1 ? "s" : "") +
                               ".\nClosing the app will stop all recordings."
                    }
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    lineHeight: 1.4
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: cancelCloseText.implicitWidth + 24
                        height: 36; radius: Theme.borderRadius
                        color: cancelCloseHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder; border.width: 1
                        property bool cancelCloseHov: false

                        Text { id: cancelCloseText; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.cancelCloseHov = true; onExited: parent.cancelCloseHov = false; onClicked: closeConfirmDialog.visible = false }
                    }

                    Rectangle {
                        width: quitAnywayText.implicitWidth + 24
                        height: 36; radius: Theme.borderRadius
                        color: quitHov ? Qt.darker(Theme.error, 1.2) : Theme.error
                        property bool quitHov: false

                        Text { id: quitAnywayText; anchors.centerIn: parent; text: "Quit Anyway"; font.pixelSize: Theme.fontSizeSm; font.bold: true; color: "#FFFFFF" }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.quitHov = true; onExited: parent.quitHov = false; onClicked: Qt.quit() }
                    }
                }
            }
        }
    }
}
