// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: homeView

    // --- Row-level focus tracking ---
    property int currentRowIndex: 0
    property bool focusRestorePending: false
    property int focusRestoreAttempts: 0
    property bool continueWatchingReady: false
    property int homeRevealStage: -1
    readonly property var allRows: [continueWatchingRow, favoritesRow, recentlyAddedRow, quickAccessRow]

    readonly property bool anyRowFocused: {
        for (var i = 0; i < allRows.length; i++) {
            var r = allRows[i]
            if (r && r.cardListView && r.cardListView.activeFocus) return true
        }
        return false
    }

    function startRowRevealSequence() {
        homeRevealStage = 0
        homeRevealTimer.restart()
    }

    function snapRowToFirstCard(row) {
        if (!row || !row.cardListView) return
        if (row.cardListView.count > 0) {
            row.cardListView.currentIndex = 0
            row.cardListView.positionViewAtIndex(0, ListView.Beginning)
            row.cardListView.contentX = -row.cardListView.leftMargin
        }
    }

    function focusFirstAvailableRow() {
        for (var i = 0; i < allRows.length; i++) {
            var row = allRows[i]
            if (row && row.visible && row.enabled && row.cardListView && row.cardListView.count > 0) {
                currentRowIndex = i
                snapRowToFirstCard(row)
                row.cardListView.forceActiveFocus()
                return true
            }
        }
        return false
    }

    function focusPrimary() {
        currentRowIndex = 0
        homeView.forceActiveFocus()
        if (!continueWatchingReady) {
            requestFocusRestore()
            return
        }
        focusFirstAvailableRow()
    }

    function requestFocusRestore() {
        focusRestorePending = true
        focusRestoreAttempts = 0
        focusRestoreTimer.restart()
    }

    function tryRestoreFocus() {
        if (!focusRestorePending) return
        if (!appViewModel || appViewModel.currentView !== "home") {
            focusRestorePending = false
            return
        }

        if (homeView.activeFocus || anyRowFocused) {
            focusRestorePending = false
            return
        }

        if (!continueWatchingReady) {
            if (++focusRestoreAttempts < 40) {
                focusRestoreTimer.restart()
            } else {
                focusRestorePending = false
            }
            return
        }

        if (focusFirstAvailableRow()) {
            focusRestorePending = false
            return
        }

        if (++focusRestoreAttempts < 20) {
            focusRestoreTimer.restart()
        } else {
            focusRestorePending = false
        }
    }

    function openOrPlayChannel(channelId) {
        if (!appViewModel || channelId <= 0) return
        var ch = appViewModel.channelInfo(channelId)
        if (ch.type === "series" && ch.externalId) {
            var vm = appViewModel
            vm.setActiveSeriesDialog(ch.name, ch.serverId, ch.externalId, ch.logoUrl, channelId)
            vm.currentView = "player"
            vm.fetchSeriesEpisodes(ch.serverId, ch.externalId, ch.name, ch.logoUrl)
        } else {
            appViewModel.playChannelById(channelId)
        }
    }

    function mediaTypeIcon(type) {
        if (type === "live") return "▭"
        if (type === "series") return "◫"
        if (type === "vod" || type === "movie") return "▶"
        return ""
    }

    function focusCurrentRow() {
        var rows = allRows
        if (currentRowIndex >= 0 && currentRowIndex < rows.length) {
            var r = rows[currentRowIndex]
            if (r && r.visible && r.enabled) {
                snapRowToFirstCard(r)
                r.cardListView.forceActiveFocus()
                return
            }
        }
        // Fall back to first visible row
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].visible && rows[i].enabled && rows[i].cardListView && rows[i].cardListView.count > 0) {
                currentRowIndex = i
                snapRowToFirstCard(rows[i])
                rows[i].cardListView.forceActiveFocus()
                return
            }
        }
    }

    function focusAdjacentRow(fromRow, cardIndex, direction) {
        var rows = allRows
        var target = fromRow + direction
        while (target >= 0 && target < rows.length) {
            var row = rows[target]
            if (row && row.visible && row.enabled && row.cardListView && row.cardListView.count > 0) {
                currentRowIndex = target
                snapRowToFirstCard(row)
                row.cardListView.forceActiveFocus()
                ensureRowVisible(target)
                return
            }
            target += direction
        }
        if (direction < 0 && Window.window && Window.window.focusSidebar) {
            Window.window.focusSidebar()
        }
    }

    function ensureRowVisible(rowIdx) {
        var rows = allRows
        if (rowIdx < 0 || rowIdx >= rows.length) return
        var row = rows[rowIdx]
        if (!row) return
        var rowY = row.mapToItem(homeColumn, 0, 0).y
        var rowH = row.height
        var viewH = homeFlickable.height
        var cy = homeFlickable.contentY
        if (rowY < cy) {
            homeFlickable.contentY = Math.max(0, rowY - 8)
        } else if (rowY + rowH > cy + viewH) {
            homeFlickable.contentY = rowY + rowH - viewH + 8
        }
    }

    focus: true

    Keys.onUpPressed: focusAdjacentRow(currentRowIndex, 0, -1)
    Keys.onDownPressed: focusAdjacentRow(currentRowIndex, 0, 1)
    Keys.onReturnPressed: focusCurrentRow()
    Keys.onEnterPressed: focusCurrentRow()

    // --- Recently-added filter lifecycle ---
    property bool recentlyAddedReady: false
    Component.onCompleted: {
        if (appViewModel && appViewModel.channelList) {
            appViewModel.channelList.recentlyAddedFilter = true
            recentlyAddedReady = true
        }
        cwPopulateTimer.start()
        requestFocusRestore()
    }
    onContinueWatchingReadyChanged: {
        if (continueWatchingReady) {
            startRowRevealSequence()
        }
    }
    Component.onDestruction: {
        if (appViewModel && appViewModel.channelList) {
            appViewModel.channelList.recentlyAddedFilter = false
        }
        focusRestorePending = false
        continueWatchingReady = false
        homeRevealTimer.stop()
        cwPopulateTimer.stop()
        focusRestoreTimer.stop()
    }

    // ======================================================================
    //  Main scrollable area
    // ======================================================================
    Flickable {
        id: homeFlickable
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: homeColumn.implicitHeight + Theme.spacingXl * 2
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Behavior on contentY {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ScrollBar.vertical: ScrollBar {
            active: true
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 6; radius: 3
                color: Theme.accent
                opacity: parent.active ? 0.8 : 0.0
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
            }
            background: Rectangle { implicitWidth: 6; color: "transparent" }
        }

        Column {
            id: homeColumn
            width: parent.width
            topPadding: Theme.spacingLg
            bottomPadding: Theme.spacingLg
            spacing: Theme.spacingMd

            // ============ Compact welcome header ============
            Item {
                width: parent.width
                height: 56

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingXl
                    anchors.rightMargin: Theme.spacingXl
                    spacing: Theme.spacingMd

                    Image {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        source: "qrc:/images/iptvxs_tray.png"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.7
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Welcome to iptvXS"
                            font.pixelSize: Theme.fontSizeLg
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Live TV, VOD & recordings \u2014 all in one"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        id: statsRow
                        spacing: 6
                        visible: appViewModel && appViewModel.databaseReady

                        property int statsRevision: 0

                        Connections {
                            target: appViewModel ? appViewModel.serverList : null
                            function onCountChanged() { statsRow.statsRevision++ }
                            function onSyncFinished() { statsRow.statsRevision++ }
                            function onDataChanged() { statsRow.statsRevision++ }
                        }
                        Connections {
                            target: appViewModel ? appViewModel.favoriteList : null
                            function onCountChanged() { statsRow.statsRevision++ }
                        }
                        Connections {
                            target: appViewModel ? appViewModel.recordingList : null
                            function onCountChanged() { statsRow.statsRevision++ }
                        }

                        Repeater {
                            model: {
                                var _ = statsRow.statsRevision
                                if (!appViewModel || !appViewModel.databaseReady) return []
                                var s = appViewModel.databaseStats()
                                var items = []
                                if (s.channels > 0) items.push({ icon: "▭", value: s.channels, label: "channels" })
                                if (s.movies > 0) items.push({ icon: "▶", value: s.movies, label: "movies" })
                                if (s.series > 0) items.push({ icon: "◫", value: s.series, label: "series" })
                                if (s.favourites > 0) items.push({ icon: "★", value: s.favourites, label: "favorites" })
                                if (s.recordings > 0) items.push({ icon: "●", value: s.recordings, label: "recordings" })
                                return items
                            }

                            Rectangle {
                                height: 28
                                width: statRow.implicitWidth + 14
                                radius: 14
                                color: Theme.surfaceElevated
                                border.color: Theme.surfaceBorder
                                border.width: 1

                                Row {
                                    id: statRow
                                    anchors.centerIn: parent
                                    spacing: 4

                    Text {
                        text: modelData.icon
                        font.pixelSize: 11
                        font.family: "DejaVu Sans"
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                                    Text {
                                        text: modelData.value.toLocaleString()
                                        font.pixelSize: Theme.fontSizeXs
                                        font.bold: true
                                        color: Theme.textPrimary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textMuted
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ============ Row 1: Continue Watching ============
            HomeCardRow {
                id: continueWatchingRow
                width: parent.width
                rowIndex: 0
                rowTitle: "Continue Watching"
                rowHeight: 240
                cardWidth: 158
                cardHeight: 232
                listModel: continueWatchingModel
                isHistory: true
                visible: continueWatchingModel.count > 0
                revealed: continueWatchingReady && homeRevealStage >= 0

            }

            // ============ Row 2: Your Favorites ============
            HomeCardRow {
                id: favoritesRow
                width: parent.width
                rowIndex: 1
                rowTitle: "Your Favorites"
                rowHeight: 240
                cardWidth: 158
                cardHeight: 232
                listModel: appViewModel ? appViewModel.favoriteList : null
                visible: appViewModel && appViewModel.favoriteList && appViewModel.favoriteList.count > 0
                revealed: continueWatchingReady && homeRevealStage >= 1

            }

            // ============ Row 3: Recently Added ============
            HomeCardRow {
                id: recentlyAddedRow
                width: parent.width
                rowIndex: 2
                rowTitle: "Recently Added"
                rowHeight: 240
                cardWidth: 158
                cardHeight: 232
                listModel: recentlyAddedReady && appViewModel ? appViewModel.channelList : null
                visible: recentlyAddedReady && appViewModel && appViewModel.channelList && appViewModel.channelList.count > 0
                revealed: continueWatchingReady && homeRevealStage >= 2

            }

            // ============ Row 4: Quick Access ============
            HomeCardRow {
                id: quickAccessRow
                width: parent.width
                rowIndex: 3
                rowTitle: "Quick Access"
                rowHeight: 120
                cardWidth: 160
                cardHeight: 112
                listModel: quickAccessModel
                isQuickAccess: true
                visible: true
                revealed: continueWatchingReady && homeRevealStage >= 3

            }

            // ============ Bottom status bar ============
            Item {
                width: parent.width
                height: 32

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingXl
                    anchors.rightMargin: Theme.spacingXl
                    spacing: Theme.spacingSm

                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        radius: 4
                        color: Theme.success
                    }

                    Text {
                        text: "Database ready"
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "v" + (appViewModel ? appViewModel.appVersion : "0.1.0")
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ======================================================================
    //  Continue-watching proxy model (VOD/series only, max 20)
    // ======================================================================
    ListModel {
        id: continueWatchingModel
    }

    Timer {
        id: cwPopulateTimer
        interval: 100
        onTriggered: populateContinueWatching()
    }

    Connections {
        target: appViewModel ? appViewModel.history : null
        function onCountChanged() {
            cwPopulateTimer.restart()
            if (focusRestorePending) requestFocusRestore()
        }
    }

    function populateContinueWatching() {
        continueWatchingModel.clear()
        if (!appViewModel || !appViewModel.history) {
            continueWatchingReady = true
            return
        }
        var hist = appViewModel.history
        var added = 0
        var seen = {}
        for (var i = 0; i < hist.count && added < 20; i++) {
            var idx = hist.index(i, 0)
            var cType = hist.data(idx, 261)   // ChannelTypeRole (UserRole+5)
            var posSecs = hist.data(idx, 265) || 0      // PositionSecsRole
            var totalDur = hist.data(idx, 266) || 0     // TotalDurationSecsRole
            var channelId = hist.data(idx, 258)  // ChannelIdRole (UserRole+2)
            var streamUrl = hist.data(idx, 264)  // StreamUrlRole
            var isFinished = totalDur > 0 && posSecs >= totalDur * 0.95

            // Series: dedup by series id so only the latest in-progress episode appears.
            // Others: dedup by channelId or URL.
            var dedupeKey = cType === "series"
                ? "series:" + channelId
                : ((!channelId || channelId <= 0) ? "url:" + streamUrl : "id:" + channelId)
            if (seen[dedupeKey]) continue

            if (cType !== "series" && isFinished) {
                seen[dedupeKey] = true
                continue
            }

            seen[dedupeKey] = true
            if (cType === "series" && isFinished) continue
            continueWatchingModel.append({
                channelId:   channelId,
                channelName: hist.data(idx, 259),  // ChannelNameRole (UserRole+3)
                channelLogo: hist.data(idx, 260),  // ChannelLogoRole (UserRole+4)
                channelType: cType,
                streamUrl:   hist.data(idx, 264),  // StreamUrlRole (UserRole+8)
                duration:    hist.data(idx, 263) || 0, // DurationRole (UserRole+7)
                positionSecs: posSecs,
                totalDurationSecs: totalDur,
                historyId: hist.data(idx, 257)      // IdRole
            })
            added++
        }
        continueWatchingReady = true
        if (continueWatchingRow && continueWatchingRow.cardListView) {
            if (continueWatchingModel.count > 0) {
                continueWatchingRow.cardListView.currentIndex = 0
            } else {
                continueWatchingRow.cardListView.currentIndex = -1
            }
        }
        if (focusRestorePending) requestFocusRestore()
    }

    Timer {
        id: focusRestoreTimer
        interval: 75
        repeat: false
        onTriggered: homeView.tryRestoreFocus()
    }

    Timer {
        id: homeRevealTimer
        interval: 80
        repeat: true
        onTriggered: {
            if (homeRevealStage < 3) {
                homeRevealStage++
            }
            if (homeRevealStage >= 3) {
                homeRevealTimer.stop()
            }
            if (focusRestorePending) {
                focusRestoreTimer.restart()
            }
        }
    }

    // ======================================================================
    //  Quick access model
    // ======================================================================
    ListModel {
        id: quickAccessModel
        ListElement { title: "Add Server";      desc: "Connect to Xtream or M3U"; icon: "\u2194";       target: "servers";    accentR: 0.424; accentG: 0.361; accentB: 0.906 }
        ListElement { title: "Browse Channels"; desc: "Explore your library";      icon: "\u25AD";       target: "channels";   accentR: 0.0;   accentG: 0.808; accentB: 0.788 }
        ListElement { title: "Groups";          desc: "Organize your channels";    icon: "\u26D1";       target: "groups";     accentR: 0.600; accentG: 0.420; accentB: 0.950 }
        ListElement { title: "TV Guide";        desc: "Check what's on now";       icon: "\u25A6";       target: "epg";        accentR: 0.992; accentG: 0.475; accentB: 0.659 }
        ListElement { title: "Recordings";      desc: "Manage your recordings";    icon: "\u25CF";       target: "recordings"; accentR: 1.0;   accentG: 0.420; accentB: 0.420 }
        ListElement { title: "Speed Test";      desc: "Check your connection";     icon: "\u21AF";       target: "speedtest";  accentR: 0.992; accentG: 0.796; accentB: 0.431 }
        ListElement { title: "Settings";        desc: "Customize your experience"; icon: "\u2699";       target: "settings";   accentR: 0.635; accentG: 0.608; accentB: 0.996 }
    }

    // ======================================================================
    //  HomeCardRow — inline component for a single horizontal row
    // ======================================================================
    component HomeCardRow: Column {
        id: cardRow
        spacing: Theme.spacingSm

        required property int rowIndex
        required property string rowTitle
        required property int rowHeight
        required property int cardWidth
        required property int cardHeight
        property var listModel: null
        property bool isQuickAccess: false
        property bool isHistory: false
        property bool revealed: false
        property alias cardListView: cardLv

        opacity: revealed ? 1.0 : 0.0
        enabled: revealed
        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        function snapCardList(direction) {
            if (!cardLv || cardLv.count <= 0) return

            var step = cardWidth + cardLv.spacing
            if (step <= 0) return

            var minX = -cardLv.leftMargin
            var maxX = Math.max(minX, cardLv.contentWidth - cardLv.width + cardLv.rightMargin)
            var maxBoundary = minX + Math.floor((maxX - minX) / step) * step
            var current = cardLv.contentX
            var target

            if (direction < 0) {
                target = minX + Math.floor((current - minX - 0.001) / step) * step
            } else {
                target = minX + Math.ceil((current - minX + 0.001) / step) * step
            }

            target = Math.max(minX, Math.min(maxBoundary, target))
            cardLv.contentX = target
        }

        function activateCard(idx) {
            cardLv.currentIndex = idx
            cardLv.forceActiveFocus()
            cardLv.activateCurrentCard()
        }

        // --- Section header ---
        Item {
            width: cardRow.width
            height: 36

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingXl
                anchors.verticalCenter: parent.verticalCenter
                text: cardRow.rowTitle
                font.pixelSize: Theme.fontSizeMd
                font.bold: true
                color: Theme.textPrimary
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingXl
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: cardLv.contentWidth > cardLv.width - cardLv.leftMargin - cardLv.rightMargin

                Rectangle {
                    id: rowScrollLeftBtn
                    width: 28; height: 28; radius: 14
                    color: slHov || rowScrollLeftBtn.activeFocus ? Theme.surfaceHover : "transparent"
                    property bool slHov: false
                    focus: false
                    activeFocusOnTab: true

                    Text {
                        anchors.centerIn: parent; text: "\u2039"
                        font.pixelSize: 22; font.bold: true
                        color: parent.slHov ? Theme.textPrimary : Theme.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: parent.slHov = true; onExited: parent.slHov = false
                        onClicked: cardRow.snapCardList(-1)
                    }

                    Keys.onRightPressed: {
                        if (rowScrollRightBtn) rowScrollRightBtn.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (cardLv.count > 0) {
                            if (cardLv.currentIndex < 0) cardLv.currentIndex = 0
                            cardLv.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: cardRow.snapCardList(-1)
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            cardRow.snapCardList(-1)
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: rowScrollRightBtn
                    width: 28; height: 28; radius: 14
                    color: srHov || rowScrollRightBtn.activeFocus ? Theme.surfaceHover : "transparent"
                    property bool srHov: false
                    focus: false
                    activeFocusOnTab: true

                    Text {
                        anchors.centerIn: parent; text: "\u203A"
                        font.pixelSize: 22; font.bold: true
                        color: parent.srHov ? Theme.textPrimary : Theme.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: parent.srHov = true; onExited: parent.srHov = false
                        onClicked: cardRow.snapCardList(1)
                    }

                    Keys.onLeftPressed: {
                        if (rowScrollLeftBtn) rowScrollLeftBtn.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (cardLv.count > 0) {
                            if (cardLv.currentIndex < 0) cardLv.currentIndex = 0
                            cardLv.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: cardRow.snapCardList(1)
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            cardRow.snapCardList(1)
                            event.accepted = true
                        }
                    }
                }
            }
        }

        // --- Horizontal card list ---
        ListView {
            id: cardLv
            width: cardRow.width
            height: cardRow.rowHeight
            orientation: ListView.Horizontal
            spacing: Theme.spacingSm
            clip: true
            leftMargin: Theme.spacingXl
            rightMargin: Theme.spacingXl * 2 + 40
            contentX: -leftMargin
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            currentIndex: -1
            highlightMoveDuration: 150

            model: cardRow.listModel

            onCountChanged: {
                if (count <= 0) {
                    currentIndex = -1
                } else if (currentIndex < 0 || currentIndex >= count) {
                    currentIndex = 0
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }
            }

            onActiveFocusChanged: {
                if (activeFocus && count > 0 && (currentIndex < 0 || currentIndex >= count)) {
                    currentIndex = 0
                }
                if (activeFocus && currentIndex >= 0) {
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }
            }

            Keys.onReturnPressed: activateCurrentCard()
            Keys.onEnterPressed: activateCurrentCard()
            Keys.onLeftPressed: {
                if (currentIndex > 0) {
                    currentIndex--
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }
                else if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
            }
            Keys.onRightPressed: {
                if (currentIndex < count - 1) {
                    currentIndex++
                    positionViewAtIndex(currentIndex, ListView.Contain)
                }
            }
            Keys.onUpPressed: homeView.focusAdjacentRow(cardRow.rowIndex, currentIndex, -1)
            Keys.onDownPressed: homeView.focusAdjacentRow(cardRow.rowIndex, currentIndex, 1)
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                    activateCurrentCard()
                    event.accepted = true
                }
            }

            function activateCurrentCard() {
                if (currentIndex < 0 || !appViewModel) return
                if (cardRow.isQuickAccess) {
                    var qa = quickAccessModel.get(currentIndex)
                    if (qa) appViewModel.currentView = qa.target
                    return
                }
                if (cardRow.isHistory) {
                    var hItem = continueWatchingModel.get(currentIndex)
                    if (!hItem) return
                    if ((hItem.channelType || "") === "live") {
                        var liveItems = []
                        for (var i = 0; i < continueWatchingModel.count; i++) {
                            var li = continueWatchingModel.get(i)
                            if (!li || (li.channelType || "") !== "live") continue
                            liveItems.push({
                                channelId: li.channelId,
                                name: li.channelName,
                                streamUrl: li.streamUrl,
                                logoUrl: li.channelLogo,
                                type: li.channelType,
                                epgChannelId: ""
                            })
                        }
                        if (liveItems.length > 0) {
                            appViewModel.setZapContext(liveItems, hItem.channelId, "Continue Watching")
                        } else {
                            appViewModel.clearZapContext()
                        }
                    } else {
                        appViewModel.clearZapContext()
                    }
                    appViewModel.playHistoryEntry(hItem.historyId)
                    return
                }
                var item = currentItem
                if (item && item.itemChannelId) {
                    homeView.openOrPlayChannel(item.itemChannelId)
                }
            }

            delegate: cardRow.isQuickAccess ? quickAccessCardComp : posterCardComp
        }
    }

    // ======================================================================
    //  Poster card delegate
    // ======================================================================
    Component {
        id: posterCardComp

        Item {
            id: posterDelegate
            width: 158
            height: 232

            // Expose channelId for activateCurrentCard
            property var itemChannelId: model.channelId || 0
            property bool cardHovered: false

            Rectangle {
                id: posterCard
                anchors.fill: parent
                anchors.margins: 4
                radius: 10
                color: posterDelegate.cardHovered ? Theme.surfaceHover : Theme.surfaceElevated
                clip: true

                // Poster image area
                Rectangle {
                    id: posterImgArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height - 52
                    color: "transparent"

                    Image {
                        id: posterImg
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: parent.height - 12
                        source: model.channelLogo || model.logoUrl || ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Image {
                        visible: posterImg.status !== Image.Ready
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 48
                        height: width
                        source: "qrc:/images/iptvxs_tray.png"
                        fillMode: Image.PreserveAspectFit
                        asynchronous: false
                        cache: true
                        opacity: 0.3
                    }
                }

                // Progress bar for continue-watching items
                Rectangle {
                    visible: (model.totalDurationSecs || 0) > 0
                    anchors.bottom: posterImgArea.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 3
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)

                    Rectangle {
                        width: parent.width * Math.min(1.0, (model.positionSecs || 0) / Math.max(1, model.totalDurationSecs || 1))
                        height: parent.height
                        color: Theme.accent
                        radius: 1
                    }
                }

                Rectangle {
                    visible: mediaTypeIcon(model.channelType || model.type || "") !== ""
                    anchors.top: posterCard.top
                    anchors.left: posterCard.left
                    anchors.margins: 10
                    width: 26
                    height: 26
                    radius: 13
                    color: "#C0000000"
                    z: 200

                    Text {
                        anchors.centerIn: parent
                        text: mediaTypeIcon(model.channelType || model.type || "")
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "DejaVu Sans"
                        color: "#ffffff"
                    }
                }

                // Catchup / timeshift indicator (server-side archive)
                Rectangle {
                    visible: (model.tvArchive || 0) > 0
                    anchors.top: posterCard.top
                    anchors.right: posterCard.right
                    anchors.margins: 10
                    width: 26
                    height: 26
                    radius: 13
                    color: "#C0000000"
                    z: 200

                    Text {
                        anchors.centerIn: parent
                        text: "↻"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "DejaVu Sans"
                        color: "#ffffff"
                    }
                }

                // Title area
                Item {
                    anchors.top: posterImgArea.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        text: model.channelName || model.name || ""
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

            }

            // Single hover/click area covering entire delegate
            MouseArea {
                id: posterMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: posterDelegate.cardHovered = true
                onExited: posterDelegate.cardHovered = false
                onClicked: function(mouse) {
                    // Check if click is on the ✓ button area (top-right corner)
                    var btnRight = posterDelegate.width - 4   // posterCard right edge
                    var btnLeft = btnRight - 36               // 26px button + 10px margin
                    var btnTop = 4                            // posterCard top + margin
                    var btnBottom = btnTop + 36               // 26px button + 10px margin
                    if ((model.historyId || 0) > 0
                            && mouse.x >= btnLeft && mouse.x <= btnRight
                            && mouse.y >= btnTop && mouse.y <= btnBottom) {
                        if (appViewModel) {
                            appViewModel.history.markFinished(Number(model.historyId))
                            cwPopulateTimer.restart()
                        }
                        return
                    }
                    // Normal card click — play the content
                    var node = posterDelegate.parent
                    while (node && !node.activateCard) node = node.parent
                    if (node) node.activateCard(index)
                }
            }

            // Focus/hover border.
            Rectangle {
                anchors.fill: posterCard
                radius: posterCard.radius
                color: "transparent"
                border.width: {
                    var lv = posterDelegate.ListView.view
                    return ((lv && lv.activeFocus && lv.currentIndex === index) || posterDelegate.cardHovered) ? 2 : 1
                }
                border.color: {
                    var lv = posterDelegate.ListView.view
                    if (posterDelegate.cardHovered) {
                        return Theme.accent
                    }
                    if (lv && lv.activeFocus) {
                        return lv.currentIndex === index ? Theme.accent : Theme.surfaceBorder
                    }
                    return Theme.surfaceBorder
                }
                z: 100
            }

            // Mark as finished icon (visual only — click handled by posterMouseArea)
            Rectangle {
                visible: {
                    var lv = posterDelegate.ListView.view
                    return (model.historyId || 0) > 0
                        && (((lv && lv.activeFocus && lv.currentIndex === index) || posterDelegate.cardHovered))
                }
                anchors.top: posterCard.top
                anchors.right: posterCard.right
                anchors.margins: 10
                width: 26; height: 26; radius: 13
                color: "#C0000000"
                z: 200

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                }
            }
        }
    }

    // ======================================================================
    //  Quick access card delegate
    // ======================================================================
    Component {
        id: quickAccessCardComp

        Item {
            id: qaDelegate
            width: 160
            height: 112

            property var itemChannelId: 0
            property bool cardHovered: false

            Rectangle {
                id: qaCard
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.borderRadius
                color: qaDelegate.cardHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.width: {
                    var lv = qaDelegate.ListView.view
                    return ((lv && lv.activeFocus && lv.currentIndex === index) || qaDelegate.cardHovered) ? 2 : 1
                }
                border.color: {
                    var lv = qaDelegate.ListView.view
                    if (qaDelegate.cardHovered) {
                        return Theme.accent
                    }
                    if (lv && lv.activeFocus) {
                        return lv.currentIndex === index ? Theme.accent : Theme.surfaceBorder
                    }
                    return Theme.surfaceBorder
                }

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    spacing: 4

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: Theme.borderRadius
                        color: Qt.rgba(model.accentR, model.accentG, model.accentB, 0.12)

                        Text {
                            anchors.centerIn: parent
                            text: model.icon
                            font.pixelSize: Theme.fontSizeMd
                            font.family: "DejaVu Sans"
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                    }

                    Text {
                        text: model.title
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: model.desc
                        font.pixelSize: 10
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    Item { Layout.fillHeight: true }
                }

                MouseArea {
                    id: qaMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: qaDelegate.cardHovered = true
                    onExited: qaDelegate.cardHovered = false
                    onClicked: {
                        var node = qaDelegate.parent
                        while (node && !node.activateCard) node = node.parent
                        if (node) node.activateCard(index)
                    }
                }

            }
        }
    }
}
