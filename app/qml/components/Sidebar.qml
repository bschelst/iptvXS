// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Rectangle {
    id: sidebar

    property bool collapsed: false
    property string activeItem: "home"
    readonly property var navigationItems: [
        "home", "servers", "channels", "epg", "vod_movies", "vod_series",
        "favorites", "groups", "recordings", "history", "speedtest", "log", "settings"
    ]

    signal itemClicked(string name)

    Layout.preferredWidth: collapsed ? Theme.sidebarCollapsedWidth : Theme.sidebarWidth
    color: Theme.surface
    focus: true
    activeFocusOnTab: true

    function navigate(delta) {
        var idx = navigationItems.indexOf(activeItem)
        if (idx < 0) idx = 0
        idx = Math.max(0, Math.min(navigationItems.length - 1, idx + delta))
        activeItem = navigationItems[idx]
    }

    Keys.onUpPressed: navigate(-1)
    Keys.onDownPressed: navigate(1)
    Keys.onReturnPressed: itemClicked(activeItem)
    Keys.onEnterPressed: itemClicked(activeItem)
    Keys.onRightPressed: {
        if (Window.window && Window.window.focusCurrentViewSecondary) {
            Window.window.focusCurrentViewSecondary()
        }
    }

    Behavior on Layout.preferredWidth {
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
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.bottomMargin: Theme.spacingMd

            Row {
                anchors.centerIn: parent
                spacing: 0

                Text {
                    text: "iptv"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    font.italic: true
                    color: Theme.textSecondary
                    visible: !sidebar.collapsed
                }

                Text {
                    text: "XS"
                    font.pixelSize: sidebar.collapsed ? Theme.fontSizeMd : Theme.fontSizeXl
                    font.bold: true
                    font.italic: true
                    color: Theme.accent
                }
            }
        }

        Text {
            visible: !sidebar.collapsed
            text: "MAIN"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.5
            color: Theme.textMuted
            opacity: 0.6
            Layout.leftMargin: Theme.spacingLg
            Layout.bottomMargin: 4
        }

        Repeater {
            model: [
                { name: "home", icon: "🏠", label: "Home" },
                { name: "servers", icon: "🔗", label: "Servers" },
                { name: "channels", icon: "📺", label: "Live TV" },
                { name: "epg", icon: "📅", label: "TV Guide" },
                { name: "vod_movies", icon: "🎬", label: "VOD Movies" },
                { name: "vod_series", icon: "📀", label: "VOD Series" },
                { name: "favorites", icon: "★", label: "Favorites" },
                { name: "groups", icon: "📁", label: "Groups" },
                { name: "recordings", icon: "⏺", label: "Recordings" },
                { name: "history", icon: "🕐", label: "Play History" }
            ]

            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: Theme.spacingSm
                Layout.rightMargin: Theme.spacingSm
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                radius: 12
                color: sidebar.activeItem === modelData.name
                    ? Theme.accent
                    : hovered ? Theme.surfaceHover : "transparent"
                border.width: sidebar.activeFocus && sidebar.activeItem === modelData.name ? 2 : 0
                border.color: sidebar.activeFocus && sidebar.activeItem === modelData.name
                    ? Theme.textOnAccent
                    : "transparent"

                property bool hovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: sidebar.collapsed ? 0 : Theme.spacingMd
                    anchors.right: parent.right
                    anchors.rightMargin: sidebar.collapsed ? 0 : Theme.spacingSm
                    spacing: Theme.spacingSm

                    Item {
                        width: sidebar.collapsed ? parent.width : 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 18
                            color: sidebar.activeItem === modelData.name
                                ? Theme.textOnAccent : Theme.textSecondary
                        }
                    }

                    Text {
                        visible: !sidebar.collapsed
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: sidebar.activeItem === modelData.name ? Font.DemiBold : Font.Normal
                        color: sidebar.activeItem === modelData.name
                            ? Theme.textOnAccent
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
                        sidebar.forceActiveFocus()
                        sidebar.itemClicked(modelData.name)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spacingLg
            Layout.rightMargin: Theme.spacingLg
            Layout.bottomMargin: Theme.spacingSm
            height: 1
            color: Theme.surfaceBorder
            opacity: 0.5
        }

        Text {
            visible: !sidebar.collapsed
            text: "TOOLS"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 1.5
            color: Theme.textMuted
            opacity: 0.6
            Layout.leftMargin: Theme.spacingLg
            Layout.bottomMargin: 4
        }

        Repeater {
            model: [
                { name: "speedtest", icon: "⚡", label: "Speed Test" },
                { name: "log", icon: "📋", label: "App Log" },
                { name: "settings", icon: "⚙", label: "Settings" }
            ]

            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Layout.leftMargin: Theme.spacingSm
                Layout.rightMargin: Theme.spacingSm
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                radius: 12
                color: sidebar.activeItem === modelData.name
                    ? Theme.accent
                    : hovered ? Theme.surfaceHover : "transparent"
                border.width: sidebar.activeFocus && sidebar.activeItem === modelData.name ? 2 : 0
                border.color: sidebar.activeFocus && sidebar.activeItem === modelData.name
                    ? Theme.textOnAccent
                    : "transparent"

                property bool hovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: sidebar.collapsed ? 0 : Theme.spacingMd
                    anchors.right: parent.right
                    anchors.rightMargin: sidebar.collapsed ? 0 : Theme.spacingSm
                    spacing: Theme.spacingSm

                    Item {
                        width: sidebar.collapsed ? parent.width : 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: 18
                            color: sidebar.activeItem === modelData.name
                                ? Theme.textOnAccent : Theme.textSecondary
                        }
                    }

                    Text {
                        visible: !sidebar.collapsed
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: sidebar.activeItem === modelData.name ? Font.DemiBold : Font.Normal
                        color: sidebar.activeItem === modelData.name
                            ? Theme.textOnAccent
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
                        sidebar.forceActiveFocus()
                        sidebar.itemClicked(modelData.name)
                    }
                }
            }
        }

        Item { Layout.preferredHeight: Theme.spacingSm }
    }
}
