// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: serversView

    function focusPrimary() {
        if (serverListView.count > 0) {
            if (serverListView.currentIndex < 0) serverListView.currentIndex = 0
            serverListView.forceActiveFocus()
        } else if (epgSourceListView.count > 0) {
            if (epgSourceListView.currentIndex < 0) epgSourceListView.currentIndex = 0
            epgSourceListView.forceActiveFocus()
        } else if (addServerButton) {
            addServerButton.forceActiveFocus()
        }
    }

    ScrollView {
        id: serversScroll
        anchors.fill: parent
        contentWidth: availableWidth
        contentHeight: serversScrollContent.implicitHeight + Theme.spacingXl * 2
        clip: true

        Item {
            id: serversScrollContent
            width: serversScroll.availableWidth - Theme.spacingXl * 2
            height: implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter

            ColumnLayout {
                id: serversColumn
                width: parent.width
                spacing: Theme.spacingLg

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "IPTV Servers/Playlists"
                        font.pixelSize: Theme.fontSizeXl
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: addServerButton
                        Layout.topMargin: Theme.spacingSm
                        Layout.preferredWidth: addServerLabelRow.width + Theme.spacingLg * 2
                        Layout.preferredHeight: 40
                        radius: Theme.borderRadius
                        color: addServerHovered || addServerButton.activeFocus ? Theme.accentHover : Theme.accent
                        focus: false
                        activeFocusOnTab: true

                        property bool addServerHovered: false

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        Row {
                            id: addServerLabelRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingSm

                            Text {
                                text: "+"
                                font.pixelSize: Theme.fontSizeLg
                                font.bold: true
                                color: Theme.textOnAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Add Server"
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: Theme.textOnAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.addServerHovered = true
                            onExited: parent.addServerHovered = false
                            onClicked: addServerDialog.open()
                        }

                        Keys.onDownPressed: {
                            if (serverListView.count > 0) {
                                if (serverListView.currentIndex < 0) serverListView.currentIndex = 0
                                serverListView.forceActiveFocus()
                            } else if (epgSourceListView.count > 0) {
                                if (epgSourceListView.currentIndex < 0) epgSourceListView.currentIndex = 0
                                epgSourceListView.forceActiveFocus()
                            } else if (addEpgButton) {
                                addEpgButton.forceActiveFocus()
                            }
                        }
                        Keys.onReturnPressed: addServerDialog.open()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                addServerDialog.open()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Back) {
                                if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                event.accepted = true
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Theme.borderRadiusLarge
                    color: Theme.surfaceElevated
                    border.color: Theme.surfaceBorder
                    border.width: 1
                    implicitHeight: iptvCardLayout.implicitHeight + Theme.spacingMd * 2

                    ColumnLayout {
                        id: iptvCardLayout
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingMd

                        Rectangle {
                            visible: appViewModel && appViewModel.serverList.syncing
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: Theme.borderRadius
                            color: Theme.surfaceElevated
                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
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

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(220, Math.min(serverListView.contentHeight, 520))

                            ListView {
                                id: serverListView
                                anchors.fill: parent
                                spacing: Theme.spacingSm
                                clip: true
                                keyNavigationEnabled: true
                                highlightFollowsCurrentItem: true
                                currentIndex: -1
                                model: appViewModel ? appViewModel.serverList : null

                                Keys.onUpPressed: {
                                    if (currentIndex > 0) {
                                        currentIndex--
                                    } else if (addServerButton) {
                                        addServerButton.forceActiveFocus()
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (currentIndex < count - 1) {
                                        currentIndex++
                                    } else if (epgSourceListView.count > 0) {
                                        if (epgSourceListView.currentIndex < 0) epgSourceListView.currentIndex = 0
                                        epgSourceListView.forceActiveFocus()
                                    } else if (addEpgButton) {
                                        addEpgButton.forceActiveFocus()
                                    }
                                }
                                Keys.onLeftPressed: {
                                    if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                }
                                Keys.onReturnPressed: {
                                    if (currentIndex >= 0 && appViewModel
                                            && !(appViewModel.serverList && appViewModel.serverList.syncing))
                                        appViewModel.serverList.syncServer(currentIndex)
                                }
                                Keys.onEnterPressed: Keys.onReturnPressed(event)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                        Keys.onReturnPressed(event)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Delete) {
                                        if (currentIndex >= 0 && appViewModel)
                                            appViewModel.serverList.removeServer(currentIndex)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Y) {
                                        addServerDialog.open()
                                        event.accepted = true
                                    }
                                }

                                delegate: Rectangle {
                                    width: serverListView.width
                                    height: 132
                                    radius: Theme.borderRadiusLarge
                                    color: model.enabled
                                        ? (delegateHovered ? Theme.surfaceHover : Theme.surfaceElevated)
                                        : Theme.surface
                                    border.color: {
                                        if (serverListView.activeFocus && serverListView.currentIndex === index) return Theme.accent
                                        if (model.isPrimary) return Theme.accent
                                        if (delegateHovered) return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                                        return Theme.surfaceBorder
                                    }
                                    border.width: (serverListView.activeFocus && serverListView.currentIndex === index) ? 2 : (model.isPrimary ? 2 : 1)
                                    opacity: model.enabled ? 1.0 : 0.5

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
                                            color: model.type === "xtream"
                                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)
                                                : Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.13)

                                            Text {
                                                anchors.centerIn: parent
                                                text: model.type === "xtream" ? "📡" : "📋"
                                                font.pixelSize: Theme.fontSizeXl
                                            }
                                        }

                                        ColumnLayout {
                                            id: serverInfoCol
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingXs

                                            readonly property bool builtinFree:
                                                appViewModel && appViewModel.serverList
                                                    ? serverId === appViewModel.serverList.builtinFreeServerId()
                                                    : false

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: Theme.spacingSm

                                                Text {
                                                    text: model.name
                                                    font.pixelSize: Theme.fontSizeMd
                                                    font.bold: true
                                                    color: Theme.textPrimary
                                                }

                                                Rectangle {
                                                    visible: serverInfoCol.builtinFree
                                                    Layout.preferredWidth: freeBadgeText.implicitWidth + Theme.spacingSm * 2
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.18)
                                                    border.color: Theme.success
                                                    border.width: 1

                                                    Text {
                                                        id: freeBadgeText
                                                        anchors.centerIn: parent
                                                        text: "BUILT-IN"
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.bold: true
                                                        color: Theme.success
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }
                                            }

                                            Text {
                                                text: serverInfoCol.builtinFree
                                                    ? "Built-in iptvXS Free server"
                                                    : (model.type === "xtream"
                                                        ? model.url + " · " + model.username
                                                        : model.url)
                                                font.pixelSize: Theme.fontSizeSm
                                                color: Theme.textSecondary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: model.epgSourceName
                                                    ? "EPG: " + model.epgSourceName
                                                    : (model.type === "xtream"
                                                        ? "EPG: Built-in EPG"
                                                        : "EPG: not set")
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.textMuted
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            RowLayout {
                                                spacing: Theme.spacingMd

                                                Text {
                                                    text: {
                                                        var parts = []
                                                        if (model.channelCount > 0) parts.push(model.channelCount + " live")
                                                        if (model.vodCount > 0) parts.push(model.vodCount + " VOD")
                                                        if (model.seriesCount > 0) parts.push(model.seriesCount + " series")
                                                        return parts.length > 0 ? parts.join(" · ") : "No channels"
                                                    }
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
                                            color: primaryBtnHovered ? Theme.surfaceHover : "transparent"

                                            property bool primaryBtnHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: model.isPrimary ? "\u2B50" : "\u2606"
                                                font.pixelSize: 18
                                                color: model.isPrimary ? Theme.warning : Theme.textMuted
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: parent.primaryBtnHovered = true
                                                onExited: parent.primaryBtnHovered = false
                                                onClicked: {
                                                    if (appViewModel)
                                                        appViewModel.serverList.setPrimary(index)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 48
                                            Layout.preferredHeight: 26
                                            radius: 13
                                            color: model.enabled ? Theme.accent : Theme.surfaceBorder

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.animFast }
                                            }

                                            Rectangle {
                                                width: 20
                                                height: 20
                                                radius: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: model.enabled ? parent.width - width - 3 : 3
                                                color: "#ffffff"

                                                Behavior on x {
                                                    NumberAnimation { duration: Theme.animFast }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (appViewModel)
                                                        appViewModel.serverList.setEnabled(index, !model.enabled)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            readonly property bool disabled: serverInfoCol.builtinFree
                                            color: disabled
                                                ? "transparent"
                                                : (editBtnHovered ? Theme.surfaceHover : "transparent")
                                            opacity: disabled ? 0.35 : 1.0

                                            property bool editBtnHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✎"
                                                color: parent.disabled ? Theme.textMuted : Theme.textSecondary
                                                font.pixelSize: Theme.fontSizeMd
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: parent.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                enabled: !parent.disabled
                                                onEntered: parent.editBtnHovered = true
                                                onExited: parent.editBtnHovered = false
                                                onClicked: {
                                                    addServerDialog.openForEdit(
                                                        index, model.name, model.type,
                                                        model.url, model.username,
                                                        appViewModel.serverList.passwordAt(index),
                                                        model.epgSourceId,
                                                        serverId === appViewModel.serverList.builtinFreeServerId())
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            readonly property bool syncBusy: appViewModel && appViewModel.serverList
                                                                             ? appViewModel.serverList.syncing
                                                                             : false
                                            color: syncBusy
                                                ? "transparent"
                                                : (syncBtnHovered ? Theme.surfaceHover : "transparent")
                                            opacity: syncBusy ? 0.35 : 1.0

                                            property bool syncBtnHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: "⟳"
                                                font.pixelSize: 20
                                                color: parent.syncBusy ? Theme.textMuted : Theme.textSecondary
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !parent.syncBusy
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
                                            color: delBtnHovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.19) : "transparent"

                                            property bool delBtnHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                font.pixelSize: 18
                                                font.bold: true
                                                color: parent.delBtnHovered ? "#ffffff" : Theme.error
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
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: serverListView.count === 0
                                text: "No IPTV servers yet.\nClick 'Add Server' to get started."
                                font.pixelSize: Theme.fontSizeMd
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 1.5
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.spacingLg
                }

                Rectangle {
                    Layout.fillWidth: true
                    radius: Theme.borderRadiusLarge
                    color: Theme.surfaceElevated
                    border.color: Theme.surfaceBorder
                    border.width: 1
                    implicitHeight: epgCardLayout.implicitHeight + Theme.spacingMd * 2

                    ColumnLayout {
                        id: epgCardLayout
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingMd

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: "EPG Servers/Playlists"
                                font.pixelSize: Theme.fontSizeLg
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                id: addEpgButton
                                Layout.topMargin: Theme.spacingSm
                                Layout.preferredWidth: addEpgLabelRow.width + Theme.spacingLg * 2
                                Layout.preferredHeight: 40
                                radius: Theme.borderRadius
                                color: addEpgHovered || addEpgButton.activeFocus ? Theme.accentHover : Theme.accent
                                focus: false
                                activeFocusOnTab: true

                                property bool addEpgHovered: false

                                Row {
                                    id: addEpgLabelRow
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingSm

                                    Text {
                                        text: "+"
                                        font.pixelSize: Theme.fontSizeLg
                                        font.bold: true
                                        color: Theme.textOnAccent
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Add EPG Source"
                                        font.pixelSize: Theme.fontSizeSm
                                        font.bold: true
                                        color: Theme.textOnAccent
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.addEpgHovered = true
                                    onExited: parent.addEpgHovered = false
                                    onClicked: addEpgDialog.open()
                                }

                                Keys.onUpPressed: {
                                    if (serverListView.count > 0) {
                                        if (serverListView.currentIndex < 0) {
                                            serverListView.currentIndex = Math.max(0, serverListView.count - 1)
                                        }
                                        serverListView.forceActiveFocus()
                                    } else if (addServerButton) {
                                        addServerButton.forceActiveFocus()
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (epgSourceListView.count > 0) {
                                        if (epgSourceListView.currentIndex < 0) epgSourceListView.currentIndex = 0
                                        epgSourceListView.forceActiveFocus()
                                    }
                                }
                                Keys.onLeftPressed: {
                                    if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                }
                                Keys.onReturnPressed: addEpgDialog.open()
                                Keys.onEnterPressed: Keys.onReturnPressed(event)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                        addEpgDialog.open()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Back) {
                                        if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                        event.accepted = true
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(180, Math.min(epgSourceListView.contentHeight, 360))

                            ListView {
                                id: epgSourceListView
                                anchors.fill: parent
                                spacing: Theme.spacingSm
                                clip: true
                                keyNavigationEnabled: true
                                highlightFollowsCurrentItem: true
                                currentIndex: -1
                                model: appViewModel ? appViewModel.epgSourceList : null

                                Keys.onDownPressed: {
                                    if (currentIndex < count - 1) currentIndex++
                                }
                                Keys.onReturnPressed: {
                                    if (currentIndex >= 0 && appViewModel)
                                        appViewModel.epgSourceList.syncSource(currentIndex)
                                }
                                Keys.onEnterPressed: Keys.onReturnPressed(event)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                        Keys.onReturnPressed(event)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Back) {
                                        if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                        event.accepted = true
                                    }
                                }
                                Keys.onUpPressed: {
                                    if (currentIndex > 0) {
                                        currentIndex--
                                    } else if (addEpgButton) {
                                        addEpgButton.forceActiveFocus()
                                    }
                                }

                                delegate: Rectangle {
                                    width: epgSourceListView.width
                                    height: 92
                                    radius: Theme.borderRadiusLarge
                                    color: model.enabled
                                        ? (epgHovered ? Theme.surfaceHover : Theme.surfaceElevated)
                                        : Theme.surface
                                    border.color: epgSourceListView.activeFocus && epgSourceListView.currentIndex === index
                                        ? Theme.accent : Theme.surfaceBorder
                                    border.width: epgSourceListView.activeFocus && epgSourceListView.currentIndex === index ? 2 : 1
                                    opacity: model.enabled ? 1.0 : 0.55

                                    property bool epgHovered: false

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.epgHovered = true
                                        onExited: parent.epgHovered = false
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingMd
                                        spacing: Theme.spacingMd

                                        Rectangle {
                                            Layout.preferredWidth: 56
                                            Layout.preferredHeight: 56
                                            radius: Theme.borderRadius
                                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🗓"
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
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: model.url
                                                font.pixelSize: Theme.fontSizeSm
                                                color: Theme.textSecondary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            RowLayout {
                                                spacing: Theme.spacingMd

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
                                            color: epgPrimaryHovered ? Theme.surfaceHover : "transparent"
                                            property bool epgPrimaryHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: model.isPrimary ? "\u2B50" : "\u2606"
                                                font.pixelSize: 18
                                                color: model.isPrimary ? Theme.warning : Theme.textMuted
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: parent.epgPrimaryHovered = true
                                                onExited: parent.epgPrimaryHovered = false
                                                onClicked: {
                                                    if (appViewModel)
                                                        appViewModel.epgSourceList.setPrimary(index)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 48
                                            Layout.preferredHeight: 26
                                            radius: 13
                                            color: model.enabled ? Theme.accent : Theme.surfaceBorder

                                            Behavior on color {
                                                ColorAnimation { duration: Theme.animFast }
                                            }

                                            Rectangle {
                                                width: 20
                                                height: 20
                                                radius: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                x: model.enabled ? parent.width - width - 3 : 3
                                                color: "#ffffff"

                                                Behavior on x {
                                                    NumberAnimation { duration: Theme.animFast }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (appViewModel)
                                                        appViewModel.epgSourceList.setEnabled(index, !model.enabled)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            color: epgEditHovered ? Theme.surfaceHover : "transparent"
                                            property bool epgEditHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✎"
                                                color: Theme.textSecondary
                                                font.pixelSize: Theme.fontSizeMd
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: parent.epgEditHovered = true
                                                onExited: parent.epgEditHovered = false
                                                onClicked: {
                                                    addEpgDialog.openForEdit(index, model.name, model.url)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            readonly property bool syncBusy: appViewModel && appViewModel.epgSourceList
                                                                             ? appViewModel.epgSourceList.syncing
                                                                             : false
                                            color: syncBusy
                                                ? "transparent"
                                                : (epgSyncHovered ? Theme.surfaceHover : "transparent")
                                            opacity: syncBusy ? 0.35 : 1.0

                                            property bool epgSyncHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: "⟳"
                                                font.pixelSize: 20
                                                color: parent.syncBusy ? Theme.textMuted : Theme.textSecondary
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !parent.syncBusy
                                                onEntered: parent.epgSyncHovered = true
                                                onExited: parent.epgSyncHovered = false
                                                onClicked: {
                                                    if (appViewModel)
                                                        appViewModel.epgSourceList.syncSource(index)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            color: epgDelHovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.19) : "transparent"

                                            property bool epgDelHovered: false

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                font.pixelSize: 18
                                                font.bold: true
                                                color: parent.epgDelHovered ? "#ffffff" : Theme.error
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: parent.epgDelHovered = true
                                                onExited: parent.epgDelHovered = false
                                                onClicked: {
                                                    if (appViewModel)
                                                        appViewModel.epgSourceList.removeSource(index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: epgSourceListView.count === 0
                                text: "No EPG sources yet.\nClick 'Add EPG Source' to get started."
                                font.pixelSize: Theme.fontSizeMd
                                color: Theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 1.5
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.spacingXl
                }

                Text {
                    Layout.fillWidth: true
                    visible: serverListView.count === 0 && epgSourceListView.count === 0
                    text: "No IPTV servers added yet.\nClick 'Add Server' to get started."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }
            }
        }
    }

    AddServerDialog {
        id: addServerDialog
    }

    AddEpgSourceDialog {
        id: addEpgDialog
    }
}
