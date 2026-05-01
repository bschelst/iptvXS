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
    readonly property bool compactMode: Window.window ? Window.window.width < 1400 || Window.window.height < 820 : false
    readonly property var mainItems: [
        { name: "home", label: "Home" },
        { name: "servers", label: "Servers" },
        { name: "channels", label: "Live TV" },
        { name: "epg", label: "TV Guide" },
        { name: "vod_movies", label: "VOD Movies" },
        { name: "vod_series", label: "VOD Series" },
        { name: "favorites", label: "Favorites" },
        { name: "groups", label: "Groups" },
        { name: "recordings", label: "Recordings" },
        { name: "history", label: "Play History" }
    ]
    readonly property var toolItems: [
        { name: "speedtest", label: "Speed Test" },
        { name: "log", label: "App Log" },
        { name: "settings", label: "Settings" }
    ]
    readonly property var navigationItems: [
        "home", "servers", "channels", "epg", "vod_movies", "vod_series",
        "favorites", "groups", "recordings", "history", "speedtest", "log", "settings"
    ]

    signal itemClicked(string name)

    Layout.preferredWidth: collapsed ? Theme.sidebarCollapsedWidth : (compactMode ? 220 : Theme.sidebarWidth)
    color: Theme.surface
    focus: true
    activeFocusOnTab: true
    clip: true

    function navigate(delta) {
        var idx = navigationItems.indexOf(activeItem)
        if (idx < 0) idx = 0
        idx = Math.max(0, Math.min(navigationItems.length - 1, idx + delta))
        activeItem = navigationItems[idx]
        Qt.callLater(function() { sidebar.ensureActiveItemVisible() })
    }

    function delegateForName(name) {
        var idx = -1
        for (var i = 0; i < mainItems.length; i++) {
            if (mainItems[i].name === name) {
                idx = i
                return mainRepeater.itemAt(idx)
            }
        }
        for (var j = 0; j < toolItems.length; j++) {
            if (toolItems[j].name === name) {
                idx = j
                return toolRepeater.itemAt(idx)
            }
        }
        return null
    }

    function ensureActiveItemVisible() {
        if (!sidebarScrollView || !sidebarScrollView.contentItem || collapsed) return
        var delegate = delegateForName(activeItem)
        if (!delegate) return
        var contentItem = sidebarScrollView.contentItem
        var local = delegate.mapToItem(contentItem, 0, 0)
        var top = local.y
        var bottom = top + delegate.height
        var viewTop = contentItem.contentY
        var viewBottom = viewTop + sidebarScrollView.height
        if (top < viewTop) {
            contentItem.contentY = Math.max(0, top - Theme.spacingSm)
        } else if (bottom > viewBottom) {
            contentItem.contentY = Math.max(0, bottom - sidebarScrollView.height + Theme.spacingSm)
        }
    }

    function itemTextColor(name) {
        if (activeItem === name) {
            return activeFocus ? Theme.textOnAccent : Theme.textPrimary
        }
        return Theme.textSecondary
    }

    function itemIconColor(name) {
        return (activeFocus && activeItem === name) ? Theme.textOnAccent : Theme.textPrimary
    }

    function itemIcon(name) {
        switch (name) {
        case "home":
            return "⌂"
        case "servers":
            return "↔"
        case "channels":
            return "▭"
        case "epg":
            return "▦"
        case "vod_movies":
            return "▶"
        case "vod_series":
            return "◫"
        case "favorites":
            return "★"
        case "groups":
            return "☷"
        case "recordings":
            return "●"
        case "history":
            return "↺"
        case "speedtest":
            return "↯"
        case "log":
            return "≡"
        case "settings":
            return "⚙"
        default:
            return "•"
        }
    }

    Keys.onUpPressed: navigate(-1)
    Keys.onDownPressed: navigate(1)
    Keys.onReturnPressed: itemClicked(activeItem)
    Keys.onEnterPressed: itemClicked(activeItem)
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
            itemClicked(activeItem)
            event.accepted = true
        }
    }
    Keys.onRightPressed: {
        if (Window.window && Window.window.pipMode) {
            Window.window.focusPip()
        } else if (Window.window && Window.window.focusCurrentViewPrimary) {
            Window.window.focusCurrentViewPrimary()
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
            Layout.preferredHeight: sidebar.collapsed ? 52 : (sidebar.compactMode ? 56 : 64)
            Layout.bottomMargin: Theme.spacingMd

            Row {
                anchors.centerIn: parent
                spacing: Theme.spacingSm

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "qrc:/images/iptvxs_logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    width: sidebar.collapsed ? 36 : (sidebar.compactMode ? 40 : 44)
                    height: sidebar.collapsed ? 36 : (sidebar.compactMode ? 40 : 44)
                }

                Text {
                    visible: !sidebar.collapsed
                    text: "iptvXS"
                    font.pixelSize: sidebar.compactMode ? Theme.fontSizeMd : Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        ScrollView {
            id: sidebarScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                width: parent.width
                spacing: 0

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
                    id: mainRepeater
                    model: sidebar.mainItems

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: sidebar.compactMode ? 44 : 50
                        Layout.leftMargin: Theme.spacingSm
                        Layout.rightMargin: Theme.spacingSm
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        radius: 14
                        clip: true
                        color: sidebar.activeItem === modelData.name
                            ? (sidebar.activeFocus ? Theme.accent
                                                   : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12))
                            : hovered ? Theme.surfaceHover : "transparent"
                        border.width: sidebar.activeItem === modelData.name ? 1 : 0
                        border.color: sidebar.activeFocus && sidebar.activeItem === modelData.name
                            ? Theme.textOnAccent
                            : (sidebar.activeItem === modelData.name ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45) : "transparent")

                        property bool hovered: false

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        Rectangle {
                            visible: sidebar.activeItem === modelData.name
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 26
                            radius: 2
                            color: Theme.accent
                            opacity: sidebar.activeFocus ? 1.0 : 0.9
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: sidebar.collapsed ? Theme.spacingSm : Theme.spacingMd + 6
                            anchors.right: parent.right
                            anchors.rightMargin: sidebar.collapsed ? Theme.spacingSm : Theme.spacingMd
                            spacing: Theme.spacingMd

                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: sidebar.itemIcon(modelData.name)
                                font.pixelSize: 18
                                font.family: "DejaVu Sans"
                                font.weight: Font.DemiBold
                                color: sidebar.itemIconColor(modelData.name)
                            }
                        }

                        Text {
                                visible: !sidebar.collapsed
                                text: modelData.label
                                font.pixelSize: sidebar.compactMode ? Theme.fontSizeXs : Theme.fontSizeSm
                                font.weight: sidebar.activeItem === modelData.name ? Font.Medium : Font.Normal
                                color: sidebar.itemTextColor(modelData.name)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - 34)
                                elide: Text.ElideRight
                                clip: true

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
                                Qt.callLater(function() { sidebar.ensureActiveItemVisible() })
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spacingLg
                    Layout.rightMargin: Theme.spacingLg
                    Layout.topMargin: Theme.spacingSm
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
                    id: toolRepeater
                    model: sidebar.toolItems

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: sidebar.compactMode ? 44 : 50
                        Layout.leftMargin: Theme.spacingSm
                        Layout.rightMargin: Theme.spacingSm
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        radius: 14
                        clip: true
                        color: sidebar.activeItem === modelData.name
                            ? (sidebar.activeFocus ? Theme.accent
                                                   : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12))
                            : hovered ? Theme.surfaceHover : "transparent"
                        border.width: sidebar.activeItem === modelData.name ? 1 : 0
                        border.color: sidebar.activeFocus && sidebar.activeItem === modelData.name
                            ? Theme.textOnAccent
                            : (sidebar.activeItem === modelData.name ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45) : "transparent")

                        property bool hovered: false

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        Rectangle {
                            visible: sidebar.activeItem === modelData.name
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 26
                            radius: 2
                            color: Theme.accent
                            opacity: sidebar.activeFocus ? 1.0 : 0.9
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: sidebar.collapsed ? Theme.spacingSm : Theme.spacingMd + 6
                            anchors.right: parent.right
                            anchors.rightMargin: sidebar.collapsed ? Theme.spacingSm : Theme.spacingMd
                            spacing: Theme.spacingMd

                        Item {
                            width: 24
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.centerIn: parent
                                text: sidebar.itemIcon(modelData.name)
                                font.pixelSize: 18
                                font.family: "DejaVu Sans"
                                font.weight: Font.DemiBold
                                color: sidebar.itemIconColor(modelData.name)
                            }
                        }

                        Text {
                                visible: !sidebar.collapsed
                                text: modelData.label
                                font.pixelSize: sidebar.compactMode ? Theme.fontSizeXs : Theme.fontSizeSm
                                font.weight: sidebar.activeItem === modelData.name ? Font.Medium : Font.Normal
                                color: sidebar.itemTextColor(modelData.name)
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, parent.width - 34)
                                elide: Text.ElideRight
                                clip: true
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
                                Qt.callLater(function() { sidebar.ensureActiveItemVisible() })
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.spacingSm }
            }
        }
    }
}
