// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
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

    // D-pad/focus diagnostics. Logs every focus change so we can correlate
    // with key-press logs in HomeView/Sidebar/PlayerView and pinpoint where
    // the controller's arrow events get swallowed.
    onActiveFocusItemChanged: {
        var item = activeFocusItem
        var label = "null"
        if (item) {
            label = item.objectName || ""
            if (!label) {
                var s = item.toString()
                label = s.split("(")[0] || "unnamed"
            }
        }
        console.log("[FOCUS] activeFocusItem →", label,
                    "currentView=" + (appViewModel ? appViewModel.currentView : "?"))
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
        // Window-level catch-all: only fires for keys not consumed by any
        // focused item. If a D-pad press shows up here, it means NOTHING
        // had activeFocus when the user pressed it.
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                || event.key === Qt.Key_Left || event.key === Qt.Key_Right
                || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            console.log("[DPAD/Window] uncaught key=" + event.key +
                        " text='" + event.text + "' (no focused element handled it)")
        }
    }

    onClosing: function(close) {
        if (appViewModel && appViewModel.closeToTray && systemTrayAvailable) {
            close.accepted = false
            window.hide()
            return
        }
        var hasRecordings = appViewModel && (appViewModel.recordingList.activeCount > 0 || appViewModel.player.recording)
        var hasUpload = appViewModel && appViewModel.gdrive.uploading
        if (hasRecordings || hasUpload) {
            close.accepted = false
            closeConfirmDialog.visible = true
        }
    }

    property var viewTitles: ({
        "home": "Home",
        "channels": "Live TV",
        "vod_movies": "VOD Movies",
        "vod_series": "VOD Series",
        "favorites": "Favorites",
        "groups": "Groups",
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
                title: {
                    var view = appViewModel ? appViewModel.currentView : "home"
                    if (view === "player") {
                        if (appViewModel && appViewModel.player.isLive) return "Live TV"
                        var prev = appViewModel ? appViewModel.previousView() : ""
                        if (prev === "vod_series") return "VOD Series"
                        if (prev === "vod_movies") return "VOD Movies"
                        return "Now Playing"
                    }
                    return viewTitles[view] || "Home"
                }
                visible: !appViewModel || !appViewModel.videoFullscreen

                onToggleSidebar: sidebar.collapsed = !sidebar.collapsed
            }

            Loader {
                id: viewLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: "views/HomeView.qml"
                asynchronous: false
                onLoaded: {
                    if (!sidebar.activeFocus) {
                        requestViewFocusRestore()
                    }
                }

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
        case "vod_movies":
        case "vod_series":
            return "views/VodView.qml"
        case "favorites":
            return "views/FavoritesView.qml"
        case "groups":
            return "views/GroupsView.qml"
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

    function focusSidebar() {
        if (sidebar.visible) {
            sidebar.forceActiveFocus()
        }
    }

    function focusCurrentViewPrimary() {
        if (viewLoader.item && viewLoader.item.focusPrimary) {
            viewLoader.item.focusPrimary()
        }
    }

    function focusCurrentViewSecondary() {
        if (viewLoader.item && viewLoader.item.focusCategorySidebar) {
            viewLoader.item.focusCategorySidebar()
            return
        }
        focusCurrentViewPrimary()
    }

    function loadViewForCurrentName(view) {
        var src = viewForName(view)
        if (viewLoader.source === src && viewLoader.item) {
            return
        }
        if (view === "vod_movies" || view === "vod_series") {
            viewLoader.setSource(src, { "initialType": view === "vod_series" ? "series" : "vod" })
        } else {
            viewLoader.setSource(src)
        }
    }

    property bool focusRestorePending: false
    property int focusRestoreAttempts: 0

    function requestViewFocusRestore() {
        focusRestorePending = true
        focusRestoreAttempts = 0
        focusContentTimer.restart()
    }

    function tryRestoreViewFocus() {
        if (!focusRestorePending) return
        if (!viewLoader.item) {
            if (++focusRestoreAttempts < 20) {
                focusContentTimer.restart()
            } else {
                focusRestorePending = false
            }
            return
        }

        if (viewLoader.item.requestFocusRestore) {
            viewLoader.item.requestFocusRestore()
        } else if (viewLoader.item.focusPrimary) {
            viewLoader.item.focusPrimary()
        }

        if (viewLoader.item.activeFocus) {
            focusRestorePending = false
            return
        }

        if (++focusRestoreAttempts < 20) {
            focusContentTimer.restart()
        } else {
            focusRestorePending = false
        }
    }

    Connections {
        target: appViewModel ? appViewModel.chromecast : null
        function onResumeLocal(url, title) {
            if (appViewModel) {
                appViewModel.player.play(url, title, "", 0)
            }
        }
    }

    Connections {
        target: appViewModel
        function onCurrentViewChanged() {
            var view = appViewModel.currentView
            sidebar.activeItem = view
            loadViewForCurrentName(view)
            if (sidebar.activeFocus) {
                focusRestorePending = false
                focusContentTimer.stop()
            } else {
                requestViewFocusRestore()
            }
        }
        function onDatabaseReadyChanged() {
            if (appViewModel.databaseReady) {
                var savedTheme = appViewModel.theme
                if (savedTheme) Theme.applyTheme(savedTheme)
            }
        }
    }

    Timer {
        id: focusContentTimer
        interval: 100
        onTriggered: tryRestoreViewFocus()
    }

    Component.onCompleted: {
        if (appViewModel && appViewModel.databaseReady) {
            var savedTheme = appViewModel.theme
            if (savedTheme) Theme.applyTheme(savedTheme)
        }
        requestViewFocusRestore()
    }

    // --- Single persistent video surface with PIP ---
    property bool _inPlayer: appViewModel && appViewModel.currentView === "player"
    property bool _playing: appViewModel && !appViewModel.player.stopped
    property bool _reconnecting: appViewModel && appViewModel.player.reconnecting
    property bool pipMode: _playing && !_inPlayer && !_reconnecting


        Rectangle {
            id: videoContainer
            visible: _playing
        focus: pipMode
        z: _inPlayer ? 0 : (pipMode ? 1000 : -1)
        color: "#000000"
        clip: pipMode
        radius: pipMode ? Theme.borderRadius : 0
        border.width: pipMode && activeFocus ? 2 : 0
        border.color: Theme.accent
        activeFocusOnTab: pipMode

        Keys.onReturnPressed: { if (pipMode && appViewModel) appViewModel.currentView = "player" }
        Keys.onEnterPressed: Keys.onReturnPressed(event)
        Keys.onLeftPressed: { if (pipMode) focusSidebar() }
        Keys.onRightPressed: { if (pipMode) focusCurrentViewPrimary() }
        Keys.onUpPressed: { if (pipMode) focusCurrentViewPrimary() }
        Keys.onDownPressed: { if (pipMode && pipCloseButton.visible) pipCloseButton.forceActiveFocus() }
        Keys.onPressed: function(event) {
            if (!pipMode) return
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back
                    || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                if (appViewModel) appViewModel.player.stop()
                event.accepted = true
            } else if (event.key === Qt.Key_Select) {
                if (appViewModel) appViewModel.currentView = "player"
                event.accepted = true
            }
        }

        // Default PIP corner position
        property real pipDefaultX: parent.width - 320 - Theme.spacingMd
        property real pipDefaultY: parent.height - 180 - Theme.spacingMd

        states: [
            State {
                name: "pip"
                when: pipMode
                PropertyChanges {
                    target: videoContainer
                    width: 320
                    height: 180
                    z: 100
                }
            },
            State {
                name: "fullscreen"
                when: !pipMode
                PropertyChanges {
                    target: videoContainer
                    x: sidebar.visible ? sidebar.width : 0
                    y: topBar.visible ? topBar.height : 0
                    width: parent.width - (sidebar.visible ? sidebar.width : 0)
                    height: parent.height - (topBar.visible ? topBar.height : 0)
                    z: -1
                }
            }
        ]

        Connections {
            target: window
            function onPipModeChanged() {
                if (pipMode) {
                    videoContainer.x = videoContainer.pipDefaultX
                    videoContainer.y = videoContainer.pipDefaultY
                }
            }
        }

        MpvVideoItem {
            anchors.fill: parent
            visible: !_reconnecting
            player: appViewModel ? appViewModel.player.mpvPlayer : null
        }

        Rectangle {
            id: reconnectOverlay
            anchors.fill: parent
            visible: _reconnecting
            color: "#000000"
            z: 1

            Image {
                anchors.centerIn: parent
                width: 128
                height: 128
                source: "qrc:/images/iptvxs_tray.png"
                fillMode: Image.PreserveAspectFit
                opacity: 0.18
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 84
                text: "Reconnecting..."
                font.pixelSize: Theme.fontSizeSm
                font.bold: true
                color: "#ccffffff"
            }
        }

        MouseArea {
            id: pipMouseArea
            anchors.fill: parent
            visible: pipMode
            cursorShape: Qt.PointingHandCursor
            drag.target: pipMode ? videoContainer : null
            drag.minimumX: 0
            drag.maximumX: videoContainer.parent.width - videoContainer.width
            drag.minimumY: 0
            drag.maximumY: videoContainer.parent.height - videoContainer.height
            drag.threshold: 5
            onClicked: { if (appViewModel) appViewModel.currentView = "player" }
        }

        Rectangle {
            id: pipCloseButton
            visible: pipMode
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            width: 24; height: 24; radius: 12
            color: pipCloseHov ? Theme.error : "#80000000"
            property bool pipCloseHov: false
            z: 2
            focus: false
            activeFocusOnTab: true

            Text {
                anchors.centerIn: parent
                text: "✕"; font.pixelSize: 12; font.bold: true; color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.pipCloseHov = true
                onExited: parent.pipCloseHov = false
                onClicked: {
                    if (appViewModel) {
                        appViewModel.player.stop()
                    }
                }
            }

            Keys.onReturnPressed: {
                if (appViewModel) {
                    appViewModel.player.stop()
                }
            }
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onUpPressed: { if (pipMode) videoContainer.forceActiveFocus() }
            Keys.onLeftPressed: { if (pipMode) videoContainer.forceActiveFocus() }
            Keys.onPressed: function(event) {
                if (!pipMode) return
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    Keys.onReturnPressed(event)
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back
                        || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    if (appViewModel) appViewModel.player.stop()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            visible: pipMode
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: videoContainer.activeFocus ? 44 : 24
            color: "#a0000000"
            z: 2

            Behavior on height { NumberAnimation { duration: 150 } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: appViewModel ? appViewModel.player.channelName : ""
                    font.pixelSize: 11; color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.maximumWidth: videoContainer.width - 16
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    visible: videoContainer.activeFocus
                    text: "A/Enter = Open  ·  B/Esc = Close"
                    font.pixelSize: 9; color: "#aaffffff"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    function focusPip() {
        if (pipMode) videoContainer.forceActiveFocus()
    }

    Shortcut {
        sequence: "P"
        enabled: pipMode && !_inPlayer
        onActivated: focusPip()
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
                appViewModel.player.stop()
                appViewModel.currentView = "home"
            } else if (window.visibility === Window.FullScreen) {
                window.showNormal()
            } else if (pipMode && appViewModel) {
                appViewModel.player.stop()
                return
            }
        }
    }

    property var navItems: ["home", "servers", "channels", "epg", "vod_movies", "vod_series", "favorites", "groups", "recordings", "history", "speedtest", "settings"]

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
                    text: {
                        var hasRec = appViewModel && appViewModel.recordingList.activeCount > 0
                        var hasUp = appViewModel && appViewModel.gdrive.uploading
                        if (hasRec && hasUp) return "Recording & Upload in Progress"
                        if (hasUp) return "Upload in Progress"
                        return "Recording in Progress"
                    }
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: {
                        var parts = []
                        var n = appViewModel ? appViewModel.recordingList.activeCount : 0
                        if (n > 0) parts.push("You have " + n + " active recording" + (n > 1 ? "s" : ""))
                        if (appViewModel && appViewModel.gdrive.uploading)
                            parts.push("A Google Drive upload is in progress")
                        parts.push("Closing the app will interrupt" +
                            (parts.length > 1 ? " them" : " it") +
                            ". Uploads will resume on next launch.")
                        return parts.join(".\n")
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
