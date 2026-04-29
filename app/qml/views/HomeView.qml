// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import app.iptvxs

Item {
    id: homeView

    // --- Row-level focus tracking ---
    property int currentRowIndex: 0
    readonly property var allRows: [continueWatchingRow, favoritesRow, recentlyAddedRow, quickAccessRow]

    function focusPrimary() {
        currentRowIndex = 0
        homeView.forceActiveFocus()
        var rows = allRows
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].visible) {
                currentRowIndex = i
                rows[i].cardListView.currentIndex = 0
                rows[i].cardListView.forceActiveFocus()
                return
            }
        }
    }

    function openOrPlayChannel(channelId) {
        if (!appViewModel || channelId <= 0) return
        var ch = appViewModel.channelInfo(channelId)
        if (ch.type === "series" && ch.externalId) {
            appViewModel.fetchSeriesEpisodes(ch.serverId, ch.externalId, ch.name, ch.logoUrl)
        } else {
            appViewModel.playChannelById(channelId)
        }
    }

    function focusCurrentRow() {
        var rows = allRows
        if (currentRowIndex >= 0 && currentRowIndex < rows.length) {
            var r = rows[currentRowIndex]
            if (r && r.visible) {
                r.cardListView.forceActiveFocus()
                return
            }
        }
        // Fall back to first visible row
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].visible) {
                currentRowIndex = i
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
            if (row && row.visible) {
                currentRowIndex = target
                row.cardListView.currentIndex = Math.min(cardIndex, row.cardListView.count - 1)
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
    }
    Component.onDestruction: {
        if (appViewModel && appViewModel.channelList) {
            appViewModel.channelList.recentlyAddedFilter = false
        }
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
        function onCountChanged() { cwPopulateTimer.restart() }
    }

    function populateContinueWatching() {
        continueWatchingModel.clear()
        if (!appViewModel || !appViewModel.history) return
        var hist = appViewModel.history
        var added = 0
        var seen = {}
        for (var i = 0; i < hist.count && added < 20; i++) {
            var idx = hist.index(i, 0)
            var cType = hist.data(idx, 261)   // ChannelTypeRole (UserRole+5)
            if (cType === "live") continue
            var posSecs = hist.data(idx, 265) || 0      // PositionSecsRole
            var totalDur = hist.data(idx, 266) || 0     // TotalDurationSecsRole
            var channelId = hist.data(idx, 258)  // ChannelIdRole (UserRole+2)
            var dedupeKey = channelId > 0 ? "id:" + channelId : "url:" + hist.data(idx, 264)
            // Skip finished (>= 95% watched) — also mark dedup key as seen
            if (totalDur > 0 && posSecs >= totalDur * 0.95) { seen[dedupeKey] = true; continue }
            if (seen[dedupeKey]) continue
            seen[dedupeKey] = true
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
    }

    // ======================================================================
    //  Quick access model
    // ======================================================================
    ListModel {
        id: quickAccessModel
        ListElement { title: "Add Server";      desc: "Connect to Xtream or M3U"; icon: "\uD83D\uDD17"; target: "servers";    accentR: 0.424; accentG: 0.361; accentB: 0.906 }
        ListElement { title: "Browse Channels"; desc: "Explore your library";      icon: "\uD83D\uDCFA"; target: "channels";   accentR: 0.0;   accentG: 0.808; accentB: 0.788 }
        ListElement { title: "TV Guide";        desc: "Check what's on now";       icon: "\uD83D\uDCC5"; target: "epg";        accentR: 0.992; accentG: 0.475; accentB: 0.659 }
        ListElement { title: "Recordings";      desc: "Manage your recordings";    icon: "\u23FA";       target: "recordings"; accentR: 1.0;   accentG: 0.420; accentB: 0.420 }
        ListElement { title: "Speed Test";      desc: "Check your connection";     icon: "\u26A1";       target: "speedtest";  accentR: 0.992; accentG: 0.796; accentB: 0.431 }
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
        property alias cardListView: cardLv

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
                anchors.rightMargin: Theme.spacingSm
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: cardLv.contentWidth > cardLv.width - cardLv.leftMargin - cardLv.rightMargin

                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: slHov ? Theme.surfaceHover : "transparent"
                    property bool slHov: false

                    Text {
                        anchors.centerIn: parent; text: "\u2039"
                        font.pixelSize: 22; font.bold: true
                        color: parent.slHov ? Theme.textPrimary : Theme.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: parent.slHov = true; onExited: parent.slHov = false
                        onClicked: cardLv.contentX = Math.max(cardLv.contentX - 216, -cardLv.leftMargin)
                    }
                }

                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: srHov ? Theme.surfaceHover : "transparent"
                    property bool srHov: false

                    Text {
                        anchors.centerIn: parent; text: "\u203A"
                        font.pixelSize: 22; font.bold: true
                        color: parent.srHov ? Theme.textPrimary : Theme.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: parent.srHov = true; onExited: parent.srHov = false
                        onClicked: cardLv.contentX = Math.min(cardLv.contentX + 216,
                            cardLv.contentWidth - cardLv.width + cardLv.rightMargin)
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
            rightMargin: Theme.spacingXl
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            currentIndex: -1
            highlightMoveDuration: 150

            model: cardRow.listModel

            Keys.onReturnPressed: activateCurrentCard()
            Keys.onEnterPressed: activateCurrentCard()
            Keys.onLeftPressed: {
                if (currentIndex > 0) currentIndex--
                else if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
            }
            Keys.onRightPressed: {
                if (currentIndex < count - 1) currentIndex++
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
                    if (hItem.channelType === "series" && hItem.channelId > 0) {
                        homeView.openOrPlayChannel(hItem.channelId)
                        return
                    }
                    if (hItem.streamUrl) {
                        appViewModel.player.play(hItem.streamUrl, hItem.channelName,
                            hItem.channelLogo, hItem.channelId, "")
                        appViewModel.currentView = "player"
                    }
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

            Rectangle {
                id: posterCard
                anchors.fill: parent
                anchors.margins: 4
                radius: 10
                color: Theme.surfaceElevated
                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: posterCard.width; height: posterCard.height; radius: posterCard.radius
                    }
                }

                property bool cardHovered: false

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
                        anchors.centerIn: parent
                        width: parent.width * 0.4; height: parent.width * 0.4
                        source: "qrc:/images/iptvxs_tray.png"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.4
                        visible: posterImg.status !== Image.Ready
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

                // Mouse interaction
                scale: posterCard.cardHovered ? 1.03 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
                }
            }

            // Single hover/click area covering entire delegate
            MouseArea {
                id: posterMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: posterCard.cardHovered = true
                onExited: posterCard.cardHovered = false
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
                            populateContinueWatching()
                        }
                        return
                    }
                    // Normal card click — play the content
                    var node = posterDelegate.parent
                    while (node && !node.activateCard) node = node.parent
                    if (node) node.activateCard(index)
                }
            }

            // Focus/hover border
            Rectangle {
                anchors.fill: posterCard
                radius: posterCard.radius
                color: "transparent"
                border.width: 2
                border.color: {
                    var lv = posterDelegate.ListView.view
                    if (posterCard.cardHovered) return Theme.accent
                    if (lv && lv.activeFocus && lv.currentIndex === model.index) return Theme.accent
                    return "transparent"
                }
                z: 100
            }

            // Mark as finished icon (visual only — click handled by posterMouseArea)
            Rectangle {
                visible: posterCard.cardHovered && (model.historyId || 0) > 0
                anchors.top: posterCard.top
                anchors.right: posterCard.right
                anchors.margins: 10
                width: 26; height: 26; radius: 13
                color: "#C0000000"
                z: 200

                Text {
                    anchors.centerIn: parent
                    text: "✓"
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

            Rectangle {
                id: qaCard
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.borderRadius
                color: qaCard.cardHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.width: {
                    var lv = qaDelegate.ListView.view
                    return (lv && lv.activeFocus && lv.currentIndex === index) ? 2 : 1
                }
                border.color: {
                    var lv = qaDelegate.ListView.view
                    if (lv && lv.activeFocus && lv.currentIndex === index) return Theme.accent
                    if (qaCard.cardHovered) return Qt.rgba(model.accentR, model.accentG, model.accentB, 0.25)
                    return Theme.surfaceBorder
                }

                property bool cardHovered: false

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                scale: cardHovered ? 1.03 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic }
                }

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
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: qaCard.cardHovered = true
                    onExited: qaCard.cardHovered = false
                    onClicked: {
                        var node = qaDelegate.parent
                        while (node && !node.activateCard) node = node.parent
                        if (node) node.activateCard(model.index)
                    }
                }
            }
        }
    }
}
