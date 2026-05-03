// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: epgView

    Component.onDestruction: {
        channelListView.model = null
        guideListView.model = null
    }

    readonly property int channelColumnWidth: 248
    readonly property real pixelsPerSecond: 0.08
    readonly property int rowHeight: 116
    readonly property int timeHeaderHeight: 34

    // --- Controller / d-pad navigation state ---
    property int currentChannelIndex: 0
    property int currentProgrammeIndex: 0
    property bool channelColumnFocused: false  // true = channel col, false = programme grid
    property bool defaultServerApplied: false

    Connections {
        target: appViewModel ? appViewModel.serverList : null
        function onCountChanged() {
            applyDefaultServerSelection()
        }
    }

    function applyDefaultServerSelection() {
        if (!appViewModel || !appViewModel.serverList || !serverPicker) return
        if (defaultServerApplied) return
        if (serverPicker.count <= 0) return

        var idx = appViewModel.serverList.firstLiveServerIndex()
        if (idx < 0 || idx >= serverPicker.count) {
            idx = 0
        }

        serverPicker.currentIndex = idx
        appViewModel.epg.serverId = appViewModel.serverList.serverIdAt(idx)
        defaultServerApplied = true
    }

    function focusPrimary() {
        if (progDetailPopup.visible || recConfirm.visible) return
        currentChannelIndex = Math.min(currentChannelIndex, Math.max(0, guideListView.count - 1))
        channelColumnFocused = false
        guideFlickable.forceActiveFocus()
        ensureChannelVisible()
    }

    function ensureChannelVisible() {
        var targetY = currentChannelIndex * rowHeight
        if (targetY < guideListView.contentY) {
            guideListView.contentY = targetY
        } else if (targetY + rowHeight > guideListView.contentY + guideListView.height) {
            guideListView.contentY = targetY + rowHeight - guideListView.height
        }
        guideListView.contentY = Math.max(0, Math.min(guideListView.contentY,
            guideListView.contentHeight - guideListView.height))
    }

    function ensureProgrammeVisible() {
        // Find the programme rectangle x position and scroll the flickable so it is visible
        if (!appViewModel) return
        var progs = appViewModel.epg.programmesForChannel(currentChannelIndex)
        if (!progs || currentProgrammeIndex < 0 || currentProgrammeIndex >= progs.length) return
        var prog = progs[currentProgrammeIndex]
        var progStart = Math.max(prog.startTime, appViewModel.epg.timeWindowStart)
        var progEnd = Math.min(prog.endTime, appViewModel.epg.timeWindowEnd)
        var xStart = (progStart - appViewModel.epg.timeWindowStart) * pixelsPerSecond
        var xEnd = (progEnd - appViewModel.epg.timeWindowStart) * pixelsPerSecond
        if (xStart < guideFlickable.contentX) {
            guideFlickable.contentX = Math.max(0, xStart - 20)
        } else if (xEnd > guideFlickable.contentX + guideFlickable.width) {
            guideFlickable.contentX = Math.min(guideFlickable.contentWidth - guideFlickable.width,
                xEnd - guideFlickable.width + 20)
        }
    }

    function openProgrammeDetail() {
        if (!appViewModel) return
        var progs = appViewModel.epg.programmesForChannel(currentChannelIndex)
        if (!progs || currentProgrammeIndex < 0 || currentProgrammeIndex >= progs.length) return
        var prog = progs[currentProgrammeIndex]
        var row = appViewModel.epg.rowData(currentChannelIndex)
        if (!row) return
        progDetailPopup.channelName = row.channelName || ""
        progDetailPopup.channelLogo = row.channelLogo || ""
        progDetailPopup.streamUrl = row.streamUrl || ""
        progDetailPopup.channelId = row.channelId || 0
        progDetailPopup.epgChannelId = row.epgChannelId || ""
        progDetailPopup.progTitle = prog.title || ""
        progDetailPopup.progDescription = prog.description || ""
        progDetailPopup.progStart = prog.startTime
        progDetailPopup.progEnd = prog.endTime
        progDetailPopup.visible = true
    }

    function focusHeaderControls() {
        if (epgPrevBtn) {
            epgPrevBtn.forceActiveFocus()
        } else if (epgSearch) {
            epgSearch.forceActiveFocus()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Component.onCompleted: {
            applyDefaultServerSelection()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: Theme.surface

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.surfaceBorder
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 32
                    radius: 16
                    color: Theme.surfaceElevated
                    border.color: epgSearch.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: epgSearch.forceActiveFocus()
                        cursorShape: Qt.IBeamCursor
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingSm
                        anchors.rightMargin: Theme.spacingSm
                        spacing: Theme.spacingSm

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🔍"
                            font.pixelSize: Theme.fontSizeXs
                            opacity: 0.5
                        }

                        TextInput {
                            id: epgSearch
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 30
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                            clip: true
                            selectByMouse: true

                            onActiveFocusChanged: {
                                if (activeFocus) Qt.inputMethod.show()
                                else Qt.inputMethod.hide()
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search channels..."
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textMuted
                                visible: !epgSearch.text && !epgSearch.activeFocus
                            }

                            onTextChanged: epgSearchTimer.restart()

                            Keys.onRightPressed: {
                                epgView.focusPrimary()
                            }
                            Keys.onDownPressed: {
                                epgView.focusPrimary()
                            }
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
                                    if (Window.window && Window.window.focusSidebar) {
                                        Window.window.focusSidebar()
                                    }
                                    event.accepted = true
                                }
                            }

                            Timer {
                                id: epgSearchTimer
                                interval: 300
                                onTriggered: {
                                    if (appViewModel)
                                        appViewModel.epg.searchQuery = epgSearch.text
                                }
                            }
                        }
                    }
                }

                ComboBox {
                    id: serverPicker
                    Layout.preferredWidth: 200
                    model: appViewModel ? appViewModel.serverList : null
                    textRole: "name"
                    valueRole: "serverId"

                    background: Rectangle {
                        radius: Theme.borderRadiusSmall
                        color: Theme.surfaceElevated
                        border.color: serverPicker.activeFocus ? Theme.accent : Theme.surfaceBorder
                        border.width: 1
                    }

                    contentItem: Text {
                        text: serverPicker.displayText
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: Theme.spacingSm
                    }

                    delegate: ItemDelegate {
                        width: serverPicker.width
                        height: model.enabled ? 36 : 0
                        visible: model.enabled
                        contentItem: Text {
                            text: model.name
                            font.pixelSize: Theme.fontSizeSm
                            color: highlighted ? Theme.textOnAccent : Theme.textPrimary
                            verticalAlignment: Text.AlignVCenter
                        }
                        highlighted: serverPicker.highlightedIndex === index
                        background: Rectangle {
                            color: highlighted ? Theme.accent : (hovered ? Theme.surfaceHover : Theme.surfaceElevated)
                        }
                    }

                    popup: Popup {
                        y: serverPicker.height
                        width: serverPicker.width
                        implicitHeight: contentItem.implicitHeight + 2
                        padding: 1
                        contentItem: ListView {
                            clip: true
                            implicitHeight: Math.min(contentHeight, 250)
                            model: serverPicker.popup.visible ? serverPicker.delegateModel : null
                            ScrollBar.vertical: ScrollBar { active: true }
                        }
                        background: Rectangle {
                            color: Theme.surfaceElevated
                            border.color: Theme.surfaceBorder
                            border.width: 1
                            radius: Theme.borderRadiusSmall
                        }
                    }

                    onCurrentValueChanged: {
                        if (appViewModel && currentValue > 0) {
                            appViewModel.epg.serverId = currentValue
                        }
                    }
                    onActivated: {
                        defaultServerApplied = true
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: epgPrevBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: Theme.borderRadiusSmall
                    color: prevHovered || epgPrevBtn.activeFocus ? Theme.surfaceHover : "transparent"
                    property bool prevHovered: false
                    focus: false
                    activeFocusOnTab: true

                    Text {
                        anchors.centerIn: parent
                        text: "\u2039"
                        font.pixelSize: 22
                        font.bold: true
                        color: parent.prevHovered ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.prevHovered = true
                        onExited: parent.prevHovered = false
                        onClicked: {
                            if (appViewModel) appViewModel.epg.shiftTime(-2)
                        }
                    }

                    Keys.onRightPressed: {
                        if (epgNextBtn) epgNextBtn.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (guideFlickable) guideFlickable.forceActiveFocus()
                    }
                    Keys.onReturnPressed: {
                        if (appViewModel) appViewModel.epg.shiftTime(-2)
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            if (appViewModel) appViewModel.epg.shiftTime(-2)
                            event.accepted = true
                        }
                    }
                }

                Text {
                    text: {
                        if (!appViewModel) return ""
                        var d = new Date(appViewModel.epg.timeWindowStart * 1000)
                        return Qt.formatDate(d, "ddd d MMM") + " " +
                               Qt.formatTime(d, "HH:mm") + " - " +
                               Qt.formatTime(new Date(appViewModel.epg.timeWindowEnd * 1000), "HH:mm")
                    }
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: Theme.textPrimary
                }

                Rectangle {
                    id: epgNextBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: Theme.borderRadiusSmall
                    color: nextHovered || epgNextBtn.activeFocus ? Theme.surfaceHover : "transparent"
                    property bool nextHovered: false
                    focus: false
                    activeFocusOnTab: true

                    Text {
                        anchors.centerIn: parent
                        text: "\u203A"
                        font.pixelSize: 22
                        font.bold: true
                        color: parent.nextHovered ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.nextHovered = true
                        onExited: parent.nextHovered = false
                        onClicked: {
                            if (appViewModel) appViewModel.epg.shiftTime(2)
                        }
                    }

                    Keys.onLeftPressed: {
                        if (epgPrevBtn) epgPrevBtn.forceActiveFocus()
                    }
                    Keys.onRightPressed: {
                        if (epgSyncBtn) epgSyncBtn.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (guideFlickable) guideFlickable.forceActiveFocus()
                    }
                    Keys.onReturnPressed: {
                        if (appViewModel) appViewModel.epg.shiftTime(2)
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            if (appViewModel) appViewModel.epg.shiftTime(2)
                            event.accepted = true
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: appViewModel ? appViewModel.epg.syncStatus : ""
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textMuted
                    visible: text.length > 0
                }

                Rectangle {
                    id: epgSyncBtn
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 32
                    radius: Theme.borderRadiusSmall
                    color: syncHovered || epgSyncBtn.activeFocus ? Theme.accentHover : Theme.accent
                    opacity: appViewModel && appViewModel.epg.syncing ? 0.5 : 1.0
                    focus: false
                    activeFocusOnTab: true

                    property bool syncHovered: false

                    Text {
                        anchors.centerIn: parent
                        text: appViewModel && appViewModel.epg.syncing ? "Syncing..." : "Sync EPG"
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        color: Theme.textOnAccent
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: appViewModel && !appViewModel.epg.syncing
                        onEntered: parent.syncHovered = true
                        onExited: parent.syncHovered = false
                        onClicked: {
                            if (appViewModel && serverPicker.currentValue > 0) {
                                var epgUrl = appViewModel.serverList.epgUrlAt(serverPicker.currentIndex)
                                if (epgUrl.length > 0) {
                                    appViewModel.epg.syncEpg(epgUrl)
                                }
                            }
                        }
                    }

                    Keys.onLeftPressed: {
                        if (epgNextBtn) epgNextBtn.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (guideFlickable) guideFlickable.forceActiveFocus()
                    }
                    Keys.onReturnPressed: {
                        if (appViewModel && serverPicker.currentValue > 0) {
                            var epgUrl = appViewModel.serverList.epgUrlAt(serverPicker.currentIndex)
                            if (epgUrl.length > 0) {
                                appViewModel.epg.syncEpg(epgUrl)
                            }
                        }
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            Keys.onReturnPressed(event)
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                id: timeHeader
                x: channelColumnWidth
                width: parent.width - channelColumnWidth
                height: timeHeaderHeight
                color: Theme.surface
                clip: true
                z: 2

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.surfaceBorder
                }

                Row {
                    x: -guideFlickable.contentX

                    Repeater {
                        model: {
                            if (!appViewModel) return 0
                            return (appViewModel.epg.timeWindowEnd - appViewModel.epg.timeWindowStart) / 1800
                        }

                        Rectangle {
                            width: 1800 * pixelsPerSecond
                            height: timeHeaderHeight
                            color: "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                width: 1
                                height: parent.height
                                color: Theme.surfaceBorder
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingSm
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!appViewModel) return ""
                                    var t = appViewModel.epg.timeWindowStart + index * 1800
                                    return Qt.formatTime(new Date(t * 1000), "HH:mm")
                                }
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: channelColumn
                width: channelColumnWidth
                y: timeHeaderHeight
                height: parent.height - timeHeaderHeight
                color: Theme.surface
                clip: true
                z: 2

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height
                    color: Theme.surfaceBorder
                }

                ListView {
                    id: channelListView
                    anchors.fill: parent
                    model: appViewModel ? appViewModel.epg : null
                    interactive: false
                    contentY: guideListView.contentY

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        target: null
                        onWheel: function(event) {
                            if (!guideListView) return
                            var delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
                            if (delta === 0) return
                            guideListView.contentY = Math.max(0, Math.min(
                                guideListView.contentY - delta,
                                guideListView.contentHeight - guideListView.height))
                            event.accepted = true
                        }
                    }

                    delegate: Rectangle {
                        width: channelColumnWidth
                        height: rowHeight
                        color: {
                            var stripe = (index % 2 === 0)
                                ? "transparent"
                                : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.015)
                            if (guideFlickable.activeFocus && index === currentChannelIndex) {
                                return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, channelColumnFocused ? 0.10 : 0.05)
                            }
                            return stripe
                        }
                        border.width: (guideFlickable.activeFocus && index === currentChannelIndex) ? 1 : 0
                        border.color: (guideFlickable.activeFocus && index === currentChannelIndex)
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45) : "transparent"

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.surfaceBorder
                            opacity: 0.28
                        }

                        Rectangle {
                            visible: guideFlickable.activeFocus && index === currentChannelIndex
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 4
                            radius: 2
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingMd
                            spacing: Theme.spacingMd

                            Rectangle {
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                radius: 12
                                color: Theme.surfaceElevated
                                border.color: Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.08)
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    source: model.channelLogo || ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready
                                    sourceSize.width: 104
                                    sourceSize.height: 104
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "📺"
                                    font.pixelSize: 15
                                    visible: !model.channelLogo
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    visible: model.isFavorite === true
                                    text: "★ Favorite"
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: true
                                    color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.85)
                                }

                                Text {
                                    text: model.channelName
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textPrimary
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (appViewModel) {
                                    appViewModel.player.play(model.streamUrl, model.channelName, model.channelLogo, model.channelId, model.epgChannelId || "", 0, true, true)
                                    appViewModel.currentView = "player"
                                }
                            }
                        }
                    }
                }
            }

            Flickable {
                id: guideFlickable
                x: channelColumnWidth
                y: timeHeaderHeight
                width: parent.width - channelColumnWidth
                height: parent.height - timeHeaderHeight
                contentWidth: timelineContentWidth
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                focus: true

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    target: null
                    onWheel: function(event) {
                        if (!guideFlickable) return

                        var pixelX = event.pixelDelta.x
                        var pixelY = event.pixelDelta.y
                        var angleX = event.angleDelta.x
                        var angleY = event.angleDelta.y

                        var deltaX = pixelX !== 0 ? pixelX : angleX / 6
                        var deltaY = pixelY !== 0 ? pixelY : angleY / 6

                        if (deltaY !== 0) {
                            guideListView.contentY = Math.max(0, Math.min(
                                guideListView.contentY - deltaY,
                                guideListView.contentHeight - guideListView.height))
                        }

                        if (deltaX !== 0) {
                            guideFlickable.contentX = Math.max(0, Math.min(
                                guideFlickable.contentX - deltaX,
                                guideFlickable.contentWidth - guideFlickable.width))
                        }

                        event.accepted = true
                    }
                }

                Keys.onUpPressed: {
                    if (currentChannelIndex > 0) {
                        currentChannelIndex--
                        if (!channelColumnFocused) {
                            // Clamp programme index to new row
                            var progs = appViewModel ? appViewModel.epg.programmesForChannel(currentChannelIndex) : null
                            if (progs) currentProgrammeIndex = Math.min(currentProgrammeIndex, progs.length - 1)
                            else currentProgrammeIndex = 0
                            ensureProgrammeVisible()
                        }
                        ensureChannelVisible()
                    } else {
                        focusHeaderControls()
                    }
                }
                Keys.onDownPressed: {
                    if (guideListView.count > 0 && currentChannelIndex < guideListView.count - 1) {
                        currentChannelIndex++
                        if (!channelColumnFocused) {
                            var progs = appViewModel ? appViewModel.epg.programmesForChannel(currentChannelIndex) : null
                            if (progs) currentProgrammeIndex = Math.min(currentProgrammeIndex, progs.length - 1)
                            else currentProgrammeIndex = 0
                            ensureProgrammeVisible()
                        }
                        ensureChannelVisible()
                    }
                }
                Keys.onLeftPressed: {
                    if (channelColumnFocused) {
                        // Already on channel column — go to sidebar
                        if (Window.window && Window.window.focusSidebar)
                            Window.window.focusSidebar()
                    } else if (currentProgrammeIndex > 0) {
                        currentProgrammeIndex--
                        ensureProgrammeVisible()
                    } else {
                        // At first programme or no programmes — move to channel column
                        channelColumnFocused = true
                    }
                }
                Keys.onRightPressed: {
                    if (channelColumnFocused) {
                        // Move from channel column into programme grid
                        channelColumnFocused = false
                        var progs = appViewModel ? appViewModel.epg.programmesForChannel(currentChannelIndex) : null
                        if (progs && progs.length > 0) {
                            currentProgrammeIndex = 0
                            ensureProgrammeVisible()
                        }
                    } else {
                        var progs2 = appViewModel ? appViewModel.epg.programmesForChannel(currentChannelIndex) : null
                        if (progs2 && currentProgrammeIndex < progs2.length - 1) {
                            currentProgrammeIndex++
                            ensureProgrammeVisible()
                        }
                    }
                }
                Keys.onReturnPressed: {
                    if (channelColumnFocused) {
                        // Play the channel directly
                        if (appViewModel && currentChannelIndex >= 0 && currentChannelIndex < guideListView.count) {
                            var row = appViewModel.epg.rowData(currentChannelIndex)
                            if (row) {
                                appViewModel.player.play(row.streamUrl, row.channelName,
                                    row.channelLogo, row.channelId, row.epgChannelId || "", 0, true, true)
                                appViewModel.currentView = "player"
                            }
                        }
                    } else {
                        openProgrammeDetail()
                    }
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Enter) {
                        Keys.onReturnPressed(event)
                        event.accepted = true
                    }
                }

                readonly property real timelineContentWidth: {
                    if (!appViewModel) return 0
                    return (appViewModel.epg.timeWindowEnd - appViewModel.epg.timeWindowStart) * pixelsPerSecond
                }

                ListView {
                    id: guideListView
                    anchors.fill: parent
                    model: appViewModel ? appViewModel.epg : null
                    clip: false
                    cacheBuffer: rowHeight * 4

                    delegate: Item {
                        id: guideRowDelegate
                        width: guideFlickable.timelineContentWidth
                        height: rowHeight

                        property int channelRowIndex: index

                        Rectangle {
                            anchors.fill: parent
                            color: {
                                var stripe = (index % 2 === 0)
                                    ? "transparent"
                                    : Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.015)
                                if (guideFlickable.activeFocus && index === currentChannelIndex) {
                                return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, channelColumnFocused ? 0.08 : 0.04)
                                }
                                return stripe
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.surfaceBorder
                            opacity: 0.24
                        }

                        Item {
                            anchors.fill: parent

                            Repeater {
                                model: programmes || []

                                Rectangle {
                                    property real progStart: Math.max(modelData.startTime, appViewModel.epg.timeWindowStart)
                                    property real progEnd: Math.min(modelData.endTime, appViewModel.epg.timeWindowEnd)
                                    property real duration: progEnd - progStart

                                    readonly property bool isFocused: guideFlickable.activeFocus
                                        && !channelColumnFocused
                                        && guideRowDelegate.channelRowIndex === currentChannelIndex
                                        && index === currentProgrammeIndex

                                    x: (progStart - appViewModel.epg.timeWindowStart) * pixelsPerSecond
                                    width: Math.max(duration * pixelsPerSecond - 1, 2)
                                    height: rowHeight - 1
                                    radius: Theme.borderRadiusSmall + 1
                                    color: isFocused ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                        : progHovered ? Theme.surfaceHover : Theme.surfaceElevated
                                    border.color: isFocused
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.65)
                                        : (progHovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : Qt.rgba(Theme.surfaceBorder.r, Theme.surfaceBorder.g, Theme.surfaceBorder.b, 0.55))
                                    border.width: 1

                                    property bool progHovered: false

                                    Rectangle {
                                        visible: isFocused || progHovered
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: 3
                                        radius: parent.radius
                                        color: Theme.accent
                                        opacity: isFocused ? 0.95 : 0.45
                                    }

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animFast }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingSm
                                        spacing: isFocused || progHovered ? 2 : 0

                                        Text {
                                            text: modelData.title || ""
                                            font.pixelSize: Theme.fontSizeSm
                                            font.bold: true
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            wrapMode: Text.NoWrap
                                        }

                                        Text {
                                            visible: isFocused || progHovered
                                            text: {
                                                var s = new Date(modelData.startTime * 1000)
                                                var e = new Date(modelData.endTime * 1000)
                                                return Qt.formatTime(s, "HH:mm") + " - " + Qt.formatTime(e, "HH:mm")
                                            }
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.textMuted
                                            opacity: 0.85
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.progHovered = true
                                        onExited: parent.progHovered = false
                                        onClicked: {
                                            progDetailPopup.channelName = channelName
                                            progDetailPopup.channelLogo = channelLogo
                                            progDetailPopup.streamUrl = streamUrl
                                            progDetailPopup.channelId = channelId
                                            progDetailPopup.epgChannelId = epgChannelId || ""
                                            progDetailPopup.progTitle = modelData.title || ""
                                            progDetailPopup.progDescription = modelData.description || ""
                                            progDetailPopup.progStart = modelData.startTime
                                            progDetailPopup.progEnd = modelData.endTime
                                            progDetailPopup.visible = true
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: {
                                if (!appViewModel) return false
                                var now = appViewModel.epg.currentTime
                                return now >= appViewModel.epg.timeWindowStart && now <= appViewModel.epg.timeWindowEnd
                            }
                            x: {
                                if (!appViewModel) return 0
                                return (appViewModel.epg.currentTime - appViewModel.epg.timeWindowStart) * pixelsPerSecond
                            }
                            width: 2
                            height: rowHeight
                            color: Theme.live
                            z: 10
                        }
                    }

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOff }
                }

                ScrollBar {
                    id: hScrollBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    orientation: Qt.Horizontal
                    size: guideFlickable.width / Math.max(guideFlickable.contentWidth, 1)
                    position: guideFlickable.contentX / Math.max(guideFlickable.contentWidth, 1)
                    active: true
                    policy: ScrollBar.AsNeeded

                    onPositionChanged: {
                        if (pressed) {
                            guideFlickable.contentX = position * guideFlickable.contentWidth
                        }
                    }

                    contentItem: Rectangle {
                        implicitHeight: 6
                        radius: 3
                        color: Theme.accent
                        opacity: hScrollBar.active ? 0.8 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }
                    background: Rectangle {
                        implicitHeight: 6
                        color: "transparent"
                    }
                }

                ScrollBar {
                    id: vScrollBar
                    orientation: Qt.Vertical
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    size: guideListView.height / Math.max(guideListView.contentHeight, 1)
                    position: guideListView.contentY / Math.max(guideListView.contentHeight - guideListView.height, 1)
                    policy: ScrollBar.AsNeeded
                    active: true

                    onPositionChanged: {
                        if (pressed) {
                            guideListView.contentY = position * (guideListView.contentHeight - guideListView.height)
                        }
                    }

                    contentItem: Rectangle {
                        implicitWidth: 8
                        radius: 4
                        color: Theme.accent
                        opacity: vScrollBar.pressed ? 1.0 : 0.5
                    }
                    background: Rectangle {
                        implicitWidth: 8
                        color: Theme.surfaceBorder
                        opacity: 0.3
                        radius: 4
                    }
                }
            }

            Rectangle {
                x: channelColumnWidth
                y: timeHeaderHeight
                width: parent.width - channelColumnWidth
                height: parent.height - timeHeaderHeight
                color: "transparent"
                visible: appViewModel && appViewModel.epg.count === 0

                Text {
                    anchors.centerIn: parent
                    text: "No EPG data available.\nSelect a server and click 'Sync EPG' to download programme data."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }
            }
        }
    }

    Rectangle {
        id: progDetailPopup
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 200

        property int focusedButton: 1  // 0=record, 1=watch
        onVisibleChanged: {
            if (visible) { focusedButton = 1; forceActiveFocus() }
            else guideFlickable.forceActiveFocus()
        }

        Keys.onLeftPressed: focusedButton = 0
        Keys.onRightPressed: focusedButton = 1
        Keys.onReturnPressed: activateFocusedButton()
        Keys.onEnterPressed: activateFocusedButton()
        Keys.onEscapePressed: visible = false
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                activateFocusedButton()
                event.accepted = true
            } else if (event.key === Qt.Key_Back || event.key === Qt.Key_B) {
                visible = false
                event.accepted = true
            }
        }

        function activateFocusedButton() {
            if (focusedButton === 0) recBtn.clicked()
            else watchBtn.clicked()
        }

        property string channelName: ""
        property string channelLogo: ""
        property string streamUrl: ""
        property var channelId: 0
        property string epgChannelId: ""
        property string progTitle: ""
        property string progDescription: ""
        property real progStart: 0
        property real progEnd: 0

        readonly property bool isLive: {
            if (!appViewModel) return false
            var now = appViewModel.epg.currentTime
            return now >= progStart && now < progEnd
        }

        readonly property real progress: {
            if (!isLive || progEnd <= progStart) return 0
            var now = appViewModel.epg.currentTime
            return Math.min(1, Math.max(0, (now - progStart) / (progEnd - progStart)))
        }

        MouseArea { anchors.fill: parent; onClicked: progDetailPopup.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(520, parent.width - 80)
            height: popupContent.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.surfaceBorder
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: popupContent
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: Theme.borderRadius
                        color: Theme.surface
                        clip: true

                        Image {
                            id: popupLogo
                            anchors.fill: parent
                            anchors.margins: 4
                            source: progDetailPopup.channelLogo || ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "📺"
                            font.pixelSize: 20
                            visible: !popupLogo.visible
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: progDetailPopup.channelName
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: progDetailPopup.progTitle
                            font.pixelSize: Theme.fontSizeLg
                            font.bold: true
                            color: Theme.textPrimary
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: closePopupHov ? 30 : 28
                        Layout.preferredHeight: closePopupHov ? 30 : 28
                        Layout.alignment: Qt.AlignTop
                        radius: width / 2
                        color: closePopupHov ? Theme.surfaceHover : "transparent"
                        property bool closePopupHov: false

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: Theme.fontSizeMd
                            color: parent.closePopupHov ? Theme.textPrimary : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.closePopupHov = true
                            onExited: parent.closePopupHov = false
                            onClicked: progDetailPopup.visible = false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.surfaceBorder
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd

                    Text {
                        text: {
                            if (progDetailPopup.progStart <= 0) return ""
                            var s = new Date(progDetailPopup.progStart * 1000)
                            var e = new Date(progDetailPopup.progEnd * 1000)
                            return Qt.formatTime(s, "HH:mm") + " – " + Qt.formatTime(e, "HH:mm")
                        }
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            var dur = progDetailPopup.progEnd - progDetailPopup.progStart
                            if (dur <= 0) return ""
                            var mins = Math.round(dur / 60)
                            if (mins >= 60) {
                                var h = Math.floor(mins / 60)
                                var m = mins % 60
                                return h + "h " + (m > 0 ? m + "m" : "")
                            }
                            return mins + " min"
                        }
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textMuted
                    }

                    Rectangle {
                        visible: progDetailPopup.isLive
                        Layout.preferredWidth: liveLabel.implicitWidth + 12
                        Layout.preferredHeight: 20
                        radius: 10
                        color: Theme.live

                        Text {
                            id: liveLabel
                            anchors.centerIn: parent
                            text: "LIVE"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    visible: progDetailPopup.isLive
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: Theme.surface

                    Rectangle {
                        width: parent.width * progDetailPopup.progress
                        height: parent.height
                        radius: 2
                        color: Theme.live
                    }
                }

                Text {
                    visible: progDetailPopup.progDescription.length > 0
                    text: progDetailPopup.progDescription
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    lineHeight: 1.4
                    maximumLineCount: 8
                    elide: Text.ElideRight
                }

                Text {
                    visible: progDetailPopup.progDescription.length === 0
                    text: "No description available."
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textMuted
                    font.italic: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.surfaceBorder
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: recBtnLabel.implicitWidth + Theme.spacingLg * 2
                        id: recBtn
                        height: 36
                        radius: 18
                        color: recBtnHov || progDetailPopup.focusedButton === 0 ? Theme.accentHover : Theme.accent
                        border.width: progDetailPopup.focusedButton === 0 ? 2 : 0
                        border.color: "#ffffff"
                        signal clicked()

                        property bool recBtnHov: false

                        Text {
                            id: recBtnLabel
                            anchors.centerIn: parent
                            text: "●  Record"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textOnAccent
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.recBtnHov = true
                            onExited: parent.recBtnHov = false
                            onClicked: recBtn.clicked()
                        }

                        onClicked: {
                            if (!appViewModel) return
                            var leadMin = appViewModel.epgRecordingLeadTime || 0
                            var overMin = appViewModel.epgRecordingOverrun || 0
                            recConfirm.channelName = progDetailPopup.channelName
                            recConfirm.channelLogo = progDetailPopup.channelLogo
                            recConfirm.channelId = progDetailPopup.channelId
                            recConfirm.progTitle = progDetailPopup.progTitle
                            recConfirm.isLive = progDetailPopup.isLive
                            recConfirm.startEpoch = Math.floor(progDetailPopup.progStart) - leadMin * 60
                            recConfirm.endEpoch = Math.floor(progDetailPopup.progEnd) + overMin * 60
                            recConfirm.leadMin = leadMin
                            recConfirm.overMin = overMin
                            progDetailPopup.visible = false
                            recConfirm.visible = true
                        }
                    }

                    Rectangle {
                        id: watchBtn
                        width: watchBtnLabel.implicitWidth + Theme.spacingLg * 2
                        height: 36
                        radius: 18
                        color: watchBtnHov || progDetailPopup.focusedButton === 1 ? Theme.accentHover : Theme.accent
                        border.width: progDetailPopup.focusedButton === 1 ? 2 : 0
                        border.color: "#ffffff"
                        signal clicked()

                        property bool watchBtnHov: false

                        Text {
                            id: watchBtnLabel
                            anchors.centerIn: parent
                            text: progDetailPopup.isLive ? "▶  Watch Now" : "▶  Tune In"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textOnAccent
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.watchBtnHov = true
                            onExited: parent.watchBtnHov = false
                            onClicked: watchBtn.clicked()
                        }

                        onClicked: {
                            if (appViewModel) {
                                appViewModel.player.play(progDetailPopup.streamUrl,
                                    progDetailPopup.channelName,
                                    progDetailPopup.channelLogo,
                                    progDetailPopup.channelId,
                                    progDetailPopup.epgChannelId)
                                appViewModel.currentView = "player"
                            }
                            progDetailPopup.visible = false
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: recConfirm
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 300

        property string channelName: ""
        property string channelLogo: ""
        property var channelId: 0
        property string progTitle: ""
        property bool isLive: false
        property real startEpoch: 0
        property real endEpoch: 0
        property int leadMin: 0
        property int overMin: 0

        MouseArea { anchors.fill: parent; onClicked: recConfirm.visible = false }

        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: recConfirmCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.accent
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: recConfirmCol
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                Text {
                    text: "Schedule Recording"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                }

                RowLayout {
                    spacing: Theme.spacingMd

                    Image {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        source: recConfirm.channelLogo || ""
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: recConfirm.channelName
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            visible: recConfirm.progTitle.length > 0
                            text: recConfirm.progTitle
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.surfaceBorder
                }

                ColumnLayout {
                    spacing: 4

                    Text {
                        text: recConfirm.isLive ? "Recording starts immediately" : "Scheduled recording"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: Theme.accent
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "Start:"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
                        Text {
                            text: {
                                var d = new Date(recConfirm.startEpoch * 1000)
                                var s = Qt.formatDateTime(d, "ddd d MMM HH:mm")
                                return recConfirm.leadMin > 0 ? s + "  (" + recConfirm.leadMin + " min early)" : s
                            }
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textPrimary
                        }
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "End:"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
                        Text {
                            text: {
                                var d = new Date(recConfirm.endEpoch * 1000)
                                var s = Qt.formatDateTime(d, "ddd d MMM HH:mm")
                                return recConfirm.overMin > 0 ? s + "  (+" + recConfirm.overMin + " min overrun)" : s
                            }
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textPrimary
                        }
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "Duration:"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
                        Text {
                            text: {
                                var mins = Math.round((recConfirm.endEpoch - recConfirm.startEpoch) / 60)
                                if (mins >= 60) return Math.floor(mins / 60) + "h " + (mins % 60) + "min"
                                return mins + " min"
                            }
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textPrimary
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Theme.spacingSm

                    Rectangle {
                        width: cancelRecLabel.implicitWidth + Theme.spacingLg
                        height: 36
                        radius: Theme.borderRadius
                        color: cancelRecHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        property bool cancelRecHov: false

                        Text { id: cancelRecLabel; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: parent.cancelRecHov = true; onExited: parent.cancelRecHov = false
                            onClicked: recConfirm.visible = false
                        }
                    }

                    Rectangle {
                        width: confirmRecLabel.implicitWidth + Theme.spacingLg * 2
                        height: 36
                        radius: Theme.borderRadius
                        color: confirmRecHov ? Theme.accentHover : Theme.accent
                        property bool confirmRecHov: false

                        Text { id: confirmRecLabel; anchors.centerIn: parent; text: "Confirm Recording"; font.pixelSize: Theme.fontSizeSm; font.bold: true; color: Theme.textOnAccent }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: parent.confirmRecHov = true; onExited: parent.confirmRecHov = false
                            onClicked: {
                                if (!appViewModel) return
                                var now = Math.floor(Date.now() / 1000)
                                if (recConfirm.isLive) {
                                    var remaining = recConfirm.endEpoch > now ? recConfirm.endEpoch - now : 3600
                                    appViewModel.recordingList.startNow(recConfirm.channelId, remaining, "original")
                                } else {
                                    appViewModel.recordingList.scheduleRecording(
                                        recConfirm.channelId, recConfirm.startEpoch, recConfirm.endEpoch, "original")
                                }
                                appViewModel.recordingList.refresh()
                                recConfirm.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
