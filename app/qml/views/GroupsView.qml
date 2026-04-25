import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: groupsView

    property int selectedGroupId: 0
    property string selectedGroupName: ""

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
                            color: Theme.textMuted
                            opacity: 0.5
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: addBtnHov ? Theme.accent : Theme.accentHover
                            property bool addBtnHov: false

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 16
                                font.bold: true
                                color: Theme.textOnAccent
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

                    delegate: Item {
                        width: groupListView.width
                        height: 52

                        Rectangle {
                            anchors.fill: parent
                            color: selectedGroupId === model.gid
                                ? Theme.accent + "25" : grpHov ? Theme.surfaceHover : "transparent"
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
                                anchors.right: grpDelBtn.left
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
                                    text: model.gmemberCount + (model.gmemberCount === 1 ? " channel" : " channels")
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textMuted
                                }
                            }

                            Rectangle {
                                id: grpDelBtn
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingSm
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22; radius: 11
                                color: delGrpHov ? Theme.error + "30" : "transparent"
                                property bool delGrpHov: false

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2715"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: parent.delGrpHov ? Theme.error : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.delGrpHov = true
                                    onExited: parent.delGrpHov = false
                                    onClicked: {
                                        if (appViewModel)
                                            appViewModel.groupList.deleteGroup(model.gid)
                                        if (selectedGroupId === model.gid) {
                                            selectedGroupId = 0
                                            selectedGroupName = ""
                                            memberListModel.clear()
                                        }
                                        reloadGroups()
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
                                    reloadMembers()
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
                            ? selectedGroupName + " (" + memberListModel.count + ")"
                            : "Select a group"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: selectedGroupId > 0
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: selectedGroupId > 0
                        Layout.preferredWidth: addChLabel.implicitWidth + 20
                        Layout.preferredHeight: 32
                        radius: Theme.borderRadius
                        color: addChHov ? Theme.accent : Theme.accentHover
                        property bool addChHov: false

                        Text {
                            id: addChLabel
                            anchors.centerIn: parent
                            text: "+ Add Channels"
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
                    }
                }
            }

            ListView {
                id: memberListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: memberListModel
                spacing: 6

                ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: memberListView.width - 24
                    height: 64
                    x: 12
                    radius: 8
                    color: memHov ? Theme.surfaceHover : Theme.surfaceElevated
                    border.color: memHov ? Theme.accent + "40" : "transparent"
                    border.width: 1
                    property bool memHov: false

                    Rectangle {
                        id: mLogo
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 44; radius: 6
                        color: Theme.surface
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: model.mlogoUrl || ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "\uD83D\uDCFA"
                            font.pixelSize: 16
                            visible: !model.mlogoUrl
                        }
                    }

                    Column {
                        anchors.left: mLogo.right
                        anchors.leftMargin: 12
                        anchors.right: mDelBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: model.mname
                            font.pixelSize: 14
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: model.mtype
                            font.pixelSize: 11
                            color: Theme.textMuted
                        }
                    }

                    Rectangle {
                        id: mDelBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 16
                        color: mDelHov ? Theme.error + "30" : "transparent"
                        property bool mDelHov: false

                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            font.pixelSize: 14; font.bold: true
                            color: parent.mDelHov ? Theme.error : Theme.textMuted
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
                                    reloadMembers()
                                    reloadGroups()
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.left: mLogo.left
                        anchors.right: mDelBtn.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.memHov = true
                        onExited: parent.memHov = false
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.player.play(model.mstreamUrl, model.mname, model.mlogoUrl, model.mchannelId)
                                appViewModel.currentView = "player"
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: memberListModel.count === 0 && selectedGroupId > 0
                    text: "No channels in this group yet.\nClick \"+ Add Channels\" to search and add."
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
                gmemberCount: gl.memberCount(gl.groupIdAt(i))
            })
        }
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
                mtype: "live"
            })
        }
        gl.activeGroupId = 0
    }

    Component.onCompleted: reloadGroups()

    // ── Create group dialog ──

    Rectangle {
        id: createGroupDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 100

        function open() { visible = true; newGroupInput.text = ""; newGroupInput.forceActiveFocus() }
        function close() { visible = false }

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

                Text {
                    text: "Create Group"
                    font.pixelSize: 18; font.bold: true
                    color: Theme.textPrimary
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

                        Keys.onReturnPressed: confirmCreateGroup()
                        Keys.onEnterPressed: confirmCreateGroup()
                        Keys.onEscapePressed: createGroupDialog.close()

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
                    Layout.fillWidth: true
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: cancelHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder; border.width: 1
                        property bool cancelHov: false
                        Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 13; color: Theme.textSecondary }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.cancelHov = true; onExited: parent.cancelHov = false; onClicked: createGroupDialog.close() }
                    }
                    Rectangle {
                        width: 80; height: 36; radius: 6
                        color: createHov ? Theme.accent : Theme.accentHover
                        property bool createHov: false
                        Text { anchors.centerIn: parent; text: "Create"; font.pixelSize: 13; font.bold: true; color: Theme.textOnAccent }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.createHov = true; onExited: parent.createHov = false; onClicked: confirmCreateGroup() }
                    }
                }
            }
        }
    }

    function confirmCreateGroup() {
        if (!appViewModel || !newGroupInput.text.trim()) return
        appViewModel.groupList.createGroup(newGroupInput.text.trim())
        createGroupDialog.close()
        reloadGroups()
    }

    // ── Channel search dialog ──

    Rectangle {
        id: channelSearchDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 100

        function open() {
            visible = true; chSearchInput.text = ""
            chSearchResults.clear(); chSearchInput.forceActiveFocus()
        }
        function close() { visible = false }

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
                    text: "Add Channels to \"" + selectedGroupName + "\""
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
                        Keys.onEscapePressed: channelSearchDialog.close()
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

                    ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: chSearchList.width
                        height: 52
                        radius: 6
                        color: srHov ? Theme.surfaceHover : Theme.surface
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
                                ? (srBtnHov ? Theme.error : Theme.error + "20")
                                : (srBtnHov ? Theme.accent : Theme.accent + "20")
                            property bool srBtnHov: false

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
                    Layout.alignment: Qt.AlignRight
                    width: 80; height: 36; radius: 6
                    color: doneHov ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.surfaceBorder; border.width: 1
                    property bool doneHov: false
                    Text { anchors.centerIn: parent; text: "Done"; font.pixelSize: 13; font.bold: true; color: Theme.textPrimary }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: parent.doneHov = true; onExited: parent.doneHov = false
                        onClicked: {
                            channelSearchDialog.close()
                            reloadMembers()
                            reloadGroups()
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
                    cstreamUrl: r.streamUrl || ""
                })
            }
        }
    }
}
