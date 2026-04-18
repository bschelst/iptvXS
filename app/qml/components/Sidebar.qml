import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Rectangle {
    id: sidebar

    property bool collapsed: false
    property string activeItem: "home"

    signal itemClicked(string name)

    width: collapsed ? Theme.sidebarCollapsedWidth : Theme.sidebarWidth
    color: Theme.surface

    Behavior on width {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.surfaceBorder
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.spacingMd
        spacing: Theme.spacingXs

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: Theme.spacingMd
            Layout.bottomMargin: Theme.spacingLg

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSm

                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme.borderRadius
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "X"
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                Text {
                    visible: !sidebar.collapsed
                    anchors.verticalCenter: parent.verticalCenter
                    text: "iptvxs"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animFast }
                    }
                }
            }
        }

        Repeater {
            model: [
                { name: "home", icon: "🏠", label: "Home" },
                { name: "servers", icon: "📡", label: "Servers" },
                { name: "channels", icon: "📺", label: "Channels" },
                { name: "favorites", icon: "⭐", label: "Favorites" },
                { name: "epg", icon: "📅", label: "TV Guide" },
                { name: "recordings", icon: "⏺", label: "Recordings" }
            ]

            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: Theme.spacingSm
                Layout.rightMargin: Theme.spacingSm
                radius: Theme.borderRadius
                color: sidebar.activeItem === modelData.name
                    ? Theme.accentGlow
                    : hovered ? Theme.surfaceHover : "transparent"

                property bool hovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Rectangle {
                    visible: sidebar.activeItem === modelData.name
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 24
                    radius: 2
                    color: Theme.accent
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingMd
                    spacing: Theme.spacingMd

                    Text {
                        text: modelData.icon
                        font.pixelSize: Theme.fontSizeMd
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: !sidebar.collapsed
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSm
                        color: sidebar.activeItem === modelData.name
                            ? Theme.textPrimary
                            : Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onClicked: {
                        sidebar.activeItem = modelData.name
                        sidebar.itemClicked(modelData.name)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Repeater {
            model: [
                { name: "speedtest", icon: "⚡", label: "Speed Test" },
                { name: "settings", icon: "⚙", label: "Settings" }
            ]

            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: Theme.spacingSm
                Layout.rightMargin: Theme.spacingSm
                Layout.bottomMargin: index === 1 ? Theme.spacingMd : 0
                radius: Theme.borderRadius
                color: sidebar.activeItem === modelData.name
                    ? Theme.accentGlow
                    : hovered ? Theme.surfaceHover : "transparent"

                property bool hovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingMd
                    spacing: Theme.spacingMd

                    Text {
                        text: modelData.icon
                        font.pixelSize: Theme.fontSizeMd
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: !sidebar.collapsed
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSm
                        color: sidebar.activeItem === modelData.name
                            ? Theme.textPrimary
                            : Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.hovered = true
                    onExited: parent.hovered = false
                    onClicked: {
                        sidebar.activeItem = modelData.name
                        sidebar.itemClicked(modelData.name)
                    }
                }
            }
        }
    }
}
