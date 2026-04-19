import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: favoritesView

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
                    text: {
                        var c = appViewModel ? appViewModel.favoriteList.count : 0
                        return c + (c === 1 ? " favorite" : " favorites")
                    }
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                }

                Item { Layout.fillWidth: true }
            }
        }

        ListView {
            id: favoritesList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appViewModel ? appViewModel.favoriteList : null
            spacing: Theme.spacingXs

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: favoritesList.width - Theme.spacingMd * 2
                height: 64
                x: Theme.spacingMd
                radius: Theme.borderRadius
                color: favHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.color: favHovered ? Theme.accent + "40" : "transparent"
                border.width: 1

                property bool favHovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    spacing: Theme.spacingMd

                    Text {
                        text: (index + 1).toString()
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        color: Theme.textMuted
                        Layout.preferredWidth: 28
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: Theme.borderRadiusSmall
                        color: Theme.surface
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: model.logoUrl || ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "📺"
                            font.pixelSize: Theme.fontSizeSm
                            visible: !model.logoUrl
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.name
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: model.type
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: removeHovered ? Theme.error + "30" : "transparent"

                        property bool removeHovered: false

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            color: parent.removeHovered ? Theme.error : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.removeHovered = true
                            onExited: parent.removeHovered = false
                            onClicked: {
                                if (appViewModel) {
                                    appViewModel.favoriteList.toggleFavorite(model.channelId)
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.favHovered = true
                    onExited: parent.favHovered = false
                    onClicked: {
                        if (appViewModel) {
                            appViewModel.player.play(model.streamUrl, model.name, model.logoUrl, model.channelId)
                            appViewModel.currentView = "player"
                        }
                    }

                    z: -1
                }
            }

            Text {
                anchors.centerIn: parent
                visible: favoritesList.count === 0
                text: "No favorites yet.\nClick the star on any channel to add it here."
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }
    }
}
