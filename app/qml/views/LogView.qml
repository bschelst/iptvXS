// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: logView

    function focusPrimary() {
        if (filterRepeater.count > 0) {
            var first = filterRepeater.itemAt(0)
            if (first) {
                first.forceActiveFocus()
                return
            }
        }
        if (clearButton) {
            clearButton.forceActiveFocus()
            return
        }
        logList.forceActiveFocus()
    }

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

                Text {
                    text: appViewModel ? appViewModel.log.count + " entries" : "0 entries"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: Theme.spacingXs

                    Repeater {
                        id: filterRepeater
                        model: [
                            { label: "All", value: "" },
                            { label: "Info", value: "INFO" },
                            { label: "Warn", value: "WARN" },
                            { label: "Error", value: "ERROR" },
                            { label: "Debug", value: "DEBUG" }
                        ]

                        Rectangle {
                            id: filterButton
                            width: filterLbl.implicitWidth + Theme.spacingMd * 2
                            height: 28
                            radius: 14
                            color: {
                                var current = appViewModel ? appViewModel.log.filterLevel : ""
                                return current === modelData.value
                                    ? Theme.accent : (filterHov ? Theme.surfaceHover : "transparent")
                            }
                            border.color: {
                                var current = appViewModel ? appViewModel.log.filterLevel : ""
                                if (filterButton.activeFocus) return Theme.textOnAccent
                                return current === modelData.value ? Theme.accent : "transparent"
                            }
                            border.width: filterButton.activeFocus || filterHov ? 2 : 1
                            focus: false
                            activeFocusOnTab: true

                            property bool filterHov: false

                            Text {
                                id: filterLbl
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: true
                                color: {
                                    var current = appViewModel ? appViewModel.log.filterLevel : ""
                                    return current === modelData.value
                                        ? Theme.textOnAccent : Theme.textSecondary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.filterHov = true
                                onExited: parent.filterHov = false
                                onClicked: {
                                    if (appViewModel)
                                        appViewModel.log.filterLevel = modelData.value
                                }
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = filterRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < filterRepeater.count - 1) {
                                    var next = filterRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                } else if (clearButton) {
                                    clearButton.forceActiveFocus()
                                }
                            }
                            Keys.onDownPressed: {
                                if (logList) logList.forceActiveFocus()
                            }
                            Keys.onReturnPressed: {
                                if (appViewModel)
                                    appViewModel.log.filterLevel = modelData.value
                            }
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    if (appViewModel)
                                        appViewModel.log.filterLevel = modelData.value
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: clearButton
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 28
                    radius: 14
                    color: clearHov || clearButton.activeFocus ? Theme.error : Theme.surfaceElevated
                    border.color: clearButton.activeFocus ? Theme.textOnAccent : Theme.surfaceBorder
                    border.width: clearButton.activeFocus || clearHov ? 2 : 1
                    focus: false
                    activeFocusOnTab: true
                    property bool clearHov: false

                    Text {
                        anchors.centerIn: parent
                        text: "Clear"
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.clearHov = true
                        onExited: parent.clearHov = false
                        onClicked: { if (appViewModel) appViewModel.log.clear() }
                    }

                    Keys.onLeftPressed: {
                        if (filterRepeater.count > 0) {
                            var last = filterRepeater.itemAt(filterRepeater.count - 1)
                            if (last) last.forceActiveFocus()
                        }
                    }
                    Keys.onDownPressed: {
                        if (logList) logList.forceActiveFocus()
                    }
                    Keys.onReturnPressed: { if (appViewModel) appViewModel.log.clear() }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            if (appViewModel) appViewModel.log.clear()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        ListView {
            id: logList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appViewModel ? appViewModel.log : null
            spacing: 1
            keyNavigationEnabled: true

            Keys.onLeftPressed: {
                if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
            }
            Keys.onUpPressed: {
                if (filterRepeater.count > 0) {
                    var first = filterRepeater.itemAt(0)
                    if (first) first.forceActiveFocus()
                }
            }

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: logList.width
                height: logMsg.implicitHeight + Theme.spacingSm * 2
                color: index % 2 === 0 ? "transparent" : Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMd
                    anchors.rightMargin: Theme.spacingMd
                    spacing: Theme.spacingMd

                    Text {
                        text: model.timestamp.substring(11, 23)
                        font.pixelSize: 11
                        font.family: "monospace"
                        color: Theme.textMuted
                        Layout.preferredWidth: 90
                    }

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 18
                        radius: 9
                        color: model.levelColor + "30"

                        Text {
                            anchors.centerIn: parent
                            text: model.level
                            font.pixelSize: 9
                            font.bold: true
                            color: model.levelColor
                        }
                    }

                    Text {
                        id: logMsg
                        text: model.message
                        font.pixelSize: Theme.fontSizeXs
                        font.family: "monospace"
                        color: Theme.textPrimary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Connections {
                target: appViewModel ? appViewModel.log : null
                function onNewLogEntry() {
                    if (logList.atYEnd)
                        logList.positionViewAtEnd()
                }
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            if (appViewModel && appViewModel.log)
                appViewModel.log.refresh()
        }
    }
}
