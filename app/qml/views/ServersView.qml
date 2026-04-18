import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: serversView

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXl
        spacing: Theme.spacingLg

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Servers"
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: addBtnRow.width + Theme.spacingLg * 2
                Layout.preferredHeight: 40
                radius: Theme.borderRadius
                color: addBtnHovered ? Theme.accentHover : Theme.accent

                property bool addBtnHovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Row {
                    id: addBtnRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingSm

                    Text {
                        text: "+"
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Add Server"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.addBtnHovered = true
                    onExited: parent.addBtnHovered = false
                    onClicked: addServerDialog.open()
                }
            }
        }

        Rectangle {
            visible: appViewModel && appViewModel.serverList.syncing
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: Theme.borderRadius
            color: Theme.surfaceElevated
            border.color: Theme.accent + "40"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd
                spacing: Theme.spacingMd

                BusyIndicator {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    running: true
                }

                Text {
                    text: appViewModel ? appViewModel.serverList.syncStatus : ""
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }
            }
        }

        ListView {
            id: serverListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingSm
            clip: true

            model: appViewModel ? appViewModel.serverList : null

            delegate: Rectangle {
                width: serverListView.width
                height: 100
                radius: Theme.borderRadiusLarge
                color: delegateHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.color: delegateHovered ? Theme.accent + "40" : Theme.surfaceBorder
                border.width: 1

                property bool delegateHovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animFast }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.delegateHovered = true
                    onExited: parent.delegateHovered = false
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingMd

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: Theme.borderRadius
                        color: model.type === "xtream" ? Theme.accent + "20" : Theme.success + "20"

                        Text {
                            anchors.centerIn: parent
                            text: model.type === "xtream" ? "📡" : "📋"
                            font.pixelSize: Theme.fontSizeXl
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: model.name
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: model.type === "xtream"
                                ? model.url + " · " + model.username
                                : model.url
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: Theme.spacingMd

                            Text {
                                text: model.channelCount + " channels"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }

                            Text {
                                text: "·"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }

                            Text {
                                text: "Synced: " + model.lastSynced
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Theme.borderRadius
                        color: syncBtnHovered ? Theme.surfaceHover : "transparent"

                        property bool syncBtnHovered: false

                        Text {
                            anchors.centerIn: parent
                            text: "🔄"
                            font.pixelSize: Theme.fontSizeMd
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.syncBtnHovered = true
                            onExited: parent.syncBtnHovered = false
                            onClicked: {
                                if (appViewModel)
                                    appViewModel.serverList.syncServer(index)
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Theme.borderRadius
                        color: delBtnHovered ? Theme.error + "30" : "transparent"

                        property bool delBtnHovered: false

                        Text {
                            anchors.centerIn: parent
                            text: "🗑"
                            font.pixelSize: Theme.fontSizeMd
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.delBtnHovered = true
                            onExited: parent.delBtnHovered = false
                            onClicked: {
                                if (appViewModel)
                                    appViewModel.serverList.removeServer(index)
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: serverListView.count === 0
                text: "No servers added yet.\nClick 'Add Server' to get started."
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }
    }

    AddServerDialog {
        id: addServerDialog
    }
}
