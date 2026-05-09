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
            if (serverListView.currentIndex < 0 || serverListView.currentIndex >= serverListView.count) {
                serverListView.currentIndex = 0
            }
            serverListView.forceActiveFocus()
        } else if (epgSourceListView.count > 0) {
            if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                epgSourceListView.currentIndex = 0
            }
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

        ScrollBar.vertical: ScrollBar {
            active: true
            policy: ScrollBar.AlwaysOn
            visible: true
            implicitWidth: 10
            contentItem: Rectangle {
                implicitWidth: 10
                radius: 5
                color: Theme.accent
                opacity: 0.85
            }
            background: Rectangle {
                implicitWidth: 10
                radius: 5
                color: Qt.rgba(Theme.surfaceBorder.r, Theme.surfaceBorder.g, Theme.surfaceBorder.b, 0.7)
            }
        }

        Item {
            id: serversScrollContent
            width: serversScroll.availableWidth - Theme.spacingXl * 2
            implicitHeight: serversColumn.implicitHeight
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
                                if (serverListView.currentIndex < 0 || serverListView.currentIndex >= serverListView.count) {
                                    serverListView.currentIndex = 0
                                }
                                serverListView.forceActiveFocus()
                            } else if (epgSourceListView.count > 0) {
                                if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                    epgSourceListView.currentIndex = 0
                                }
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

                                onCountChanged: {
                                    if (count <= 0) {
                                        currentIndex = -1
                                    } else if (currentIndex < 0 || currentIndex >= count) {
                                        currentIndex = 0
                                    }
                                }

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
                                        if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                            epgSourceListView.currentIndex = 0
                                        }
                                        epgSourceListView.forceActiveFocus()
                                    } else if (addEpgButton) {
                                        addEpgButton.forceActiveFocus()
                                    }
                                }
                                Keys.onLeftPressed: {
                                    if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                }
                                Keys.onRightPressed: {
                                    if (currentIndex < 0) return
                                    var item = currentItem
                                    if (item && item.serverInfoCol && item.serverInfoCol.focusActionAt) {
                                        item.serverInfoCol.focusActionAt(0)
                                    } else if (currentIndex >= 0 && appViewModel
                                               && !(appViewModel.serverList && appViewModel.serverList.syncing)) {
                                        appViewModel.serverList.syncServer(currentIndex)
                                    }
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
                                    focus: serverListView.activeFocus && serverListView.currentIndex === index
                                    activeFocusOnTab: true
                                    color: model.enabled
                                        ? (delegateHovered ? Theme.surfaceHover : Theme.surfaceElevated)
                                        : Theme.surface
                                    border.color: {
                                        if (serverInfoCol.actionFocused) return Theme.accent
                                        if (serverListView.activeFocus && serverListView.currentIndex === index) return Theme.accent
                                        if (model.isPrimary) return Theme.accent
                                        if (delegateHovered) return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                                        return Theme.surfaceBorder
                                    }
                                    border.width: (serverInfoCol.actionFocused || (serverListView.activeFocus && serverListView.currentIndex === index)) ? 2 : (model.isPrimary ? 2 : 1)
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
                                        onClicked: serverInfoCol.focusRow()
                                    }

                                    Keys.onRightPressed: serverInfoCol.focusActionAt(0)
                                    Keys.onLeftPressed: {
                                        if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                    }
                                    Keys.onUpPressed: {
                                        if (index > 0) {
                                            serverListView.currentIndex = index - 1
                                            serverListView.forceActiveFocus()
                                            serverInfoCol.focusActionAt(0)
                                        } else if (addServerButton) {
                                            addServerButton.forceActiveFocus()
                                        }
                                    }
                                    Keys.onDownPressed: {
                                        if (index < serverListView.count - 1) {
                                            serverListView.currentIndex = index + 1
                                            serverListView.forceActiveFocus()
                                            serverInfoCol.focusActionAt(0)
                                        } else if (epgSourceListView.count > 0) {
                                            if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                                epgSourceListView.currentIndex = 0
                                            }
                                            epgSourceListView.forceActiveFocus()
                                        } else if (addEpgButton) {
                                            addEpgButton.forceActiveFocus()
                                        }
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

                                            readonly property bool actionFocused:
                                                primaryBtn.activeFocus
                                                || enabledBtn.activeFocus
                                                || editBtn.activeFocus
                                                || syncBtn.activeFocus
                                                || delBtn.activeFocus

                                            function focusRow() {
                                                serverListView.currentIndex = index
                                                serverListView.forceActiveFocus()
                                            }

                                            function focusActionAt(actionIndex) {
                                                serverListView.currentIndex = index
                                                var actions = [primaryBtn, enabledBtn, editBtn, syncBtn, delBtn]
                                                actionIndex = Math.max(0, Math.min(actions.length - 1, actionIndex))
                                                var item = actions[actionIndex]
                                                if (item) item.forceActiveFocus()
                                            }

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
                                            id: primaryBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            color: primaryBtnHovered || activeFocus ? Theme.surfaceHover : "transparent"

                                            property bool primaryBtnHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: serverInfoCol.focusRow()
                                            Keys.onRightPressed: enabledBtn.forceActiveFocus()
                                            Keys.onUpPressed: {
                                                if (index > 0) {
                                                    serverListView.currentIndex = index - 1
                                                    serverListView.forceActiveFocus()
                                                    primaryBtn.forceActiveFocus()
                                                } else if (addServerButton) {
                                                    addServerButton.forceActiveFocus()
                                                }
                                            }
                                            Keys.onDownPressed: {
                                                if (index < serverListView.count - 1) {
                                                    serverListView.currentIndex = index + 1
                                                    serverListView.forceActiveFocus()
                                                    primaryBtn.forceActiveFocus()
                                                } else if (epgSourceListView.count > 0) {
                                                    if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                                        epgSourceListView.currentIndex = 0
                                                    }
                                                    epgSourceListView.forceActiveFocus()
                                                } else if (addEpgButton) {
                                                    addEpgButton.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: enabledBtn
                                            Layout.preferredWidth: 48
                                            Layout.preferredHeight: 26
                                            radius: 13
                                            color: model.enabled ? Theme.accent : Theme.surfaceBorder
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: primaryBtn.forceActiveFocus()
                                            Keys.onRightPressed: editBtn.forceActiveFocus()
                                            Keys.onUpPressed: primaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < serverListView.count - 1) {
                                                    serverListView.currentIndex = index + 1
                                                    serverListView.forceActiveFocus()
                                                    enabledBtn.forceActiveFocus()
                                                } else if (epgSourceListView.count > 0) {
                                                    if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                                        epgSourceListView.currentIndex = 0
                                                    }
                                                    epgSourceListView.forceActiveFocus()
                                                } else if (addEpgButton) {
                                                    addEpgButton.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: editBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            readonly property bool disabled: serverInfoCol.builtinFree
                                            color: disabled
                                                ? "transparent"
                                                : (editBtnHovered || activeFocus ? Theme.surfaceHover : "transparent")
                                            opacity: disabled ? 0.35 : 1.0

                                            property bool editBtnHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: enabledBtn.forceActiveFocus()
                                            Keys.onRightPressed: syncBtn.forceActiveFocus()
                                            Keys.onUpPressed: primaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < serverListView.count - 1) {
                                                    serverListView.currentIndex = index + 1
                                                    serverListView.forceActiveFocus()
                                                    editBtn.forceActiveFocus()
                                                } else if (epgSourceListView.count > 0) {
                                                    if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                                        epgSourceListView.currentIndex = 0
                                                    }
                                                    epgSourceListView.forceActiveFocus()
                                                } else if (addEpgButton) {
                                                    addEpgButton.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: syncBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            readonly property bool syncBusy: appViewModel && appViewModel.serverList
                                                                             ? appViewModel.serverList.syncing
                                                                             : false
                                            color: syncBusy
                                                ? "transparent"
                                                : (syncBtnHovered || activeFocus ? Theme.surfaceHover : "transparent")
                                            opacity: syncBusy ? 0.35 : 1.0

                                            property bool syncBtnHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: editBtn.forceActiveFocus()
                                            Keys.onRightPressed: delBtn.forceActiveFocus()
                                            Keys.onUpPressed: primaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < serverListView.count - 1) {
                                                    serverListView.currentIndex = index + 1
                                                    serverListView.forceActiveFocus()
                                                    syncBtn.forceActiveFocus()
                                                } else if (epgSourceListView.count > 0) {
                                                    if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                                        epgSourceListView.currentIndex = 0
                                                    }
                                                    epgSourceListView.forceActiveFocus()
                                                } else if (addEpgButton) {
                                                    addEpgButton.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: delBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            color: delBtnHovered || activeFocus
                                                ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.19)
                                                : "transparent"

                                            property bool delBtnHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.error

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

                                            Keys.onLeftPressed: syncBtn.forceActiveFocus()
                                            Keys.onRightPressed: serverInfoCol.focusRow()
                                            Keys.onUpPressed: primaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < serverListView.count - 1) {
                                                    serverListView.currentIndex = index + 1
                                                    serverListView.forceActiveFocus()
                                                    delBtn.forceActiveFocus()
                                                } else if (epgSourceListView.count > 0) {
                                                    if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                                        epgSourceListView.currentIndex = 0
                                                    }
                                                    epgSourceListView.forceActiveFocus()
                                                } else if (addEpgButton) {
                                                    addEpgButton.forceActiveFocus()
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
                                        if (serverListView.currentIndex < 0 || serverListView.currentIndex >= serverListView.count) {
                                            serverListView.currentIndex = Math.max(0, serverListView.count - 1)
                                        }
                                        serverListView.forceActiveFocus()
                                    } else if (addServerButton) {
                                        addServerButton.forceActiveFocus()
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (epgSourceListView.count > 0) {
                                        if (epgSourceListView.currentIndex < 0 || epgSourceListView.currentIndex >= epgSourceListView.count) {
                                            epgSourceListView.currentIndex = 0
                                        }
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

                                onCountChanged: {
                                    if (count <= 0) {
                                        currentIndex = -1
                                    } else if (currentIndex < 0 || currentIndex >= count) {
                                        currentIndex = 0
                                    }
                                }

                                Keys.onDownPressed: {
                                    if (currentIndex < count - 1) currentIndex++
                                }
                                Keys.onRightPressed: {
                                    if (currentIndex < 0) return
                                    var item = currentItem
                                    if (item && item.epgInfoCol && item.epgInfoCol.focusActionAt) {
                                        item.epgInfoCol.focusActionAt(0)
                                    } else if (currentIndex >= 0 && appViewModel
                                               && !(appViewModel.epgSourceList && appViewModel.epgSourceList.syncing)) {
                                        appViewModel.epgSourceList.syncSource(currentIndex)
                                    }
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
                                    focus: epgSourceListView.activeFocus && epgSourceListView.currentIndex === index
                                    activeFocusOnTab: true
                                    color: model.enabled
                                        ? (epgHovered ? Theme.surfaceHover : Theme.surfaceElevated)
                                        : Theme.surface
                                    border.color: epgInfoCol.actionFocused || (epgSourceListView.activeFocus && epgSourceListView.currentIndex === index)
                                        ? Theme.accent : Theme.surfaceBorder
                                    border.width: (epgInfoCol.actionFocused || (epgSourceListView.activeFocus && epgSourceListView.currentIndex === index)) ? 2 : 1
                                    opacity: model.enabled ? 1.0 : 0.55

                                    property bool epgHovered: false
                                    readonly property bool actionFocused:
                                        epgPrimaryBtn.activeFocus
                                        || epgEnabledBtn.activeFocus
                                        || epgEditBtn.activeFocus
                                        || epgSyncBtn.activeFocus
                                        || epgDelBtn.activeFocus

                                    function focusRow() {
                                        epgSourceListView.currentIndex = index
                                        epgSourceListView.forceActiveFocus()
                                    }

                                    function focusActionAt(actionIndex) {
                                        epgSourceListView.currentIndex = index
                                        var actions = [epgPrimaryBtn, epgEnabledBtn, epgEditBtn, epgSyncBtn, epgDelBtn]
                                        actionIndex = Math.max(0, Math.min(actions.length - 1, actionIndex))
                                        var item = actions[actionIndex]
                                        if (item) item.forceActiveFocus()
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: parent.epgHovered = true
                                        onExited: parent.epgHovered = false
                                        onClicked: epgInfoCol.focusRow()
                                    }

                                    Keys.onRightPressed: epgInfoCol.focusActionAt(0)
                                    Keys.onLeftPressed: {
                                        if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                                    }
                                    Keys.onUpPressed: {
                                        if (index > 0) {
                                            epgSourceListView.currentIndex = index - 1
                                            epgSourceListView.forceActiveFocus()
                                            epgInfoCol.focusActionAt(0)
                                        } else if (addEpgButton) {
                                            addEpgButton.forceActiveFocus()
                                        }
                                    }
                                    Keys.onDownPressed: {
                                        if (index < epgSourceListView.count - 1) {
                                            epgSourceListView.currentIndex = index + 1
                                            epgSourceListView.forceActiveFocus()
                                            epgInfoCol.focusActionAt(0)
                                        }
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
                                            id: epgInfoCol
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingXs

                                            readonly property bool actionFocused:
                                                epgPrimaryBtn.activeFocus
                                                || epgEnabledBtn.activeFocus
                                                || epgEditBtn.activeFocus
                                                || epgSyncBtn.activeFocus
                                                || epgDelBtn.activeFocus

                                            function focusRow() {
                                                epgSourceListView.currentIndex = index
                                                epgSourceListView.forceActiveFocus()
                                            }

                                            function focusActionAt(actionIndex) {
                                                epgSourceListView.currentIndex = index
                                                var actions = [epgPrimaryBtn, epgEnabledBtn, epgEditBtn, epgSyncBtn, epgDelBtn]
                                                actionIndex = Math.max(0, Math.min(actions.length - 1, actionIndex))
                                                var item = actions[actionIndex]
                                                if (item) item.forceActiveFocus()
                                            }

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
                                            id: epgPrimaryBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            color: epgPrimaryHovered || activeFocus ? Theme.surfaceHover : "transparent"
                                            property bool epgPrimaryHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: epgInfoCol.focusRow()
                                            Keys.onRightPressed: epgEnabledBtn.forceActiveFocus()
                                            Keys.onUpPressed: {
                                                if (index > 0) {
                                                    epgSourceListView.currentIndex = index - 1
                                                    epgSourceListView.forceActiveFocus()
                                                    epgPrimaryBtn.forceActiveFocus()
                                                } else if (addEpgButton) {
                                                    addEpgButton.forceActiveFocus()
                                                }
                                            }
                                            Keys.onDownPressed: {
                                                if (index < epgSourceListView.count - 1) {
                                                    epgSourceListView.currentIndex = index + 1
                                                    epgSourceListView.forceActiveFocus()
                                                    epgPrimaryBtn.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: epgEnabledBtn
                                            Layout.preferredWidth: 48
                                            Layout.preferredHeight: 26
                                            radius: 13
                                            color: model.enabled ? Theme.accent : Theme.surfaceBorder
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: epgPrimaryBtn.forceActiveFocus()
                                            Keys.onRightPressed: epgEditBtn.forceActiveFocus()
                                            Keys.onUpPressed: epgPrimaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < epgSourceListView.count - 1) {
                                                    epgSourceListView.currentIndex = index + 1
                                                    epgSourceListView.forceActiveFocus()
                                                    epgEnabledBtn.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: epgEditBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            color: epgEditHovered || activeFocus ? Theme.surfaceHover : "transparent"
                                            property bool epgEditHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: epgEnabledBtn.forceActiveFocus()
                                            Keys.onRightPressed: epgSyncBtn.forceActiveFocus()
                                            Keys.onUpPressed: epgPrimaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < epgSourceListView.count - 1) {
                                                    epgSourceListView.currentIndex = index + 1
                                                    epgSourceListView.forceActiveFocus()
                                                    epgEditBtn.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: epgSyncBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            readonly property bool syncBusy: appViewModel && appViewModel.epgSourceList
                                                                             ? appViewModel.epgSourceList.syncing
                                                                             : false
                                            color: syncBusy
                                                ? "transparent"
                                                : (epgSyncHovered || activeFocus ? Theme.surfaceHover : "transparent")
                                            opacity: syncBusy ? 0.35 : 1.0

                                            property bool epgSyncHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.accent

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

                                            Keys.onLeftPressed: epgEditBtn.forceActiveFocus()
                                            Keys.onRightPressed: epgDelBtn.forceActiveFocus()
                                            Keys.onUpPressed: epgPrimaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < epgSourceListView.count - 1) {
                                                    epgSourceListView.currentIndex = index + 1
                                                    epgSourceListView.forceActiveFocus()
                                                    epgSyncBtn.forceActiveFocus()
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: epgDelBtn
                                            Layout.preferredWidth: 36
                                            Layout.preferredHeight: 36
                                            radius: Theme.borderRadius
                                            color: epgDelHovered || activeFocus ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.19) : "transparent"

                                            property bool epgDelHovered: false
                                            activeFocusOnTab: true
                                            border.width: activeFocus ? 2 : 0
                                            border.color: Theme.error

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

                                            Keys.onLeftPressed: epgSyncBtn.forceActiveFocus()
                                            Keys.onRightPressed: epgInfoCol.focusRow()
                                            Keys.onUpPressed: epgPrimaryBtn.forceActiveFocus()
                                            Keys.onDownPressed: {
                                                if (index < epgSourceListView.count - 1) {
                                                    epgSourceListView.currentIndex = index + 1
                                                    epgSourceListView.forceActiveFocus()
                                                    epgDelBtn.forceActiveFocus()
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
