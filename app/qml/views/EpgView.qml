// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: epgView

    Component.onDestruction: {
        channelListView.model = null
        guideListView.model = null
    }

    readonly property int channelColumnWidth: 200
    readonly property real pixelsPerSecond: 0.08
    readonly property int rowHeight: 64
    readonly property int timeHeaderHeight: 40

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

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

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search channels..."
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textMuted
                                visible: !epgSearch.text && !epgSearch.activeFocus
                            }

                            onTextChanged: epgSearchTimer.restart()

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
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: Theme.borderRadiusSmall
                    color: prevHovered ? Theme.surfaceHover : "transparent"
                    property bool prevHovered: false

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
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: Theme.borderRadiusSmall
                    color: nextHovered ? Theme.surfaceHover : "transparent"
                    property bool nextHovered: false

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
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: appViewModel ? appViewModel.epg.syncStatus : ""
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textMuted
                    visible: text.length > 0
                }

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 32
                    radius: Theme.borderRadiusSmall
                    color: syncHovered ? Theme.accentHover : Theme.accent
                    opacity: appViewModel && appViewModel.epg.syncing ? 0.5 : 1.0

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

                    delegate: Rectangle {
                        width: channelColumnWidth
                        height: rowHeight
                        color: "transparent"

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.surfaceBorder
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingSm
                            spacing: Theme.spacingSm

                            Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: Theme.borderRadiusSmall
                                color: Theme.surfaceElevated
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: model.channelLogo || ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "📺"
                                    font.pixelSize: Theme.fontSizeXs
                                    visible: !model.channelLogo
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    visible: model.isFavorite === true
                                    text: "★"
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.warning
                                }

                                Text {
                                    text: model.channelName
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textPrimary
                                    font.bold: model.isFavorite === true
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
                                    appViewModel.player.play(model.streamUrl, model.channelName, model.channelLogo, model.channelId, model.epgChannelId || "")
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
                width: parent.width - channelColumnWidth - 10
                height: parent.height - timeHeaderHeight
                contentWidth: timelineContentWidth
                clip: true
                flickableDirection: Flickable.HorizontalFlick
                focus: true

                Keys.onUpPressed: guideListView.contentY = Math.max(0, guideListView.contentY - 80)
                Keys.onDownPressed: guideListView.contentY = Math.min(guideListView.contentHeight - guideListView.height, guideListView.contentY + 80)
                Keys.onLeftPressed: contentX = Math.max(0, contentX - 200)
                Keys.onRightPressed: contentX = Math.min(contentWidth - width, contentX + 200)

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
                        width: guideFlickable.timelineContentWidth
                        height: rowHeight

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.surfaceBorder
                        }

                        Item {
                            anchors.fill: parent

                            Repeater {
                                model: programmes || []

                                Rectangle {
                                    property real progStart: Math.max(modelData.startTime, appViewModel.epg.timeWindowStart)
                                    property real progEnd: Math.min(modelData.endTime, appViewModel.epg.timeWindowEnd)
                                    property real duration: progEnd - progStart

                                    x: (progStart - appViewModel.epg.timeWindowStart) * pixelsPerSecond
                                    width: Math.max(duration * pixelsPerSecond - 1, 2)
                                    height: rowHeight - 1
                                    radius: Theme.borderRadiusSmall
                                    color: progHovered ? Theme.surfaceHover : Theme.surfaceElevated
                                    border.color: Theme.surfaceBorder
                                    border.width: 1

                                    property bool progHovered: false

                                    Behavior on color {
                                        ColorAnimation { duration: Theme.animFast }
                                    }

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingXs
                                        spacing: 1

                                        Text {
                                            text: modelData.title || ""
                                            font.pixelSize: Theme.fontSizeXs
                                            font.bold: true
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: {
                                                var s = new Date(modelData.startTime * 1000)
                                                var e = new Date(modelData.endTime * 1000)
                                                return Qt.formatTime(s, "HH:mm") + " - " + Qt.formatTime(e, "HH:mm")
                                            }
                                            font.pixelSize: 10
                                            color: Theme.textMuted
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
                    anchors.leftMargin: channelColumnWidth
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
                    x: parent.width - 10
                    y: timeHeaderHeight
                    height: parent.height - timeHeaderHeight
                    size: guideListView.height / Math.max(guideListView.contentHeight, 1)
                    position: guideListView.contentY / Math.max(guideListView.contentHeight - guideListView.height, 1)
                    policy: ScrollBar.AlwaysOn
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
                        height: 36
                        radius: 18
                        color: recBtnHov ? Theme.accentHover : Theme.accent

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
                    }

                    Rectangle {
                        width: watchBtnLabel.implicitWidth + Theme.spacingLg * 2
                        height: 36
                        radius: 18
                        color: watchBtnHov ? Theme.accentHover : Theme.accent

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
