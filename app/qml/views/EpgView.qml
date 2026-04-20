import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: epgView

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
                        text: "◀"
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.textSecondary
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
                        text: "▶"
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.textSecondary
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
                        color: Theme.textPrimary
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
                                    appViewModel.player.play(model.streamUrl, model.channelName, model.channelLogo, model.channelId)
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
                                        onEntered: parent.progHovered = true
                                        onExited: parent.progHovered = false

                                        ToolTip.visible: parent.progHovered && (modelData.description || "").length > 0
                                        ToolTip.text: modelData.description || ""
                                        ToolTip.delay: 500
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

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: Theme.accent
                            opacity: parent.active ? 0.8 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                        }
                        background: Rectangle {
                            implicitWidth: 6
                            color: "transparent"
                        }
                    }
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
}
