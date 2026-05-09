// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: groupsView

    property int selectedGroupId: 0
    property string selectedGroupName: ""
    property string selectedGroupMode: "static"

    function clampListIndex(listView) {
        if (!listView) return
        if (listView.count <= 0) {
            listView.currentIndex = -1
        } else if (listView.currentIndex < 0 || listView.currentIndex >= listView.count) {
            listView.currentIndex = 0
        }
    }

    function focusMemberList() {
        if (memberListView.count > 0) {
            clampListIndex(memberListView)
            memberListView.forceActiveFocus()
        } else if (addChannelsBtn && addChannelsBtn.visible) {
            addChannelsBtn.forceActiveFocus()
        } else if (groupListView.count > 0) {
            groupListView.forceActiveFocus()
        }
    }

    function focusPrimary() {
        if (groupListView.count > 0) {
            clampListIndex(groupListView)
            groupListView.forceActiveFocus()
        } else if (addGroupBtn) {
            addGroupBtn.forceActiveFocus()
        }
    }

    function focusAddGroupButton() {
        if (addGroupBtn) addGroupBtn.forceActiveFocus()
    }

    function focusGroupList() {
        if (groupListView.count > 0) {
            clampListIndex(groupListView)
            groupListView.forceActiveFocus()
        } else if (addGroupBtn) {
            addGroupBtn.forceActiveFocus()
        } else if (Window.window && Window.window.focusSidebar) {
            Window.window.focusSidebar()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left panel — Group list
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            color: Theme.surface

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.surfaceBorder
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: 1
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingMd
                        anchors.rightMargin: Theme.spacingMd

                        Text {
                            text: "GROUPS"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.5
                            color: Theme.textMuted
                            opacity: 0.7
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: groupListModel.count
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignVCenter
                            Layout.rightMargin: 4
                        }

                        Rectangle {
                            id: addGroupBtn
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: addBtnHov || addGroupBtn.activeFocus ? Theme.accent : Theme.accentHover
                            border.width: addGroupBtn.activeFocus ? 2 : 0
                            border.color: "#ffffff"
                            property bool addBtnHov: false
                            focus: false
                            activeFocusOnTab: true

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 16
                                font.bold: true
                                color: Theme.textOnAccent
                            }

                            Keys.onReturnPressed: createGroupDialog.open()
                            Keys.onEnterPressed: createGroupDialog.open()
                            Keys.onDownPressed: {
                                if (groupListView.count > 0) {
                                    if (groupListView.currentIndex < 0) groupListView.currentIndex = 0
                                    groupListView.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (groupListView.count > 0) {
                                    if (groupListView.currentIndex < 0) groupListView.currentIndex = 0
                                    groupListView.forceActiveFocus()
                                }
                            }
                            Keys.onLeftPressed: {
                                if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                            }
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    createGroupDialog.open()
                                    event.accepted = true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.addBtnHov = true
                                onExited: parent.addBtnHov = false
                                onClicked: createGroupDialog.open()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spacingMd
                    Layout.rightMargin: Theme.spacingMd
                    height: 1
                    color: Theme.surfaceBorder
                }

                ListView {
                    id: groupListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: groupListModel
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: true
                    onCountChanged: groupsView.clampListIndex(groupListView)

                    Keys.onUpPressed: {
                        if (currentIndex > 0) currentIndex--
                        else groupsView.focusAddGroupButton()
                    }
                    Keys.onDownPressed: { if (currentIndex < count - 1) currentIndex++ }
                    Keys.onLeftPressed: {
                        if (Window.window && Window.window.focusSidebar)
                            Window.window.focusSidebar()
                    }
                    Keys.onRightPressed: {
                        if (groupListView.currentItem && groupListView.currentItem.grpEditBtn) {
                            groupListView.currentItem.grpEditBtn.forceActiveFocus()
                        } else {
                            groupsView.focusMemberList()
                        }
                    }
                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentIndex < count) {
                            var item = groupListModel.get(currentIndex)
                            selectedGroupId = item.gid
                            selectedGroupName = item.gname
                            selectedGroupMode = item.gmode || "static"
                            groupsView.reloadMembers()
                        }
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select) {
                            Keys.onReturnPressed(event)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Y) {
                            createGroupDialog.open()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                            if (currentIndex >= 0 && currentIndex < count) {
                                var delItem = groupListModel.get(currentIndex)
                                if (appViewModel && delItem) {
                                    appViewModel.groupList.deleteGroup(delItem.gid)
                                    if (selectedGroupId === delItem.gid) {
                                        selectedGroupId = 0
                                        selectedGroupName = ""
                                        memberListModel.clear()
                                    }
                                    groupsView.reloadGroups()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    delegate: Item {
                        width: groupListView.width
                        height: 52

                        Rectangle {
                            anchors.fill: parent
                            color: selectedGroupId === model.gid
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : grpHov ? Theme.surfaceHover : "transparent"
                            border.width: groupListView.activeFocus && groupListView.currentIndex === index ? 2 : 0
                            border.color: groupListView.activeFocus && groupListView.currentIndex === index
                                ? Theme.accent : "transparent"
                            property bool grpHov: false

                            Rectangle {
                                visible: selectedGroupId === model.gid
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3; height: 28; radius: 2
                                color: Theme.accent
                            }

                            Text {
                                id: grpIcon
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingMd
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uD83D\uDCC1"
                                font.pixelSize: 16
                            }

                            Column {
                                anchors.left: grpIcon.right
                                anchors.leftMargin: Theme.spacingSm
                                anchors.right: grpEditBtn.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: model.gname
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: selectedGroupId === model.gid
                                    color: selectedGroupId === model.gid
                                        ? Theme.textPrimary : Theme.textSecondary
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: model.gmode === "dynamic"
                                        ? (model.gmemberCount + (model.gmemberCount === 1 ? " item" : " items")
                                           + (model.gsummary ? " · " + model.gsummary : ""))
                                        : (model.gmemberCount + (model.gmemberCount === 1 ? " item" : " items"))
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textMuted
                                }
                            }

                            Rectangle {
                                id: grpEditBtn
                                anchors.right: grpDelBtn.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 24; radius: 12
                                color: editGrpHov ? Theme.surfaceHover : "transparent"
                                property bool editGrpHov: false

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u270E"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: parent.editGrpHov ? "#ffffff" : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.editGrpHov = true
                                    onExited: parent.editGrpHov = false
                                    onClicked: {
                                        editGroupDialog.openForGroup(model.gid, model.gname,
                                                                     model.gmode || "static",
                                                                     model.gscope || "any",
                                                                     model.gfield || "name",
                                                                     model.goperator || "contains",
                                                                     model.gfilterValue || "")
                                    }
                                }

                                Keys.onLeftPressed: groupListView.forceActiveFocus()
                                Keys.onRightPressed: {
                                    if (grpDelBtn) grpDelBtn.forceActiveFocus()
                                    else groupsView.focusMemberList()
                                }
                                Keys.onUpPressed: {
                                    if (groupListView.currentIndex > 0) {
                                        groupListView.currentIndex--
                                    }
                                    groupListView.forceActiveFocus()
                                }
                                Keys.onDownPressed: {
                                    if (groupListView.currentIndex < groupListView.count - 1) {
                                        groupListView.currentIndex++
                                    }
                                    groupListView.forceActiveFocus()
                                }
                                Keys.onReturnPressed: editGroupDialog.openForGroup(model.gid, model.gname,
                                                                                   model.gmode || "static",
                                                                                   model.gscope || "any",
                                                                                   model.gfield || "name",
                                                                                   model.goperator || "contains",
                                                                                   model.gfilterValue || "")
                                Keys.onEnterPressed: Keys.onReturnPressed(event)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                        editGroupDialog.openForGroup(model.gid, model.gname,
                                                                     model.gmode || "static",
                                                                     model.gscope || "any",
                                                                     model.gfield || "name",
                                                                     model.goperator || "contains",
                                                                     model.gfilterValue || "")
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                               || event.key === Qt.Key_Back) {
                                        groupListView.forceActiveFocus()
                                        event.accepted = true
                                    }
                                }
                            }

                            Rectangle {
                                id: grpDelBtn
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingSm
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22; radius: 11
                                color: delGrpHov ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.19) : "transparent"
                                property bool delGrpHov: false

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u232B"
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "DejaVu Sans"
                                    color: parent.delGrpHov ? "#ffffff" : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.delGrpHov = true
                                    onExited: parent.delGrpHov = false
                                    onClicked: {
                                        if (appViewModel) {
                                            appViewModel.groupList.deleteGroup(model.gid)
                                            if (selectedGroupId === model.gid) {
                                                selectedGroupId = 0
                                                selectedGroupName = ""
                                                selectedGroupMode = "static"
                                                memberListModel.clear()
                                            }
                                            groupsView.reloadGroups()
                                        }
                                    }
                                }

                                Keys.onLeftPressed: grpEditBtn.forceActiveFocus()
                                Keys.onRightPressed: groupsView.focusMemberList()
                                Keys.onUpPressed: {
                                    if (groupListView.currentIndex > 0) {
                                        groupListView.currentIndex--
                                    }
                                    groupListView.forceActiveFocus()
                                }
                                Keys.onDownPressed: {
                                    if (groupListView.currentIndex < groupListView.count - 1) {
                                        groupListView.currentIndex++
                                    }
                                    groupListView.forceActiveFocus()
                                }
                                Keys.onReturnPressed: {
                                    if (appViewModel) {
                                        appViewModel.groupList.deleteGroup(model.gid)
                                        if (selectedGroupId === model.gid) {
                                            selectedGroupId = 0
                                            selectedGroupName = ""
                                            selectedGroupMode = "static"
                                            memberListModel.clear()
                                        }
                                        groupsView.reloadGroups()
                                    }
                                }
                                Keys.onEnterPressed: Keys.onReturnPressed(event)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                        Keys.onReturnPressed(event)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                               || event.key === Qt.Key_Back) {
                                        groupListView.forceActiveFocus()
                                        event.accepted = true
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.grpHov = true
                                onExited: parent.grpHov = false
                                onClicked: {
                                    selectedGroupId = model.gid
                                    selectedGroupName = model.gname
                                    selectedGroupMode = model.gmode || "static"
                                    groupsView.reloadMembers()
                                }
                                z: -1
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: groupListView.count === 0
                        text: "No groups yet.\nClick + to create one."
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.5
                    }
                }
            }
        }

        // Right panel — Group members
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                        text: selectedGroupId > 0
                            ? selectedGroupName
                              + (selectedGroupMode === "dynamic" ? " (Dynamic)" : "")
                              + " (" + memberListModel.count + ")"
                            : "Select a group"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: selectedGroupId > 0
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        id: addChannelsBtn
                        visible: selectedGroupId > 0 && selectedGroupMode !== "dynamic"
                        Layout.preferredWidth: addChLabel.implicitWidth + 20
                        Layout.preferredHeight: 32
                        radius: Theme.borderRadius
                        color: addChHov ? Theme.accent : Theme.accentHover
                        focus: false
                        activeFocusOnTab: true
                        property bool addChHov: false

                        Text {
                            id: addChLabel
                            anchors.centerIn: parent
                            text: "+ Add Items"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textOnAccent
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.addChHov = true
                            onExited: parent.addChHov = false
                            onClicked: channelSearchDialog.open()
                        }

                        Keys.onLeftPressed: groupsView.focusGroupList()
                        Keys.onDownPressed: {
                            if (memberListView.count > 0) {
                                if (memberListView.currentIndex < 0 || memberListView.currentIndex >= memberListView.count) {
                                    memberListView.currentIndex = 0
                                }
                                memberListView.forceActiveFocus()
                            } else {
                                groupsView.focusMemberList()
                            }
                        }
                        Keys.onReturnPressed: channelSearchDialog.open()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                channelSearchDialog.open()
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            GridView {
                id: memberListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: memberListModel
                cellWidth: 210
                cellHeight: 180
                leftMargin: Theme.spacingMd
                rightMargin: Theme.spacingMd
                topMargin: Theme.spacingSm
                keyNavigationEnabled: true
                highlightFollowsCurrentItem: true
                property int cols: Math.max(1, Math.floor((width - leftMargin - rightMargin) / cellWidth))
                onCountChanged: groupsView.clampListIndex(memberListView)

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 6; radius: 3
                        color: Theme.accent
                        opacity: parent.active ? 0.8 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }
                    background: Rectangle { implicitWidth: 6; color: "transparent" }
                }

                Keys.onUpPressed: {
                    if (currentIndex >= cols) {
                        currentIndex -= cols
                    } else if (addChannelsBtn && addChannelsBtn.visible) {
                        addChannelsBtn.forceActiveFocus()
                    } else {
                        groupsView.focusGroupList()
                    }
                }
                Keys.onDownPressed: {
                    if (currentIndex + cols < count) {
                        currentIndex += cols
                    }
                }
                Keys.onLeftPressed: {
                    if (currentIndex > 0 && (currentIndex % cols) !== 0) {
                        currentIndex--
                    } else {
                        groupsView.focusGroupList()
                    }
                }
                Keys.onRightPressed: {
                    if (currentIndex < count - 1 && ((currentIndex + 1) % cols) !== 0) {
                        currentIndex++
                    } else if (addChannelsBtn && addChannelsBtn.visible) {
                        addChannelsBtn.forceActiveFocus()
                    }
                }
                Keys.onReturnPressed: {
                    if (currentIndex >= 0 && currentIndex < count && appViewModel) {
                        var item = memberListModel.get(currentIndex)
                        if (item && item.mtype === "live") {
                            appViewModel.setZapContext(appViewModel.groupList.membersAsList(), item.mchannelId, selectedGroupName || "Groups")
                        } else {
                            appViewModel.clearZapContext()
                        }
                        appViewModel.player.play(item.mstreamUrl, item.mname, item.mlogoUrl, item.mchannelId, "", 0, true, true)
                        appViewModel.currentView = "player"
                    }
                }
                Keys.onEnterPressed: Keys.onReturnPressed(event)
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                        Keys.onReturnPressed(event)
                        event.accepted = true
                    } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)
                               && selectedGroupMode !== "dynamic") {
                        if (currentIndex >= 0 && currentIndex < count && appViewModel) {
                            var removeItem = memberListModel.get(currentIndex)
                            if (removeItem) {
                                appViewModel.groupList.removeChannel(selectedGroupId, removeItem.mchannelId)
                                groupsView.reloadMembers()
                                groupsView.reloadGroups()
                                event.accepted = true
                            }
                        }
                    }
                }

                delegate: Item {
                    width: memberListView.cellWidth
                    height: memberListView.cellHeight
                    focus: memberListView.activeFocus && memberListView.currentIndex === index
                    activeFocusOnTab: true

                    function activate() {
                        if (!appViewModel) return
                        if (model.mtype === "live") {
                            appViewModel.setZapContext(appViewModel.groupList.membersAsList(), model.mchannelId, selectedGroupName || "Groups")
                        } else {
                            appViewModel.clearZapContext()
                        }
                        appViewModel.player.play(model.mstreamUrl, model.mname, model.mlogoUrl, model.mchannelId, "", 0, true, true)
                        appViewModel.currentView = "player"
                    }

                    Rectangle {
                        id: mGridCard
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: Theme.surfaceElevated
                        clip: true
                        property bool memHov: false

                        // Logo area at the top, inset from card edges so the
                        // rounded card surface frames the image instead of the
                        // image rendering edge-to-edge.
                        Image {
                            id: mGridLogo
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height - 50
                            source: model.mlogoUrl || ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        FallbackLogo {
                            visible: !mGridLogo.visible
                            logoOpacity: 0.15
                            anchors.verticalCenterOffset: -20
                        }

                        // Channel-type icon (top-left), same monochrome style as HomeView
                        Rectangle {
                            visible: model.mtype && model.mtype.length > 0
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 8
                            width: 26
                            height: 26
                            radius: 13
                            color: "#C0000000"
                            z: 200

                            Text {
                                anchors.centerIn: parent
                                text: model.mtype === "live" ? "\u25AD"
                                    : model.mtype === "series" ? "\u25EB"
                                    : (model.mtype === "vod" || model.mtype === "movie") ? "\u25B6"
                                    : ""
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "DejaVu Sans"
                                color: "#ffffff"
                            }
                        }

                        // Channel name (bottom strip, on card surface \u2014 not gradient overlay)
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.bottomMargin: 8
                            text: model.mname
                            font.pixelSize: Theme.fontSizeXs
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        // Delete button (top-right) for static groups only
                        Rectangle {
                            id: mDelBtn
                            visible: selectedGroupMode !== "dynamic"
                                && (mGridCard.memHov || (memberListView.activeFocus && memberListView.currentIndex === index))
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 26
                            height: 26
                            radius: 13
                            color: mDelHov ? Theme.error : "#C0000000"
                            z: 200
                            property bool mDelHov: false

                            Text {
                                anchors.centerIn: parent
                                text: "\u2715"
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "DejaVu Sans"
                                color: "#ffffff"
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.mDelHov = true
                                onExited: parent.mDelHov = false
                                onClicked: {
                                    if (appViewModel) {
                                        appViewModel.groupList.removeChannel(selectedGroupId, model.mchannelId)
                                        groupsView.reloadMembers()
                                        groupsView.reloadGroups()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: mGridCard.memHov = true
                            onExited: mGridCard.memHov = false
                            onClicked: {
                                // Don't trigger play if clicking the delete button area
                                var btnRight = parent.width
                                var btnLeft = btnRight - 42
                                var btnTop = 0
                                var btnBottom = 42
                                if (mDelBtn.visible
                                        && mouseX >= btnLeft && mouseX <= btnRight
                                        && mouseY >= btnTop && mouseY <= btnBottom) {
                                    return
                                }
                                activate()
                            }
                        }

                        // Focus/hover border. When the GridView has keyboard
                        // focus, only currentIndex drives the border (hover is
                        // ignored) \u2014 otherwise the cursor's last-hovered card
                        // would stay lit while D-pad moves to a new card.
                        Rectangle {
                            anchors.fill: parent
                            radius: mGridCard.radius
                            color: "transparent"
                            border.color: {
                                if (memberListView.activeFocus) {
                                    return memberListView.currentIndex === index
                                        ? Theme.accent : "transparent"
                                }
                                return mGridCard.memHov ? Theme.accent : "transparent"
                            }
                            border.width: {
                                if (memberListView.activeFocus) {
                                    return memberListView.currentIndex === index ? 2 : 0
                                }
                                return mGridCard.memHov ? 2 : 0
                            }
                            z: 100
                        }
                    }

                    Keys.onReturnPressed: activate()
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            activate()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: memberListModel.count === 0 && selectedGroupId > 0
                    text: "No items in this group yet.\nClick \"+ Add Items\" to search and add."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }

                Text {
                    anchors.centerIn: parent
                    visible: selectedGroupId === 0
                    text: "Select a group from the left panel\nor create a new one."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }
            }
        }
    }

    // ── Data models (plain ListModels, no dual-mode ViewModel) ──

    ListModel { id: groupListModel }
    ListModel { id: memberListModel }

    function reloadGroups() {
        if (!appViewModel) return
        var gl = appViewModel.groupList
        gl.activeGroupId = 0
        gl.refresh()
            groupListModel.clear()
            for (var i = 0; i < gl.count; i++) {
                groupListModel.append({
                    gid: gl.groupIdAt(i),
                    gname: gl.groupNameAt(i),
                    gmode: gl.groupTypeAt(i),
                    gscope: gl.groupFilterScopeAt(i),
                    gfield: gl.groupFilterFieldAt(i),
                    goperator: gl.groupFilterOperatorAt(i),
                    gfilterValue: gl.groupFilterValueAt(i),
                    gsummary: gl.groupSummaryAt(i),
                    gmemberCount: gl.memberCount(gl.groupIdAt(i))
                })
            }
        }

    function focusGroupById(groupId) {
        for (var i = 0; i < groupListModel.count; i++) {
            var item = groupListModel.get(i)
            if (item && item.gid === groupId) {
                groupListView.currentIndex = i
                groupListView.positionViewAtIndex(i, ListView.Contain)
                selectedGroupId = item.gid
                selectedGroupName = item.gname
                selectedGroupMode = item.gmode || "static"
                groupsView.reloadMembers()
                return true
            }
        }
        return false
    }

    function focusLastGroup() {
        if (groupListModel.count <= 0) return false
        var lastIndex = groupListModel.count - 1
        var item = groupListModel.get(lastIndex)
        if (!item) return false
        groupListView.currentIndex = lastIndex
        groupListView.positionViewAtIndex(lastIndex, ListView.Contain)
        selectedGroupId = item.gid
        selectedGroupName = item.gname
        selectedGroupMode = item.gmode || "static"
        groupsView.reloadMembers()
        return true
    }

    function reloadMembers() {
        memberListModel.clear()
        if (!appViewModel || selectedGroupId <= 0) return
        var gl = appViewModel.groupList
        gl.activeGroupId = selectedGroupId
        gl.refresh()
        for (var i = 0; i < gl.count; i++) {
            memberListModel.append({
                mchannelId: gl.channelIdAt(i),
                mname: gl.channelNameAt(i),
                mlogoUrl: gl.logoUrlAt(i),
                mstreamUrl: gl.streamUrlAt(i),
                mtype: gl.typeAt(i)
            })
        }
        gl.activeGroupId = 0
    }

    Component.onCompleted: groupsView.reloadGroups()

    // ── Create group dialog ──

    Rectangle {
        id: editGroupDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 101

        property int groupId: 0
        property string originalName: ""
        property string groupKind: "static"
        property string filterScope: "any"
        property string filterField: "name"
        property string filterOperator: "contains"

        function openForGroup(id, name, kind, scope, field, op, value) {
            groupId = id
            originalName = name || ""
            groupKind = kind || "static"
            filterScope = scope || "any"
            filterField = field || "name"
            filterOperator = op || "contains"
            editGroupInput.text = originalName
            editFilterInput.text = value || ""
            visible = true
            editGroupInput.forceActiveFocus()
            editGroupInput.selectAll()
        }
        function close() {
            visible = false
            Qt.callLater(function() {
                if (selectedGroupId > 0) {
                    groupsView.focusGroupById(selectedGroupId)
                } else if (groupListView.count > 0) {
                    groupListView.forceActiveFocus()
                } else if (addGroupBtn) {
                    addGroupBtn.forceActiveFocus()
                }
            })
        }

        MouseArea { anchors.fill: parent; onClicked: editGroupDialog.close() }

        Rectangle {
            anchors.centerIn: parent
            width: 420
            height: editGrpCol.implicitHeight + 48
            radius: 12
            color: Theme.surfaceElevated
            border.color: Theme.accent; border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: editGrpCol
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Edit Group"
                        font.pixelSize: 18; font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        id: editGroupCloseBtn
                        width: 24
                        height: 24
                        radius: 12
                        color: editCloseHov || editGroupCloseBtn.activeFocus ? Theme.error : "transparent"
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        focus: false
                        activeFocusOnTab: true
                        property bool editCloseHov: false

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            font.bold: true
                            color: (parent.editCloseHov || editGroupCloseBtn.activeFocus) ? "#ffffff" : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.editCloseHov = true
                            onExited: parent.editCloseHov = false
                            onClicked: editGroupDialog.close()
                        }

                        Keys.onReturnPressed: editGroupDialog.close()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                                    || event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                    || event.key === Qt.Key_Back) {
                                editGroupDialog.close()
                                event.accepted = true
                            }
                        }
                    }
                }

                Text {
                    text: "Original: " + editGroupDialog.originalName
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: Theme.surface
                    border.color: editGroupInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    TextInput {
                        id: editGroupInput
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        clip: true; selectByMouse: true
                        focus: false
                        activeFocusOnTab: true

                        Keys.onUpPressed: editGroupCloseBtn.forceActiveFocus()
                        Keys.onDownPressed: {
                            if (editGroupDialog.groupKind === "dynamic") {
                                if (editScopeRepeater.count > 0) {
                                    var firstScope = editScopeRepeater.itemAt(0)
                                    if (firstScope) firstScope.forceActiveFocus()
                                }
                            } else {
                                editGroupCancelBtn.forceActiveFocus()
                            }
                        }
                        Keys.onReturnPressed: {
                            if (editGroupDialog.groupKind === "dynamic") {
                                if (editScopeRepeater.count > 0) {
                                    var firstScope = editScopeRepeater.itemAt(0)
                                    if (firstScope) firstScope.forceActiveFocus()
                                }
                            } else {
                                confirmEditGroup()
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onEscapePressed: editGroupDialog.close()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Back) {
                                editGroupDialog.close()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Select) {
                                if (editGroupDialog.groupKind === "dynamic") {
                                    if (editScopeRepeater.count > 0) {
                                        var firstScope = editScopeRepeater.itemAt(0)
                                        if (firstScope) firstScope.forceActiveFocus()
                                    }
                                } else {
                                    confirmEditGroup()
                                }
                                event.accepted = true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Group name..."
                            font.pixelSize: 14
                            color: Theme.textMuted
                            visible: !editGroupInput.text && !editGroupInput.activeFocus
                        }
                    }
                }

                RowLayout {
                    visible: editGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        id: editScopeRepeater
                        model: [
                            { value: "any", label: "Any" },
                            { value: "live", label: "Live" },
                            { value: "vod", label: "Movies" },
                            { value: "series", label: "Series" }
                        ]

                        delegate: Rectangle {
                            id: editScopeBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: editGroupDialog.filterScope === modelData.value
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : scopeHover ? Theme.surfaceHover : Theme.surface
                            border.color: editGroupDialog.filterScope === modelData.value
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            property bool scopeHover: false

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: editGroupDialog.filterScope === modelData.value
                                color: editGroupDialog.filterScope === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.scopeHover = true
                                onExited: parent.scopeHover = false
                                onClicked: editGroupDialog.filterScope = modelData.value
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = editScopeRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < editScopeRepeater.count - 1) {
                                    var next = editScopeRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onUpPressed: editGroupInput.forceActiveFocus()
                            Keys.onDownPressed: {
                                if (editFieldRepeater.count > 0) {
                                    var firstField = editFieldRepeater.itemAt(0)
                                    if (firstField) firstField.forceActiveFocus()
                                }
                            }
                            Keys.onReturnPressed: editGroupDialog.filterScope = modelData.value
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    editGroupDialog.filterScope = modelData.value
                                    event.accepted = true
                                } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                           || event.key === Qt.Key_Back) {
                                    editGroupDialog.close()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    visible: editGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        id: editFieldRepeater
                        model: [
                            { value: "name", label: "Name" },
                            { value: "category", label: "Category" },
                            { value: "server", label: "Server" }
                        ]

                        delegate: Rectangle {
                            id: editFieldBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: editGroupDialog.filterField === modelData.value
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : fieldHover ? Theme.surfaceHover : Theme.surface
                            border.color: editGroupDialog.filterField === modelData.value
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            property bool fieldHover: false

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: editGroupDialog.filterField === modelData.value
                                color: editGroupDialog.filterField === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.fieldHover = true
                                onExited: parent.fieldHover = false
                                onClicked: editGroupDialog.filterField = modelData.value
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = editFieldRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < editFieldRepeater.count - 1) {
                                    var next = editFieldRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onUpPressed: {
                                if (editScopeRepeater.count > 0) {
                                    var s = editScopeRepeater.itemAt(0)
                                    if (s) s.forceActiveFocus()
                                }
                            }
                            Keys.onDownPressed: {
                                if (editOpRepeater.count > 0) {
                                    var firstOp = editOpRepeater.itemAt(0)
                                    if (firstOp) firstOp.forceActiveFocus()
                                }
                            }
                            Keys.onReturnPressed: editGroupDialog.filterField = modelData.value
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    editGroupDialog.filterField = modelData.value
                                    event.accepted = true
                                } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                           || event.key === Qt.Key_Back) {
                                    editGroupDialog.close()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    visible: editGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        id: editOpRepeater
                        model: [
                            { value: "contains", label: "Contains" },
                            { value: "not_contains", label: "Not Contains" },
                            { value: "starts_with", label: "Starts With" },
                            { value: "equals", label: "Equals" }
                        ]

                        delegate: Rectangle {
                            id: editOpBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: editGroupDialog.filterOperator === modelData.value
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : opHover ? Theme.surfaceHover : Theme.surface
                            border.color: editGroupDialog.filterOperator === modelData.value
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            property bool opHover: false

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: editGroupDialog.filterOperator === modelData.value
                                color: editGroupDialog.filterOperator === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.opHover = true
                                onExited: parent.opHover = false
                                onClicked: editGroupDialog.filterOperator = modelData.value
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = editOpRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < editOpRepeater.count - 1) {
                                    var next = editOpRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onUpPressed: {
                                if (editFieldRepeater.count > 0) {
                                    var f = editFieldRepeater.itemAt(0)
                                    if (f) f.forceActiveFocus()
                                }
                            }
                            Keys.onDownPressed: editFilterInput.forceActiveFocus()
                            Keys.onReturnPressed: editGroupDialog.filterOperator = modelData.value
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    editGroupDialog.filterOperator = modelData.value
                                    event.accepted = true
                                } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                           || event.key === Qt.Key_Back) {
                                    editGroupDialog.close()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: editGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: Theme.surface
                    border.color: editFilterInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    TextInput {
                        id: editFilterInput
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        clip: true; selectByMouse: true
                        focus: false
                        activeFocusOnTab: true

                        Keys.onUpPressed: {
                            if (editOpRepeater.count > 0) {
                                var firstOp = editOpRepeater.itemAt(0)
                                if (firstOp) firstOp.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: editGroupCancelBtn.forceActiveFocus()
                        Keys.onReturnPressed: confirmEditGroup()
                        Keys.onEnterPressed: confirmEditGroup()
                        Keys.onEscapePressed: editGroupDialog.close()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Back) {
                                editGroupDialog.close()
                                event.accepted = true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Filter text..."
                            font.pixelSize: 14
                            color: Theme.textMuted
                            visible: !editFilterInput.text && !editFilterInput.activeFocus
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: editGroupCancelBtn
                        width: 80; height: 36; radius: 6
                        color: editCancelHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder; border.width: 1
                        focus: false
                        activeFocusOnTab: true
                        property bool editCancelHov: false
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 13; color: Theme.textSecondary }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.editCancelHov = true
                            onExited: parent.editCancelHov = false
                            onClicked: editGroupDialog.close()
                        }
                        Keys.onRightPressed: editGroupSaveBtn.forceActiveFocus()
                        Keys.onUpPressed: {
                            if (editGroupDialog.groupKind === "dynamic") {
                                editFilterInput.forceActiveFocus()
                            } else {
                                editGroupInput.forceActiveFocus()
                            }
                        }
                        Keys.onReturnPressed: editGroupDialog.close()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                                    || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                editGroupDialog.close()
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        id: editGroupSaveBtn
                        width: 80; height: 36; radius: 6
                        color: editSaveHov ? Theme.accent : Theme.accentHover
                        focus: false
                        activeFocusOnTab: true
                        property bool editSaveHov: false
                        Text { anchors.centerIn: parent; text: "Save"; font.pixelSize: 13; font.bold: true; color: Theme.textOnAccent }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.editSaveHov = true
                            onExited: parent.editSaveHov = false
                            onClicked: confirmEditGroup()
                        }
                        Keys.onLeftPressed: editGroupCancelBtn.forceActiveFocus()
                        Keys.onUpPressed: {
                            if (editGroupDialog.groupKind === "dynamic") {
                                editFilterInput.forceActiveFocus()
                            } else {
                                editGroupInput.forceActiveFocus()
                            }
                        }
                        Keys.onReturnPressed: confirmEditGroup()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                confirmEditGroup()
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                editGroupDialog.close()
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }

    function confirmEditGroup() {
        if (!appViewModel || !editGroupInput.text.trim() || editGroupDialog.groupId <= 0) return
        var filterValue = editGroupDialog.groupKind === "dynamic" ? editFilterInput.text.trim() : ""
        if (editGroupDialog.groupKind === "dynamic" && !filterValue) return
        appViewModel.groupList.updateGroup(editGroupDialog.groupId,
                                           editGroupInput.text.trim(),
                                           editGroupDialog.groupKind,
                                           editGroupDialog.filterScope,
                                           editGroupDialog.filterField,
                                           editGroupDialog.filterOperator,
                                           filterValue)
        selectedGroupName = editGroupInput.text.trim()
        editGroupDialog.close()
        groupsView.reloadGroups()
        Qt.callLater(function() {
            groupsView.focusGroupById(editGroupDialog.groupId)
        })
    }

    Rectangle {
        id: createGroupDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 100

        property string groupKind: "static"
        property string filterScope: "any"
        property string filterField: "name"
        property string filterOperator: "contains"

        function open() {
            visible = true
            groupKind = "static"
            filterScope = "any"
            filterField = "name"
            filterOperator = "contains"
            newGroupInput.text = ""
            newFilterInput.text = ""
            newGroupInput.forceActiveFocus()
        }
        function close() {
            visible = false
            Qt.callLater(function() {
                if (addGroupBtn) addGroupBtn.forceActiveFocus()
                else if (groupListView) groupsView.focusGroupList()
            })
        }

        MouseArea { anchors.fill: parent; onClicked: createGroupDialog.close() }

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: createGrpCol.implicitHeight + 48
            radius: 12
            color: Theme.surfaceElevated
            border.color: Theme.accent; border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: createGrpCol
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Create Group"
                        font.pixelSize: 18; font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        id: createGroupCloseBtn
                        width: 24
                        height: 24
                        radius: 12
                        color: closeHov || createGroupCloseBtn.activeFocus ? Theme.error : "transparent"
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        focus: false
                        activeFocusOnTab: true
                        property bool closeHov: false

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            font.bold: true
                            color: (parent.closeHov || createGroupCloseBtn.activeFocus) ? "#ffffff" : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.closeHov = true
                            onExited: parent.closeHov = false
                            onClicked: createGroupDialog.close()
                        }

                        Keys.onReturnPressed: createGroupDialog.close()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                                    || event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                    || event.key === Qt.Key_Back) {
                                createGroupDialog.close()
                                event.accepted = true
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        id: groupKindRepeater
                        model: [
                            { value: "static", label: "Static" },
                            { value: "dynamic", label: "Dynamic" }
                        ]

                        delegate: Rectangle {
                            id: kindBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: 6
                            color: createGroupDialog.groupKind === modelData.value
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : kindHover ? Theme.surfaceHover : Theme.surface
                            border.color: createGroupDialog.groupKind === modelData.value
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            property bool kindHover: false

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: createGroupDialog.groupKind === modelData.value
                                color: createGroupDialog.groupKind === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.kindHover = true
                                onExited: parent.kindHover = false
                                onClicked: {
                                    createGroupDialog.groupKind = modelData.value
                                    if (modelData.value === "static") {
                                        newGroupInput.forceActiveFocus()
                                    } else {
                                        newFilterInput.forceActiveFocus()
                                    }
                                }
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = groupKindRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < groupKindRepeater.count - 1) {
                                    var next = groupKindRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onDownPressed: newGroupInput.forceActiveFocus()
                            Keys.onReturnPressed: {
                                createGroupDialog.groupKind = modelData.value
                                if (modelData.value === "static") {
                                    newGroupInput.forceActiveFocus()
                                } else {
                                    newFilterInput.forceActiveFocus()
                                }
                            }
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    Keys.onReturnPressed(event)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                           || event.key === Qt.Key_Back) {
                                    createGroupDialog.close()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: Theme.surface
                    border.color: newGroupInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    TextInput {
                        id: newGroupInput
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        clip: true; selectByMouse: true
                        focus: false
                        activeFocusOnTab: true

                        Keys.onUpPressed: {
                            if (groupKindRepeater.count > 0) {
                                var firstKind = groupKindRepeater.itemAt(0)
                                if (firstKind) firstKind.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: {
                            if (createGroupDialog.groupKind === "dynamic") {
                                if (scopeRepeater.count > 0) {
                                    var firstScope = scopeRepeater.itemAt(0)
                                    if (firstScope) firstScope.forceActiveFocus()
                                }
                            } else {
                                cancelGroupBtn.forceActiveFocus()
                            }
                        }
                        Keys.onReturnPressed: {
                            if (createGroupDialog.groupKind === "dynamic") {
                                if (scopeRepeater.count > 0) {
                                    var firstScope = scopeRepeater.itemAt(0)
                                    if (firstScope) firstScope.forceActiveFocus()
                                }
                            } else {
                                confirmCreateGroup()
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onEscapePressed: createGroupDialog.close()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Back) {
                                createGroupDialog.close()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Select) {
                                if (createGroupDialog.groupKind === "dynamic") {
                                    if (scopeRepeater.count > 0) {
                                        var firstScope = scopeRepeater.itemAt(0)
                                        if (firstScope) firstScope.forceActiveFocus()
                                    }
                                } else {
                                    confirmCreateGroup()
                                }
                                event.accepted = true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Group name..."
                            font.pixelSize: 14
                            color: Theme.textMuted
                            visible: !newGroupInput.text && !newGroupInput.activeFocus
                        }
                    }
                }

                RowLayout {
                    visible: createGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        id: scopeRepeater
                        model: [
                            { value: "any", label: "Any" },
                            { value: "live", label: "Live" },
                            { value: "vod", label: "Movies" },
                            { value: "series", label: "Series" }
                        ]

                        delegate: Rectangle {
                            id: scopeBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: createGroupDialog.filterScope === modelData.value
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : scopeHover ? Theme.surfaceHover : Theme.surface
                            border.color: createGroupDialog.filterScope === modelData.value
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            property bool scopeHover: false

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: createGroupDialog.filterScope === modelData.value
                                color: createGroupDialog.filterScope === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.scopeHover = true
                                onExited: parent.scopeHover = false
                                onClicked: createGroupDialog.filterScope = modelData.value
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = scopeRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < scopeRepeater.count - 1) {
                                    var next = scopeRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onUpPressed: newGroupInput.forceActiveFocus()
                            Keys.onDownPressed: {
                                if (fieldRepeater.count > 0) {
                                    var firstField = fieldRepeater.itemAt(0)
                                    if (firstField) firstField.forceActiveFocus()
                                }
                            }
                            Keys.onReturnPressed: createGroupDialog.filterScope = modelData.value
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    createGroupDialog.filterScope = modelData.value
                                    event.accepted = true
                                } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                           || event.key === Qt.Key_Back) {
                                    createGroupDialog.close()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    visible: createGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        id: fieldRepeater
                        model: [
                            { value: "name", label: "Name" },
                            { value: "category", label: "Category" },
                            { value: "server", label: "Server" }
                        ]

                        delegate: Rectangle {
                            id: fieldBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: createGroupDialog.filterField === modelData.value
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : fieldHover ? Theme.surfaceHover : Theme.surface
                            border.color: createGroupDialog.filterField === modelData.value
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            property bool fieldHover: false

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: createGroupDialog.filterField === modelData.value
                                color: createGroupDialog.filterField === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.fieldHover = true
                                onExited: parent.fieldHover = false
                                onClicked: createGroupDialog.filterField = modelData.value
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = fieldRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < fieldRepeater.count - 1) {
                                    var next = fieldRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onUpPressed: {
                                if (scopeRepeater.count > 0) {
                                    var s = scopeRepeater.itemAt(0)
                                    if (s) s.forceActiveFocus()
                                }
                            }
                            Keys.onDownPressed: {
                                if (operatorRepeater.count > 0) {
                                    var firstOp = operatorRepeater.itemAt(0)
                                    if (firstOp) firstOp.forceActiveFocus()
                                }
                            }
                            Keys.onReturnPressed: createGroupDialog.filterField = modelData.value
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    createGroupDialog.filterField = modelData.value
                                    event.accepted = true
                                } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                           || event.key === Qt.Key_Back) {
                                    createGroupDialog.close()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    visible: createGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        id: operatorRepeater
                        model: [
                            { value: "contains", label: "Contains" },
                            { value: "not_contains", label: "Not Contains" },
                            { value: "starts_with", label: "Starts With" },
                            { value: "equals", label: "Equals" }
                        ]

                        delegate: Rectangle {
                            id: opBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 6
                            color: createGroupDialog.filterOperator === modelData.value
                                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                : opHover ? Theme.surfaceHover : Theme.surface
                            border.color: createGroupDialog.filterOperator === modelData.value
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            property bool opHover: false

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: createGroupDialog.filterOperator === modelData.value
                                color: createGroupDialog.filterOperator === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.opHover = true
                                onExited: parent.opHover = false
                                onClicked: createGroupDialog.filterOperator = modelData.value
                            }

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = operatorRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < operatorRepeater.count - 1) {
                                    var next = operatorRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onUpPressed: {
                                if (fieldRepeater.count > 0) {
                                    var f = fieldRepeater.itemAt(0)
                                    if (f) f.forceActiveFocus()
                                }
                            }
                            Keys.onDownPressed: newFilterInput.forceActiveFocus()
                            Keys.onReturnPressed: createGroupDialog.filterOperator = modelData.value
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    createGroupDialog.filterOperator = modelData.value
                                    event.accepted = true
                                } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                           || event.key === Qt.Key_Back) {
                                    createGroupDialog.close()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: createGroupDialog.groupKind === "dynamic"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: Theme.surface
                    border.color: newFilterInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    TextInput {
                        id: newFilterInput
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        clip: true; selectByMouse: true
                        focus: false
                        activeFocusOnTab: true

                        Keys.onUpPressed: {
                            if (operatorRepeater.count > 0) {
                                var firstOp = operatorRepeater.itemAt(0)
                                if (firstOp) firstOp.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: cancelGroupBtn.forceActiveFocus()
                        Keys.onReturnPressed: confirmCreateGroup()
                        Keys.onEnterPressed: confirmCreateGroup()
                        Keys.onEscapePressed: createGroupDialog.close()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Back) {
                                createGroupDialog.close()
                                event.accepted = true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Filter text..."
                            font.pixelSize: 14
                            color: Theme.textMuted
                            visible: !newFilterInput.text && !newFilterInput.activeFocus
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: cancelGroupBtn
                        width: 80; height: 36; radius: 6
                        color: cancelHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder; border.width: 1
                        focus: false
                        activeFocusOnTab: true
                        property bool cancelHov: false
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 13; color: Theme.textSecondary }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.cancelHov = true; onExited: parent.cancelHov = false; onClicked: createGroupDialog.close() }
                        Keys.onRightPressed: createGroupBtn.forceActiveFocus()
                        Keys.onUpPressed: {
                            if (createGroupDialog.groupKind === "dynamic") {
                                newFilterInput.forceActiveFocus()
                            } else {
                                newGroupInput.forceActiveFocus()
                            }
                        }
                        Keys.onReturnPressed: createGroupDialog.close()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                createGroupDialog.close()
                                event.accepted = true
                            }
                        }
                    }
                    Rectangle {
                        id: createGroupBtn
                        width: 80; height: 36; radius: 6
                        color: createHov ? Theme.accent : Theme.accentHover
                        focus: false
                        activeFocusOnTab: true
                        property bool createHov: false
                        Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: 13; font.bold: true; color: Theme.textOnAccent }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.createHov = true; onExited: parent.createHov = false; onClicked: confirmCreateGroup() }
                        Keys.onLeftPressed: cancelGroupBtn.forceActiveFocus()
                        Keys.onReturnPressed: confirmCreateGroup()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                confirmCreateGroup()
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                createGroupDialog.close()
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }

    function confirmCreateGroup() {
        if (!appViewModel || !newGroupInput.text.trim()) return
        if (createGroupDialog.groupKind === "dynamic" && !newFilterInput.text.trim()) return
        var createdId = appViewModel.groupList.createGroup(newGroupInput.text.trim(), createGroupDialog.groupKind,
                                                           createGroupDialog.filterScope, createGroupDialog.filterField,
                                                           createGroupDialog.filterOperator, newFilterInput.text.trim())
        createGroupDialog.close()
        groupsView.reloadGroups()
        Qt.callLater(function() {
            if (createdId > 0 && groupsView.focusGroupById(createdId)) return
            if (!groupsView.focusLastGroup()) {
                groupsView.reloadGroups()
                groupsView.focusLastGroup()
            }
        })
    }

    // ── Channel search dialog ──

    Rectangle {
        id: channelSearchDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 100

        function open() {
            visible = true
            chSearchInput.text = ""
            chSearchResults.clear()
            chSearchInput.forceActiveFocus()
        }
        function close() {
            visible = false
            Qt.callLater(function() {
                if (addChannelsBtn && addChannelsBtn.visible) addChannelsBtn.forceActiveFocus()
                else groupsView.focusGroupList()
            })
        }

        MouseArea { anchors.fill: parent; onClicked: channelSearchDialog.close() }

        Rectangle {
            anchors.centerIn: parent
            width: 520; height: 520
            radius: 12
            color: Theme.surfaceElevated
            border.color: Theme.accent; border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Text {
                    text: "Add Items to \"" + selectedGroupName + "\""
                    font.pixelSize: 18; font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 6
                    color: Theme.surface
                    border.color: chSearchInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    TextInput {
                        id: chSearchInput
                        anchors.fill: parent
                        anchors.margins: 8
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        clip: true; selectByMouse: true

                        onActiveFocusChanged: {
                            if (activeFocus) Qt.inputMethod.show()
                            else Qt.inputMethod.hide()
                        }

                        Keys.onEscapePressed: channelSearchDialog.close()
                        Keys.onDownPressed: {
                            if (chSearchList.count > 0) {
                                if (chSearchList.currentIndex < 0) chSearchList.currentIndex = 0
                                chSearchList.forceActiveFocus()
                            }
                        }
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Back) {
                                channelSearchDialog.close()
                                event.accepted = true
                            }
                        }
                        onTextChanged: chSearchTimer.restart()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uD83D\uDD0D  Search channels..."
                            font.pixelSize: 14
                            color: Theme.textMuted
                            visible: !chSearchInput.text
                        }
                    }
                }

                ListView {
                    id: chSearchList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: chSearchResults
                    spacing: 4
                    keyNavigationEnabled: true
                    onCountChanged: groupsView.clampListIndex(chSearchList)

                    ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                    Keys.onUpPressed: {
                        if (currentIndex > 0) currentIndex--
                        else chSearchInput.forceActiveFocus()
                    }
                    Keys.onDownPressed: { if (currentIndex < count - 1) currentIndex++ }
                    Keys.onRightPressed: {
                        if (currentIndex >= 0 && currentIndex < count) {
                            var currentItem = chSearchList.currentItem
                            if (currentItem && currentItem.srBtn) {
                                currentItem.srBtn.forceActiveFocus()
                            }
                        }
                    }
                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentIndex < count && appViewModel) {
                            var item = chSearchResults.get(currentIndex)
                            if (!item) return
                            if (item.inGrp)
                                appViewModel.groupList.removeChannel(selectedGroupId, item.cid)
                            else
                                appViewModel.groupList.addChannel(selectedGroupId, item.cid)
                            chSearchResults.setProperty(currentIndex, "inGrp", !item.inGrp)
                        }
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            Keys.onReturnPressed(event)
                            event.accepted = true
                        } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                            channelSearchDialog.close()
                            event.accepted = true
                        }
                    }

                    delegate: Rectangle {
                        width: chSearchList.width
                        height: 52
                        radius: 6
                        color: srHov ? Theme.surfaceHover : Theme.surface
                        focus: false
                        activeFocusOnTab: true
                        property bool srHov: false
                        property bool inGrp: appViewModel ? appViewModel.groupList.isInGroup(selectedGroupId, model.cid) : false

                        Rectangle {
                            id: srLogo
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36; height: 36; radius: 4
                            color: Theme.surfaceElevated; clip: true

                            Image {
                                anchors.fill: parent; anchors.margins: 3
                                source: model.clogoUrl || ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            Text { anchors.centerIn: parent; text: "\uD83D\uDCFA"; font.pixelSize: 12; visible: !model.clogoUrl }
                        }

                        Text {
                            anchors.left: srLogo.right
                            anchors.leftMargin: 8
                            anchors.right: srBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.cname
                            font.pixelSize: 13
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: srBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 70; height: 28; radius: 6
                            color: inGrp
                                ? (srBtnHov ? Theme.error : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.13))
                                : (srBtnHov ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13))
                            property bool srBtnHov: false
                            focus: false
                            activeFocusOnTab: true

                            Text {
                                anchors.centerIn: parent
                                text: inGrp ? "Remove" : "Add"
                                font.pixelSize: 12; font.bold: true
                                color: inGrp
                                    ? (parent.srBtnHov ? "#fff" : Theme.error)
                                    : (parent.srBtnHov ? "#fff" : Theme.accent)
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: parent.srBtnHov = true
                                onExited: parent.srBtnHov = false
                                onClicked: {
                                    if (!appViewModel) return
                                    if (inGrp)
                                        appViewModel.groupList.removeChannel(selectedGroupId, model.cid)
                                    else
                                        appViewModel.groupList.addChannel(selectedGroupId, model.cid)
                                    inGrp = !inGrp
                                }
                            }

                            Keys.onReturnPressed: {
                                if (!appViewModel) return
                                if (inGrp)
                                    appViewModel.groupList.removeChannel(selectedGroupId, model.cid)
                                else
                                    appViewModel.groupList.addChannel(selectedGroupId, model.cid)
                                inGrp = !inGrp
                            }
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onLeftPressed: {
                                if (chSearchList) chSearchList.forceActiveFocus()
                            }
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    Keys.onReturnPressed(event)
                                    event.accepted = true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: parent.srHov = true
                            onExited: parent.srHov = false
                            z: -1
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: chSearchList.count === 0
                        text: chSearchInput.text.length >= 2 ? "No channels found" : "Type at least 2 characters to search"
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }
                }

                Rectangle {
                    id: doneBtn
                    Layout.alignment: Qt.AlignRight
                    width: 80; height: 36; radius: 6
                    color: doneHov ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.surfaceBorder; border.width: 1
                    focus: false
                    activeFocusOnTab: true
                    property bool doneHov: false
                    Text { anchors.centerIn: parent; text: "Done"; font.pixelSize: 13; font.bold: true; color: Theme.textPrimary }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: parent.doneHov = true; onExited: parent.doneHov = false
                        onClicked: {
                            channelSearchDialog.close()
                            groupsView.reloadMembers()
                            groupsView.reloadGroups()
                        }
                    }
                    Keys.onUpPressed: {
                        if (chSearchList.count > 0) {
                            if (chSearchList.currentIndex < 0) chSearchList.currentIndex = 0
                            chSearchList.forceActiveFocus()
                        } else {
                            chSearchInput.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: {
                        channelSearchDialog.close()
                        groupsView.reloadMembers()
                        groupsView.reloadGroups()
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                                || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                            channelSearchDialog.close()
                            groupsView.reloadMembers()
                            groupsView.reloadGroups()
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }

    ListModel { id: chSearchResults }

    Timer {
        id: chSearchTimer
        interval: 300; repeat: false
        onTriggered: {
            chSearchResults.clear()
            if (!appViewModel || chSearchInput.text.trim().length < 2) return
            var results = appViewModel.groupList.searchChannels(chSearchInput.text.trim(), 50)
            for (var i = 0; i < results.length; i++) {
                var r = results[i]
                chSearchResults.append({
                    cid: r.channelId,
                    cname: r.name,
                    clogoUrl: r.logoUrl || "",
                    cstreamUrl: r.streamUrl || "",
                    inGrp: appViewModel ? appViewModel.groupList.isInGroup(selectedGroupId, r.channelId) : false
                })
            }
        }
    }
}
