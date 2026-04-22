import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: channelsView

    property var activeServerId: 0

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: categorySidebar
            Layout.preferredWidth: 240
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

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Layout.topMargin: Theme.spacingSm

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingMd
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: "SERVERS"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: Theme.textMuted
                        opacity: 0.7
                    }
                }

                ListView {
                    id: serverPicker
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 150)
                    clip: true
                    model: appViewModel ? appViewModel.serverList : null

                    delegate: Rectangle {
                        width: serverPicker.width
                        height: 36
                        color: activeServerId === model.serverId
                            ? Theme.accent + "25" : srvHovered ? Theme.surfaceHover : "transparent"

                        property bool srvHovered: false

                        Rectangle {
                            visible: activeServerId === model.serverId
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 20; radius: 2
                            color: Theme.accent
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingMd
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.name
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: activeServerId === model.serverId
                            color: activeServerId === model.serverId
                                ? Theme.textPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                            width: parent.width - Theme.spacingLg
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.srvHovered = true
                            onExited: parent.srvHovered = false
                            onClicked: selectServer(model.serverId)
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

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Layout.topMargin: Theme.spacingSm

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.spacingMd
                        anchors.rightMargin: Theme.spacingMd
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8

                        Text {
                            text: "CATEGORIES"
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.5
                            color: Theme.textMuted
                            opacity: 0.7
                            Layout.fillWidth: true
                        }

                        Text {
                            text: appViewModel ? appViewModel.categoryList.count : 0
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                            opacity: 0.5
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    Layout.leftMargin: Theme.spacingSm
                    Layout.rightMargin: Theme.spacingSm
                    Layout.topMargin: Theme.spacingSm
                    Layout.bottomMargin: Theme.spacingMd
                    radius: 14
                    color: Theme.surfaceElevated
                    border.color: catFilterInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingSm
                        anchors.rightMargin: Theme.spacingSm
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🔍"
                            font.pixelSize: 10
                            opacity: 0.5
                        }

                        TextInput {
                            id: catFilterInput
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 20
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textPrimary
                            clip: true
                            selectByMouse: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Filter categories..."
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                                visible: !catFilterInput.text && !catFilterInput.activeFocus
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: selectedCategoryId === 0
                        ? Theme.accentGlow : allCatHovered ? Theme.surfaceHover : "transparent"

                    property bool allCatHovered: false

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingMd
                        anchors.verticalCenter: parent.verticalCenter
                        text: "All Channels"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: selectedCategoryId === 0
                        color: selectedCategoryId === 0
                            ? Theme.textPrimary : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.allCatHovered = true
                        onExited: parent.allCatHovered = false
                        onClicked: selectCategory(0)
                    }
                }

                ListView {
                    id: categoryList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    keyNavigationEnabled: true
                    highlight: Rectangle { color: Theme.accent + "20"; radius: Theme.borderRadiusSmall }
                    highlightFollowsCurrentItem: true
                    model: appViewModel ? appViewModel.categoryList : null

                    Keys.onReturnPressed: if (currentIndex >= 0) selectCategory(appViewModel.categoryList.categoryIdAt(currentIndex))
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onRightPressed: channelGrid.forceActiveFocus()

                    delegate: Rectangle {
                        width: categoryList.width
                        height: catVisible ? 36 : 0
                        visible: catVisible
                        clip: true

                        property bool catVisible: {
                            if (!catFilterInput.text) return true
                            return model.name.toLowerCase().indexOf(catFilterInput.text.toLowerCase()) >= 0
                        }

                        color: selectedCategoryId === model.categoryId
                            ? Theme.accentGlow : catHovered ? Theme.surfaceHover : "transparent"

                        property bool catHovered: false

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingLg
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.name
                            font.pixelSize: Theme.fontSizeSm
                            color: selectedCategoryId === model.categoryId
                                ? Theme.textPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                            width: parent.width - Theme.spacingXl
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.catHovered = true
                            onExited: parent.catHovered = false
                            onClicked: selectCategory(model.categoryId)
                        }
                    }
                }
            }
        }

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
                    spacing: Theme.spacingSm

                    Text {
                        text: {
                            var total = appViewModel ? appViewModel.channelList.totalCount : 0
                            return total + " TV channels"
                        }
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: newFilterLabel.implicitWidth + 20
                        Layout.preferredHeight: 28
                        radius: 14
                        color: {
                            var active = appViewModel && appViewModel.channelList.recentlyAddedFilter
                            return active ? Theme.accent : newFilterHov ? Theme.surfaceHover : Theme.surface
                        }
                        border.width: 1
                        border.color: {
                            var active = appViewModel && appViewModel.channelList.recentlyAddedFilter
                            return active ? Theme.accent : Theme.surfaceBorder
                        }
                        property bool newFilterHov: false

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "\u2728"
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: newFilterLabel
                                text: "New"
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: appViewModel && appViewModel.channelList.recentlyAddedFilter
                                color: appViewModel && appViewModel.channelList.recentlyAddedFilter
                                    ? "#ffffff" : Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.newFilterHov = true
                            onExited: parent.newFilterHov = false
                            onClicked: {
                                if (appViewModel) {
                                    appViewModel.channelList.recentlyAddedFilter =
                                        !appViewModel.channelList.recentlyAddedFilter
                                }
                            }
                        }
                    }
                }
            }

            GridView {
                id: channelGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                property int cols: appViewModel ? appViewModel.gridColumns : 2
                cellWidth: Math.floor(width / cols)
                cellHeight: 72
                clip: true
                focus: true
                keyNavigationEnabled: true
                highlight: Rectangle {
                    color: Theme.accent + "30"
                    radius: Theme.borderRadius
                }
                highlightFollowsCurrentItem: true
                model: appViewModel ? appViewModel.channelList : null

                Keys.onReturnPressed: playCurrentItem()
                Keys.onEnterPressed: playCurrentItem()
                Keys.onLeftPressed: categoryList.forceActiveFocus()

                function playCurrentItem() {
                    if (currentIndex < 0 || !appViewModel) return
                    var cl = appViewModel.channelList
                    appViewModel.player.play(cl.streamUrlAt(currentIndex),
                                             cl.nameAt(currentIndex),
                                             cl.logoUrlAt(currentIndex),
                                             cl.channelIdAt(currentIndex))
                    appViewModel.currentView = "player"
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Theme.accent
                        opacity: parent.active ? 0.8 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                    }
                    background: Rectangle {
                        implicitWidth: 6
                        color: "transparent"
                    }
                }

                delegate: Rectangle {
                    width: channelGrid.cellWidth - Theme.spacingSm
                    height: channelGrid.cellHeight - Theme.spacingSm
                    radius: Theme.borderRadius
                    color: chHovered ? Theme.surfaceHover : Theme.surfaceElevated
                    border.color: chHovered ? Theme.accent + "40" : "transparent"
                    border.width: 1

                    property bool chHovered: false

                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingSm
                        spacing: Theme.spacingSm

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

                        Column {
                            spacing: 2

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: isRec ? Theme.error + "40" : recBtnHovered ? Theme.error + "30" : "transparent"
                                property bool recBtnHovered: false
                                property bool isRec: appViewModel ? appViewModel.recordingList.isChannelRecording(model.channelId) : false

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.isRec ? "⏹" : "⏺"
                                    font.pixelSize: 10
                                    color: parent.isRec ? Theme.error : parent.recBtnHovered ? Theme.error : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.recBtnHovered = true
                                    onExited: parent.recBtnHovered = false
                                    onClicked: {
                                        if (!appViewModel) return
                                        if (parent.isRec) {
                                            appViewModel.recordingList.stopChannelRecording(model.channelId)
                                            parent.isRec = false
                                        } else {
                                            appViewModel.recordingList.startNow(model.channelId)
                                            parent.isRec = true
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 13
                                color: grpBtnHov ? Theme.accent : Theme.surfaceHover
                                property bool grpBtnHov: false

                                ToolTip.visible: grpBtnHov
                                ToolTip.text: "Add to group"
                                ToolTip.delay: 400

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: parent.grpBtnHov ? "#ffffff" : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.grpBtnHov = true
                                    onExited: parent.grpBtnHov = false
                                    onClicked: {
                                        addToGroupPopup.channelId = model.channelId
                                        addToGroupPopup.channelName = model.name
                                        addToGroupPopup.open()
                                    }
                                }
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: starHovered ? Theme.surfaceHover : "transparent"
                                property bool starHovered: false
                                property bool isFav: appViewModel ? appViewModel.favoriteList.isFavorite(model.channelId) : false

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.isFav ? "⭐" : "☆"
                                    font.pixelSize: 11
                                    color: parent.isFav ? Theme.warning : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.starHovered = true
                                    onExited: parent.starHovered = false
                                    onClicked: {
                                        if (appViewModel) {
                                            appViewModel.favoriteList.toggleFavorite(model.channelId)
                                            parent.isFav = !parent.isFav
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.chHovered = true
                        onExited: parent.chHovered = false
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.player.play(model.streamUrl, model.name, model.logoUrl, model.channelId)
                                appViewModel.currentView = "player"
                            }
                        }
                        // Note: live streams work with immediate play because HTTP latency
                        // gives the render context time to initialize

                        z: -1
                    }
                }

                onAtYEndChanged: {
                    if (atYEnd && appViewModel) {
                        appViewModel.channelList.loadMore()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: channelGrid.count === 0 && activeServerId > 0
                    text: "No channels found.\nSync the server first."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }

                Text {
                    anchors.centerIn: parent
                    visible: activeServerId === 0
                    text: "Select a server to browse channels."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    property var selectedCategoryId: 0

    function selectServer(serverId) {
        activeServerId = serverId
        selectedCategoryId = 0
        if (appViewModel) {
            appViewModel.categoryList.filterType = "live"
            appViewModel.categoryList.serverId = serverId
            appViewModel.channelList.typeFilter = "live"
            appViewModel.channelList.serverId = serverId
        }
    }

    function selectCategory(catId) {
        selectedCategoryId = catId
        if (appViewModel) {
            appViewModel.channelList.categoryId = catId
        }
    }

    Component.onCompleted: {
        channelGrid.forceActiveFocus()
        if (appViewModel) {
            appViewModel.channelList.searchQuery = ""
            appViewModel.channelList.categoryId = 0
            appViewModel.channelList.typeFilter = "live"
        }
        if (appViewModel && appViewModel.serverList.count > 0) {
            selectServer(appViewModel.serverList.serverIdAt(0))
        }
    }

    Component.onDestruction: {
        if (appViewModel) {
            appViewModel.channelList.typeFilter = ""
            appViewModel.channelList.recentlyAddedFilter = false
        }
    }

    // Add-to-Group popup
    Rectangle {
        id: addToGroupPopup
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 100

        property var channelId: 0
        property string channelName: ""

        function open() { visible = true; refreshGroupOptions() }
        function close() { visible = false }

        MouseArea { anchors.fill: parent; onClicked: addToGroupPopup.close() }

        ListModel { id: groupOptionsModel }

        function refreshGroupOptions() {
            groupOptionsModel.clear()
            if (!appViewModel) return
            var gl = appViewModel.groupList
            var saved = gl.activeGroupId
            gl.activeGroupId = 0
            for (var i = 0; i < gl.count; i++) {
                groupOptionsModel.append({
                    gid: gl.groupIdAt(i),
                    gname: gl.groupNameAt(i),
                    inGroup: gl.isInGroup(gl.groupIdAt(i), addToGroupPopup.channelId)
                })
            }
            gl.activeGroupId = saved
        }

        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: addGrpCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.accent
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: addGrpCol
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                Text {
                    text: "Add to Group"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: addToGroupPopup.channelName
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.surfaceBorder
                }

                ListView {
                    id: groupOptionsList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 200)
                    clip: true
                    model: groupOptionsModel

                    delegate: Rectangle {
                        width: groupOptionsList.width
                        height: 40
                        radius: Theme.borderRadiusSmall
                        color: grpOptHov ? Theme.surfaceHover : "transparent"
                        property bool grpOptHov: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingSm
                            anchors.rightMargin: Theme.spacingSm
                            spacing: Theme.spacingSm

                            Text {
                                text: model.gname
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: addRemLabel.implicitWidth + 16
                                Layout.preferredHeight: 24
                                radius: 12
                                color: model.inGroup ? Theme.error + "30" : Theme.accent + "30"
                                border.color: model.inGroup ? Theme.error : Theme.accent
                                border.width: 1

                                Text {
                                    id: addRemLabel
                                    anchors.centerIn: parent
                                    text: model.inGroup ? "Remove" : "Add"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: model.inGroup ? Theme.error : Theme.accent
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.grpOptHov = true
                            onExited: parent.grpOptHov = false
                            onClicked: {
                                if (!appViewModel) return
                                if (model.inGroup) {
                                    appViewModel.groupList.removeChannel(model.gid, addToGroupPopup.channelId)
                                } else {
                                    appViewModel.groupList.addChannel(model.gid, addToGroupPopup.channelId)
                                }
                                addToGroupPopup.refreshGroupOptions()
                            }
                        }
                    }
                }

                Text {
                    visible: groupOptionsModel.count === 0
                    text: "No groups yet. Create one in the Groups view."
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    width: doneLabel.implicitWidth + 24
                    height: 32
                    radius: Theme.borderRadius
                    color: doneHov ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.surfaceBorder
                    border.width: 1
                    property bool doneHov: false

                    Text { id: doneLabel; anchors.centerIn: parent; text: "Done"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.doneHov = true; onExited: parent.doneHov = false; onClicked: addToGroupPopup.close() }
                }
            }
        }
    }
}
