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

    // Note: ApplicationWindow inherits Window which is NOT an Item, so the
    // `Keys` attached property cannot be used at this level. Use per-item
    // Keys handlers (HomeView, top nav, cardListView, etc.) instead.

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

    property var topNavItems: ([
        { "view": "home", "label": "Home" },
        { "view": "channels", "label": "Live TV" },
        { "view": "epg", "label": "TV Guide" },
        { "view": "recordings", "label": "Recordings" },
        { "view": "vod_movies", "label": "Films" },
        { "view": "vod_series", "label": "Series" },
        { "view": "favorites", "label": "Favorites" },
        { "view": "groups", "label": "Groups" },
        { "view": "servers", "label": "Servers" }
    ])

    function navViewForCurrentView(view) {
        if (view === "player") {
            if (appViewModel && appViewModel.player && appViewModel.player.isLive) {
                return "channels"
            }
            var prev = appViewModel ? appViewModel.previousView() : ""
            if (prev === "vod_series" || prev === "vod_movies" || prev === "recordings"
                    || prev === "history" || prev === "channels" || prev === "favorites"
                    || prev === "epg" || prev === "servers" || prev === "home") {
                return prev
            }
            return "home"
        }
        return view
    }

    function topNavIndexForView(view) {
        var navView = navViewForCurrentView(view)
        for (var i = 0; i < topNavItems.length; i++) {
            if (topNavItems[i].view === navView) {
                return i
            }
        }
        return 0
    }

    function focusTopNav() {
        if (topBar) {
            topBar.forceMenuFocus()
        }
    }

    function openSearchOverlay() {
        if (searchOverlay) {
            searchOverlay.openOverlay()
        }
    }

    function closeSearchOverlay() {
        if (searchOverlay) {
            searchOverlay.closeOverlay()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            id: topBar
            Layout.fillWidth: true
            visible: !appViewModel || !appViewModel.videoFullscreen
            menuItems: topNavItems
            activeView: navViewForCurrentView(appViewModel ? appViewModel.currentView : "home")

            onMenuActivated: function(view) {
                if (appViewModel) {
                    appViewModel.currentView = view
                }
            }
            onSpeedTestRequested: {
                if (appViewModel) appViewModel.currentView = "speedtest"
            }
            onLogRequested: {
                if (appViewModel) appViewModel.currentView = "log"
            }
            onSearchRequested: openSearchOverlay()
            onSettingsRequested: {
                if (appViewModel) appViewModel.currentView = "settings"
            }
            onLogoActivated: {
                if (appViewModel) appViewModel.currentView = "home"
            }
        }

        Item {
            id: viewContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            property string currentViewName: appViewModel ? appViewModel.currentView : "home"

            Keys.priority: Keys.AfterItem
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_PageUp) {
                    topBar.stepMenuFocus(-1)
                    event.accepted = true
                } else if (event.key === Qt.Key_PageDown) {
                    topBar.stepMenuFocus(+1)
                    event.accepted = true
                }
            }

            property var activated: ({})

            function activateView(name) {
                if (!activated[name]) {
                    var a = ({})
                    var keys = Object.keys(activated)
                    for (var i = 0; i < keys.length; i++)
                        a[keys[i]] = true
                    a[name] = true
                    activated = a
                }
            }

            function loaderFor(name) {
                switch (name) {
                case "home": return homeLoader
                case "channels": return channelsLoader
                case "epg": return epgLoader
                case "recordings": return recordingsLoader
                case "vod_movies": return vodMoviesLoader
                case "vod_series": return vodSeriesLoader
                case "favorites": return favoritesLoader
                case "groups": return groupsLoader
                case "servers": return serversLoader
                case "speedtest": return speedtestLoader
                case "settings": return settingsLoader
                case "log": return logLoader
                case "player": return playerLoader
                case "history": return historyLoader
                default: return homeLoader
                }
            }

            Loader { id: homeLoader; anchors.fill: parent; active: viewContainer.activated["home"] || viewContainer.currentViewName === "home"; visible: viewContainer.currentViewName === "home"; source: "views/HomeView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: channelsLoader; anchors.fill: parent; active: viewContainer.activated["channels"] || viewContainer.currentViewName === "channels"; visible: viewContainer.currentViewName === "channels"; source: "views/ChannelsView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: epgLoader; anchors.fill: parent; active: viewContainer.activated["epg"] || viewContainer.currentViewName === "epg"; visible: viewContainer.currentViewName === "epg"; source: "views/EpgView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: recordingsLoader; anchors.fill: parent; active: viewContainer.activated["recordings"] || viewContainer.currentViewName === "recordings"; visible: viewContainer.currentViewName === "recordings"; source: "views/RecordingsView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: vodMoviesLoader; anchors.fill: parent; active: viewContainer.activated["vod_movies"] || viewContainer.currentViewName === "vod_movies"; visible: viewContainer.currentViewName === "vod_movies"; source: "views/VodView.qml"; onLoaded: { if (item) item.initialType = "vod"; requestViewFocusRestore() } }
            Loader { id: vodSeriesLoader; anchors.fill: parent; active: viewContainer.activated["vod_series"] || viewContainer.currentViewName === "vod_series"; visible: viewContainer.currentViewName === "vod_series"; source: "views/VodView.qml"; onLoaded: { if (item) item.initialType = "series"; requestViewFocusRestore() } }
            Loader { id: favoritesLoader; anchors.fill: parent; active: viewContainer.activated["favorites"] || viewContainer.currentViewName === "favorites"; visible: viewContainer.currentViewName === "favorites"; source: "views/FavoritesView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: groupsLoader; anchors.fill: parent; active: viewContainer.activated["groups"] || viewContainer.currentViewName === "groups"; visible: viewContainer.currentViewName === "groups"; source: "views/GroupsView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: serversLoader; anchors.fill: parent; active: viewContainer.activated["servers"] || viewContainer.currentViewName === "servers"; visible: viewContainer.currentViewName === "servers"; source: "views/ServersView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: speedtestLoader; anchors.fill: parent; active: viewContainer.activated["speedtest"] || viewContainer.currentViewName === "speedtest"; visible: viewContainer.currentViewName === "speedtest"; source: "views/SpeedTestView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: settingsLoader; anchors.fill: parent; active: viewContainer.activated["settings"] || viewContainer.currentViewName === "settings"; visible: viewContainer.currentViewName === "settings"; source: "views/SettingsView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: logLoader; anchors.fill: parent; active: viewContainer.activated["log"] || viewContainer.currentViewName === "log"; visible: viewContainer.currentViewName === "log"; source: "views/LogView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: playerLoader; anchors.fill: parent; active: viewContainer.activated["player"] || viewContainer.currentViewName === "player"; visible: viewContainer.currentViewName === "player"; source: "views/PlayerView.qml"; onLoaded: requestViewFocusRestore() }
            Loader { id: historyLoader; anchors.fill: parent; active: viewContainer.activated["history"] || viewContainer.currentViewName === "history"; visible: viewContainer.currentViewName === "history"; source: "views/HistoryView.qml"; onLoaded: requestViewFocusRestore() }
        }

    }

    GlobalSearchOverlay {
        id: searchOverlay
        onClosed: {
            focusTopNav()
        }
        onResultActivated: function(result) {
            closeOverlay()
            if (appViewModel) {
                appViewModel.openSearchResult(result)
            }
        }
    }

    function focusSidebar() {
        focusTopNav()
    }

    function currentViewItem() {
        var loader = viewContainer.loaderFor(appViewModel ? appViewModel.currentView : "home")
        return loader ? loader.item : null
    }

    function focusCurrentViewPrimary() {
        var item = currentViewItem()
        if (item && item.focusPrimary) {
            item.focusPrimary()
        }
    }

    function focusCurrentViewSecondary() {
        var item = currentViewItem()
        if (item && item.focusCategorySidebar) {
            item.focusCategorySidebar()
            return
        }
        focusCurrentViewPrimary()
    }

    function loadViewForCurrentName(view) {
        viewContainer.activateView(view)
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
        var item = currentViewItem()
        if (!item) {
            if (++focusRestoreAttempts < 20) {
                focusContentTimer.restart()
            } else {
                focusRestorePending = false
            }
            return
        }

        if (item.activeFocus) {
            focusRestorePending = false
            return
        }

        if (item.requestFocusRestore) {
            item.requestFocusRestore()
        } else if (item.focusPrimary) {
            item.focusPrimary()
        }

        if (item.activeFocus) {
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
            // Whenever the user leaves the player, drop the fullscreen
            // flag so the sidebar (whose visibility is bound to
            // !videoFullscreen) reappears. Exit paths other than the
            // explicit Back button (Escape, controller B, view-switch
            // via mouse, etc.) used to leave the flag set, which made
            // the sidebar invisible after coming back to a menu view.
            if (view !== "player" && appViewModel.videoFullscreen) {
                appViewModel.videoFullscreen = false
                if (window.visibility === Window.FullScreen) {
                    window.showNormal()
                }
            }
            loadViewForCurrentName(view)
            if (searchOverlay.open) {
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
        loadViewForCurrentName("home")
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
        Keys.onLeftPressed: { if (pipMode) focusTopNav() }
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
                    x: 0
                    y: topBar.visible ? topBar.height : 0
                    width: parent.width
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
        enabled: !searchOverlay.open
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

    Shortcut {
        sequences: ["F1"]
        onActivated: topBar.stepMenuFocus(-1)
    }
    Shortcut {
        sequences: ["F2"]
        onActivated: topBar.stepMenuFocus(1)
    }

    Shortcut {
        sequences: ["Ctrl+Left"]
        onActivated: topBar.stepMenuFocus(-1)
    }
    Shortcut {
        sequences: ["Ctrl+Right"]
        onActivated: topBar.stepMenuFocus(1)
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
