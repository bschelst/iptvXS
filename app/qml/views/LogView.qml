import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: logView

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
                        model: [
                            { label: "All", value: "" },
                            { label: "Info", value: "INFO" },
                            { label: "Warn", value: "WARN" },
                            { label: "Error", value: "ERROR" },
                            { label: "Debug", value: "DEBUG" }
                        ]

                        Rectangle {
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
                                return current === modelData.value ? Theme.accent : "transparent"
                            }
                            border.width: 1

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
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 28
                    radius: 14
                    color: clearHov ? Theme.error : Theme.surfaceElevated
                    border.color: Theme.surfaceBorder
                    border.width: 1
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
