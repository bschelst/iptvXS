// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: channelsView

    property var activeServerId: 0

    function firstVisibleChannelRow() {
        for (var i = 0; i < chCategoryRepeater.count; i++) {
            var item = chCategoryRepeater.itemAt(i)
            if (item && item.visible && item.rowView && item.rowView.count > 0) {
                return item.rowView
            }
        }
        return null
    }

    function clampListIndex(listView) {
        if (!listView) return
        if (listView.count <= 0) {
            listView.currentIndex = -1
        } else if (listView.currentIndex < 0 || listView.currentIndex >= listView.count) {
            listView.currentIndex = 0
        }
    }

    function focusPrimary() {
        if (channelGrid.visible) {
            clampListIndex(channelGrid)
            channelGrid.forceActiveFocus()
            return
        }
        var row = firstVisibleChannelRow()
        if (row) {
            if (row.count > 0) row.currentIndex = 0
            row.forceActiveFocus()
            return
        }
        focusCategorySidebar()
    }

    function focusCategorySidebar() {
        if (categoryList.count > 0) {
            if (categoryList.currentIndex < 0) categoryList.currentIndex = 0
            categoryList.forceActiveFocus()
        } else if (Window.window && Window.window.focusSidebar) {
            Window.window.focusSidebar()
        }
    }

    function focusSearchField() {
        if (chSearchInput) {
            chSearchInput.forceActiveFocus()
        } else if (Window.window && Window.window.focusSidebar) {
            Window.window.focusSidebar()
        }
    }

    function focusAdjacentChannelRow(rowIndex, currentItemIndex, delta) {
        for (var i = rowIndex + delta; i >= 0 && i < chCategoryRepeater.count; i += delta) {
            var item = chCategoryRepeater.itemAt(i)
            if (item && item.visible && item.rowView && item.rowView.count > 0) {
                item.rowView.currentIndex = Math.max(0, Math.min(currentItemIndex, item.rowView.count - 1))
                item.rowView.forceActiveFocus()
                if (netflixFlickable && item.y !== undefined) {
                    var targetY = item.y - netflixFlickable.height / 3
                    netflixFlickable.contentY = Math.max(0, Math.min(targetY, netflixFlickable.contentHeight - netflixFlickable.height))
                }
                if (netflixFlickable && netflixFlickable.contentY + netflixFlickable.height > netflixFlickable.contentHeight - 400) {
                    loadMoreChannelRows()
                }
                return
            }
        }
        if (delta > 0) {
            var beforeCount = chCategoryRepeater.count
            loadMoreChannelRows()
            if (chCategoryRepeater.count > beforeCount) {
                focusAdjacentChannelRow(rowIndex, currentItemIndex, delta)
            } else {
                focusCategorySidebar()
            }
        } else if (delta < 0) {
            if (selectedCategoryId !== 0 && chSearchInput.text.length === 0) {
                focusCategorySidebar()
            } else {
                focusSearchField()
            }
        }
    }

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
                anchors.rightMargin: 1
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

                    function selectServerAt(index) {
                        if (!appViewModel || !appViewModel.serverList || appViewModel.serverList.count <= 0) return
                        index = Math.max(0, Math.min(appViewModel.serverList.count - 1, index))
                        currentIndex = index
                        selectServer(appViewModel.serverList.serverIdAt(index))
                    }

                    Keys.onUpPressed: {
                        if (currentIndex > 0) {
                            selectServerAt(currentIndex - 1)
                        } else if (Window.window && Window.window.focusSidebar) {
                            Window.window.focusSidebar()
                        }
                    }
                    Keys.onDownPressed: {
                        // Past the last server, fall through into the category
                        // sidebar (filter input → All Channels) so the chain
                        // continues smoothly downward.
                        if (currentIndex < count - 1) {
                            selectServerAt(currentIndex + 1)
                        } else if (catFilterInput) {
                            catFilterInput.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: selectServerAt(currentIndex)
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onLeftPressed: {
                        if (Window.window && Window.window.focusSidebar) {
                            Window.window.focusSidebar()
                        }
                    }
                    Keys.onRightPressed: {
                        // Right from server picker → into the channel content area.
                        if (channelGrid && channelGrid.visible) {
                            if (channelGrid.currentIndex < 0) channelGrid.currentIndex = 0
                            channelGrid.forceActiveFocus()
                        } else if (catFilterInput) {
                            catFilterInput.forceActiveFocus()
                        } else {
                            channelsView.focusCategorySidebar()
                        }
                    }

                    delegate: Rectangle {
                        width: serverPicker.width
                        height: model.enabled ? 36 : 0
                        visible: model.enabled
                        clip: true
                        color: activeServerId === model.serverId
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : srvHovered ? Theme.surfaceHover : "transparent"
                        border.width: serverPicker.activeFocus && serverPicker.currentIndex === index ? 2 : 0
                        border.color: serverPicker.activeFocus && serverPicker.currentIndex === index
                            ? Theme.accent
                            : "transparent"

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

                            onActiveFocusChanged: {
                                if (activeFocus) Qt.inputMethod.show()
                                else Qt.inputMethod.hide()
                            }

                            Keys.onDownPressed: {
                                if (allChannelsBtn) allChannelsBtn.forceActiveFocus()
                            }
                            Keys.onUpPressed: {
                                // Up from filter input → server picker (top of sidebar).
                                if (serverPicker.count > 0) {
                                    if (serverPicker.currentIndex < 0) serverPicker.currentIndex = 0
                                    serverPicker.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (newFilterBtn) newFilterBtn.forceActiveFocus()
                            }
                            Keys.onLeftPressed: {
                                if (serverPicker.count > 0) {
                                    if (serverPicker.currentIndex < 0) serverPicker.currentIndex = 0
                                    serverPicker.forceActiveFocus()
                                } else if (Window.window && Window.window.focusSidebar) {
                                    Window.window.focusSidebar()
                                }
                            }

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
                    id: allChannelsBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: selectedCategoryId === 0
                        ? Theme.accentGlow : allCatHovered ? Theme.surfaceHover : "transparent"

                    property bool allCatHovered: false
                    focus: false
                    activeFocusOnTab: true

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

                    Keys.onDownPressed: {
                        if (categoryList.count > 0) {
                            if (categoryList.currentIndex < 0) categoryList.currentIndex = 0
                            categoryList.forceActiveFocus()
                        }
                    }
                    Keys.onUpPressed: {
                        // Up from "All Channels" → filter categories input.
                        // catFilterInput's own Up handler then jumps to the
                        // server picker, completing the chain to the top.
                        if (catFilterInput) catFilterInput.forceActiveFocus()
                    }
                    Keys.onReturnPressed: selectCategory(0)
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            selectCategory(0)
                            event.accepted = true
                        }
                    }
                }

                ListView {
                    id: categoryList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: appViewModel ? appViewModel.categoryList : null
                    onCountChanged: channelsView.clampListIndex(categoryList)

                    function selectCategoryAt(index) {
                        if (!appViewModel || !appViewModel.categoryList || appViewModel.categoryList.count <= 0) return
                        index = Math.max(0, Math.min(appViewModel.categoryList.count - 1, index))
                        currentIndex = index
                        selectCategory(appViewModel.categoryList.categoryIdAt(index))
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Theme.accent
                            opacity: parent.active ? 0.6 : 0.0
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                        }
                        background: Rectangle { implicitWidth: 4; color: "transparent" }
                    }

                    Keys.onUpPressed: {
                        if (currentIndex > 0) currentIndex--
                        else if (allChannelsBtn) allChannelsBtn.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < count - 1) currentIndex++
                    }
                    Keys.onReturnPressed: if (currentIndex >= 0) selectCategory(appViewModel.categoryList.categoryIdAt(currentIndex))
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onRightPressed: channelsView.focusPrimary()
                    Keys.onLeftPressed: if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()

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
                        border.width: categoryList.activeFocus && categoryList.currentIndex === index ? 2 : 0
                        border.color: categoryList.activeFocus && categoryList.currentIndex === index
                            ? Theme.accent
                            : "transparent"

                        property bool catHovered: false
                        opacity: model.hidden ? 0.5 : 1.0

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        // Favorite star
                        Text {
                            id: catStarIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u2605"
                            font.pixelSize: 10
                            color: Theme.warning
                            visible: model.favorite
                        }

                        Text {
                            anchors.left: model.favorite ? catStarIcon.right : parent.left
                            anchors.leftMargin: model.favorite ? 4 : Theme.spacingLg
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.name
                            font.pixelSize: Theme.fontSizeSm
                            font.strikeout: model.hidden
                            color: selectedCategoryId === model.categoryId
                                ? Theme.textPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                            width: parent.width - (model.favorite ? Theme.spacingLg + 14 : Theme.spacingXl) - 60
                        }

                        // Action icons (visible on hover)
                        Row {
                            id: catActionRow
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            opacity: catHovered ? 1.0 : 0.0
                            enabled: catHovered

                            // Rename (pencil)
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: catRenameHov ? Theme.surfaceHover : "transparent"
                                property bool catRenameHov: false

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u270E"
                                    font.pixelSize: 11
                                    color: parent.catRenameHov ? Theme.textPrimary : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.catRenameHov = true
                                    onExited: parent.catRenameHov = false
                                    onClicked: {
                                        renameDialog.categoryId = model.categoryId
                                        renameDialog.originalName = model.name
                                        renameDialog.open()
                                    }
                                }
                            }

                            // Favorite toggle (star)
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: catFavHov ? Theme.surfaceHover : "transparent"
                                property bool catFavHov: false

                                Text {
                                    anchors.centerIn: parent
                                    text: model.favorite ? "\u2605" : "\u2606"
                                    font.pixelSize: 12
                                    color: model.favorite ? Theme.warning : (parent.catFavHov ? Theme.textPrimary : Theme.textMuted)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.catFavHov = true
                                    onExited: parent.catFavHov = false
                                    onClicked: {
                                        if (appViewModel) {
                                            appViewModel.categoryList.toggleFavorite(model.categoryId)
                                            Qt.callLater(channelsView.reloadChannelRows)
                                        }
                                    }
                                }
                            }

                            // Visibility toggle (eye)
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: catVisHov ? Theme.surfaceHover : "transparent"
                                property bool catVisHov: false

                                Text {
                                    anchors.centerIn: parent
                                    text: model.hidden ? "\uD83D\uDE48" : "\uD83D\uDC41"
                                    font.pixelSize: 11
                                    color: parent.catVisHov ? Theme.textPrimary : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.catVisHov = true
                                    onExited: parent.catVisHov = false
                                    onClicked: {
                                        if (appViewModel) {
                                            appViewModel.categoryList.toggleHidden(model.categoryId)
                                            Qt.callLater(channelsView.reloadChannelRows)
                                        }
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            onHoveredChanged: catHovered = hovered
                        }

                        TapHandler {
                            onTapped: selectCategory(model.categoryId)
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
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 32
                        radius: 16
                        color: Theme.surface
                        border.color: chSearchInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            Text {
                                text: "\uD83D\uDD0D"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        TextInput {
                            id: chSearchInput
                            width: parent.width - 30
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                clip: true
                                selectByMouse: true

                                onActiveFocusChanged: {
                                    if (activeFocus) Qt.inputMethod.show()
                                    else Qt.inputMethod.hide()
                                }

                            onTextChanged: {
                                if (appViewModel) {
                                    appViewModel.channelList.typeFilter = "live"
                                    appViewModel.channelList.searchQuery = text
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search channels..."
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textMuted
                                visible: !chSearchInput.text && !chSearchInput.activeFocus
                            }

                            Keys.onLeftPressed: {
                                channelsView.focusCategorySidebar()
                            }
                            Keys.onRightPressed: {
                                channelsView.focusPrimary()
                            }
                            Keys.onDownPressed: {
                                channelsView.focusPrimary()
                            }
                            Keys.onUpPressed: {
                                if (Window.window && Window.window.focusSidebar) {
                                    Window.window.focusSidebar()
                                }
                            }
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
                                    if (Window.window && Window.window.focusSidebar) {
                                        Window.window.focusSidebar()
                                    }
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                    Rectangle {
                        id: newFilterBtn
                        Layout.preferredWidth: newFilterRow.implicitWidth + 24
                        Layout.preferredHeight: 32
                        radius: 16
                        color: {
                            var active = appViewModel && appViewModel.channelList.recentlyAddedFilter
                            return active ? Theme.accent : newFilterHov ? Theme.surfaceHover : Theme.surface
                        }
                        border.width: 1
                        border.color: {
                            var active = appViewModel && appViewModel.channelList.recentlyAddedFilter
                            return active ? Theme.accent : Theme.surfaceBorder
                        }
                        focus: false
                        activeFocusOnTab: true
                        property bool newFilterHov: false

                        Row {
                            id: newFilterRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                id: newFilterLabel
                                text: "New"
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: appViewModel && appViewModel.channelList.recentlyAddedFilter
                                color: appViewModel && appViewModel.channelList.recentlyAddedFilter
                                    ? Theme.textOnAccent : Theme.textSecondary
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

                        Keys.onLeftPressed: {
                            if (catFilterInput) catFilterInput.forceActiveFocus()
                        }
                        Keys.onRightPressed: {
                            if (allChannelsBtn) allChannelsBtn.forceActiveFocus()
                        }
                        Keys.onDownPressed: {
                            channelsView.focusPrimary()
                        }
                        Keys.onReturnPressed: {
                            if (appViewModel) {
                                appViewModel.channelList.recentlyAddedFilter =
                                    !appViewModel.channelList.recentlyAddedFilter
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                if (appViewModel) {
                                    appViewModel.channelList.recentlyAddedFilter =
                                        !appViewModel.channelList.recentlyAddedFilter
                                }
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            // --- Netflix-style category rows ---
            ListModel {
                id: chCategoryModel
                // Each element: { catId: int, catName: string }
            }

            Flickable {
                id: netflixFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: netflixColumn.implicitHeight
                visible: chSearchInput.text.length === 0 && selectedCategoryId === 0
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                onContentYChanged: {
                    if (contentY + height > contentHeight - 400) {
                        loadMoreChannelRows()
                    }
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

                Column {
                    id: netflixColumn
                    width: parent.width
                    spacing: Theme.spacingMd

                    Repeater {
                        id: chCategoryRepeater
                        model: chCategoryModel

                        delegate: Column {
                        id: chCatDelegate
                        width: netflixColumn.width
                        spacing: Theme.spacingSm
                        visible: chRowModel.count > 0

                        property int catIdValue: model.catId
                        property string catNameValue: model.catName
                        property alias rowView: chRowListView

                        function snapRowList(direction) {
                            if (!chRowListView || chRowListView.count <= 0) return

                            var step = 208 + chRowListView.spacing
                            if (step <= 0) return

                            var minX = -chRowListView.leftMargin
                            var maxX = Math.max(minX, chRowListView.contentWidth - chRowListView.width + chRowListView.rightMargin)
                            var maxBoundary = minX + Math.floor((maxX - minX) / step) * step
                            var current = chRowListView.contentX
                            var target

                            if (direction < 0) {
                                target = minX + Math.floor((current - minX - 0.001) / step) * step
                            } else {
                                target = minX + Math.ceil((current - minX + 0.001) / step) * step
                            }

                            target = Math.max(minX, Math.min(maxBoundary, target))
                            chRowListView.contentX = target
                        }

                            ListModel {
                                id: chRowModel
                            }

                            Component.onCompleted: {
                                if (!appViewModel) return
                                var items = appViewModel.channelList.channelsForCategory(catIdValue, 30)
                                for (var i = 0; i < items.length; i++) {
                                    chRowModel.append(items[i])
                                }
                            }

                            // Category header
                            Item {
                                width: parent.width
                                height: 36

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingMd
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: catNameValue
                                    font.pixelSize: Theme.fontSizeMd
                                    font.bold: true
                                    color: Theme.textPrimary
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingSm
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    visible: chRowListView.contentWidth > chRowListView.width - chRowListView.leftMargin - chRowListView.rightMargin

                                    Rectangle {
                                        width: 28; height: 28; radius: 14
                                        color: chScrollLeftHov ? Theme.surfaceHover : "transparent"
                                        property bool chScrollLeftHov: false

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u2039"
                                            font.pixelSize: 22; font.bold: true
                                            color: parent.chScrollLeftHov ? Theme.textPrimary : Theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.chScrollLeftHov = true; onExited: parent.chScrollLeftHov = false
                                            onClicked: chCatDelegate.snapRowList(-1)
                                        }
                                    }

                                    Rectangle {
                                        width: 28; height: 28; radius: 14
                                        color: chScrollRightHov ? Theme.surfaceHover : "transparent"
                                        property bool chScrollRightHov: false

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u203A"
                                            font.pixelSize: 22; font.bold: true
                                            color: parent.chScrollRightHov ? Theme.textPrimary : Theme.textMuted
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.chScrollRightHov = true; onExited: parent.chScrollRightHov = false
                                            onClicked: chCatDelegate.snapRowList(1)
                                        }
                                    }
                                }
                            }

                            // Horizontal channel row
                            ListView {
                                id: chRowListView
                                width: parent.width
                                height: 240
                                orientation: ListView.Horizontal
                                spacing: Theme.spacingSm
                                clip: true
                                leftMargin: Theme.spacingMd
                                rightMargin: Theme.spacingMd
                                boundsBehavior: Flickable.StopAtBounds
                                model: chRowModel
                                keyNavigationEnabled: true
                                property int rowIndex: index

                                function playChannelAt(idx) {
                                    if (idx < 0 || !appViewModel) return
                                    var item = model.get(idx)
                                    if (!item) return
                                    playLiveChannel(item.channelId, item.streamUrl, item.name, item.logoUrl, item.epgChannelId, catIdValue)
                                }

                                Keys.onReturnPressed: playCurrentItem()
                                Keys.onEnterPressed: playCurrentItem()
                                Keys.onLeftPressed: {
                                    if (currentIndex > 0) currentIndex--
                                    else channelsView.focusCategorySidebar()
                                }
                                Keys.onRightPressed: {
                                    if (currentIndex < count - 1) currentIndex++
                                }
                                Keys.onUpPressed: channelsView.focusAdjacentChannelRow(rowIndex, currentIndex, -1)
                                Keys.onDownPressed: channelsView.focusAdjacentChannelRow(rowIndex, currentIndex, 1)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                                        playCurrentItem()
                                        event.accepted = true
                                    }
                                }

                                function playCurrentItem() {
                                    playChannelAt(currentIndex)
                                }

                                delegate: Item {
                                    width: 158
                                    height: 232
                                    focus: chRowListView.activeFocus && chRowListView.currentIndex === index
                                    activeFocusOnTab: true

                                    function activate() {
                                        chRowListView.playCurrentItem()
                                    }

                                        Rectangle {
                                            id: chNetCard
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            radius: 10
                                            color: chNetHov ? Theme.surfaceHover : Theme.surfaceElevated
                                            border.width: chNetHov || (chRowListView.activeFocus && chRowListView.currentIndex === index) ? 2 : 1
                                            border.color: chNetHov || (chRowListView.activeFocus && chRowListView.currentIndex === index)
                                                ? Theme.accent
                                                : Theme.surfaceBorder
                                            clip: true
                                            property bool chNetHov: false

                                        // Logo area (centered, not cropped). Height tracks
                                        // card height so a portrait card auto-leaves room
                                        // for the name strip below.
                                        Rectangle {
                                            id: chNetLogoArea
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: parent.height - 52
                                            color: "transparent"

                                            Image {
                                                id: chNetLogoImg
                                                anchors.centerIn: parent
                                                width: parent.width - 24
                                                height: parent.height - 16
                                                source: model.logoUrl || ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                visible: status === Image.Ready
                                            }

                                        }

                                        // Fallback logo — centered in the WHOLE card
                                        // (not just the logo area), so it sits in the
                                        // middle of the visible card vertically.
                                        Image {
                                            visible: chNetLogoImg.status !== Image.Ready
                                            anchors.centerIn: chNetCard
                                            width: Math.min(chNetCard.width, chNetCard.height) - 48
                                            height: width
                                            source: "qrc:/images/iptvxs_tray.png"
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: false
                                            cache: true
                                            opacity: 0.2
                                        }

                                        // Channel name below logo
                                        Item {
                                            anchors.top: chNetLogoArea.bottom
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right

                                        Text {
                                            anchors.centerIn: parent
                                            width: parent.width - 16
                                            text: model.name
                                            font.pixelSize: Theme.fontSizeXs
                                            font.bold: true
                                            color: Theme.textPrimary
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            horizontalAlignment: Text.AlignHCenter
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

                                        // Favorite heart button (top-right)
                                        Rectangle {
                                            id: favBtn
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.topMargin: 6
                                            anchors.rightMargin: 6
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: favHov ? "#80000000" : "#50000000"
                                            property bool favHov: false
                                            property bool isFav: appViewModel ? appViewModel.favoriteList.isFavorite(model.channelId) : false

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.isFav ? "\u2764" : "\u2661"
                                                font.pixelSize: 13
                                                color: parent.isFav ? Theme.error : "#FFFFFF"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: parent.favHov = true
                                                onExited: parent.favHov = false
                                                onClicked: {
                                                    if (appViewModel) {
                                                        appViewModel.favoriteList.toggleFavorite(model.channelId)
                                                        parent.isFav = !parent.isFav
                                                    }
                                                }
                                            }
                                        }

                                        // Catchup / timeshift indicator (server-side archive)
                                        Rectangle {
                                            visible: (model.tvArchive || 0) > 0
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.margins: 6
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: "#C0000000"
                                            z: 200

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\u21BB"
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: "DejaVu Sans"
                                                color: "#ffffff"
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            anchors.rightMargin: 34
                                            onEntered: chNetCard.chNetHov = true
                                            onExited: chNetCard.chNetHov = false
                                            onClicked: activate()
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: chNetCard.radius
                                            color: "transparent"
                                            border.color: chNetCard.chNetHov || (chRowListView.activeFocus && chRowListView.currentIndex === index)
                                                ? Theme.accent : Theme.surfaceBorder
                                            border.width: (chNetCard.chNetHov || (chRowListView.activeFocus && chRowListView.currentIndex === index)) ? 2 : 1
                                            z: 100
                                        }
                                    }

                                }
                            }
                        }
                    }

                    // Empty state
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: chCategoryModel.count === 0 && activeServerId > 0
                        topPadding: 80
                        text: "No channels found.\nSync the server first."
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: activeServerId === 0
                        topPadding: 80
                        text: "Select a server to browse channels."
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.textMuted
                    }
                }
            }

            // --- Search results / single-category grid (Netflix-style cards) ---
            GridView {
                id: channelGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: Theme.spacingMd
                Layout.rightMargin: Theme.spacingSm
                visible: chSearchInput.text.length > 0 || selectedCategoryId !== 0
                cellWidth: 158
                cellHeight: 232
                clip: true
                focus: visible && !chSearchInput.activeFocus
                keyNavigationEnabled: true
                property int cols: Math.max(1, Math.floor(width / cellWidth))
                model: appViewModel ? appViewModel.channelList : null
                onCountChanged: channelsView.clampListIndex(channelGrid)

                Keys.onReturnPressed: function(event) { playCurrentItem(); event.accepted = true }
                Keys.onEnterPressed: function(event) { playCurrentItem(); event.accepted = true }
                Keys.onUpPressed: {
                    if (currentIndex >= cols) {
                        currentIndex -= cols
                    } else if (currentIndex >= 0) {
                        if (selectedCategoryId !== 0) channelsView.focusCategorySidebar()
                        else channelsView.focusSearchField()
                    }
                }
                Keys.onLeftPressed: {
                    if (currentIndex % cols === 0)
                        channelsView.focusCategorySidebar()
                    else
                        moveCurrentIndexLeft()
                }
                Keys.onDownPressed: {
                    if (count <= 0) return
                    var lastRow = Math.floor((count - 1) / cols)
                    var currentRow = Math.floor(currentIndex / cols)
                    if (currentRow >= lastRow) {
                        channelsView.focusCategorySidebar()
                    } else {
                        currentIndex = Math.min(currentIndex + cols, count - 1)
                    }
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                        playCurrentItem()
                        event.accepted = true
                    }
                }

                function playCurrentItem() {
                    if (currentIndex < 0 || !appViewModel) return
                    if (currentItem && currentItem.activate) {
                        currentItem.activate()
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Theme.accent
                        opacity: parent.active ? 0.8 : 0.3
                    }
                    background: Rectangle { implicitWidth: 6; color: "transparent" }
                }

                delegate: Item {
                    width: channelGrid.cellWidth
                    height: channelGrid.cellHeight
                    focus: channelGrid.activeFocus && channelGrid.currentIndex === index
                    activeFocusOnTab: true
                    function activate() {
                        playLiveChannel(model.channelId, model.streamUrl, model.name, model.logoUrl, model.epgChannelId, selectedCategoryId)
                    }

                    Rectangle {
                        id: chNetCard
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 10
                        color: Theme.surfaceElevated
                        clip: true
                        property bool chHovered: false

                        function activate() {
                            if (appViewModel) {
                                playLiveChannel(model.channelId, model.streamUrl, model.name, model.logoUrl, model.epgChannelId, selectedCategoryId)
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

                        Image {
                            id: chGridLogo
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height - 50
                            source: model.logoUrl || ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        // Fallback logo — centered in the WHOLE card so it
                        // sits in the middle of the visible card vertically.
                        Image {
                            visible: !chGridLogo.visible
                            anchors.centerIn: chNetCard
                            width: Math.min(chNetCard.width, chNetCard.height) - 48
                            height: width
                            source: "qrc:/images/iptvxs_tray.png"
                            fillMode: Image.PreserveAspectFit
                            asynchronous: false
                            cache: true
                            opacity: 0.15
                        }

                        // Catchup / timeshift indicator (server-side archive)
                        Rectangle {
                            visible: (model.tvArchive || 0) > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 26
                            height: 26
                            radius: 13
                            color: "#C0000000"
                            z: 200

                            Text {
                                anchors.centerIn: parent
                                text: "↻"
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "DejaVu Sans"
                                color: "#ffffff"
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.bottomMargin: 8
                            text: model.name
                            font.pixelSize: Theme.fontSizeXs
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: chNetCard.chHovered = true
                            onExited: chNetCard.chHovered = false
                            onClicked: activate()
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: chNetCard.radius
                            color: "transparent"
                            border.color: (channelGrid.activeFocus && channelGrid.currentIndex === index)
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: (channelGrid.activeFocus && channelGrid.currentIndex === index) ? 2 : 1
                            z: 100
                        }
                    }
                }

                onAtYEndChanged: {
                    if (atYEnd && appViewModel) {
                        appViewModel.channelList.loadMore()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: channelGrid.count === 0
                    text: "No results found."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    property var selectedCategoryId: 0
    property int chRowsLoaded: 0
    property int chRowsBatchSize: 8

    function reloadChannelRows() {
        chCategoryModel.clear()
        chRowsLoaded = 0
        loadMoreChannelRows()
    }

    function loadMoreChannelRows() {
        if (!appViewModel) return
        var catList = appViewModel.categoryList
        if (!catList) return
        var end = Math.min(chRowsLoaded + chRowsBatchSize, catList.count)
        for (var i = chRowsLoaded; i < end; i++) {
            var catId = catList.categoryIdAt(i)
            // Skip "All Channels" (categoryId = 0) — too many items
            if (catId === 0) continue
            // Skip hidden categories
            if (catList.isCategoryHidden(catId)) continue
            chCategoryModel.append({
                catId: catId,
                catName: catList.categoryNameAt(i)
            })
        }
        chRowsLoaded = end
    }

    function selectServer(serverId) {
        activeServerId = serverId
        selectedCategoryId = 0
        if (appViewModel) {
            appViewModel.categoryList.filterType = "live"
            appViewModel.categoryList.serverId = serverId
            appViewModel.channelList.typeFilter = "live"
            appViewModel.channelList.serverId = serverId
            appViewModel.channelList.categoryId = 0
            appViewModel.channelList.refresh()
            reloadChannelRows()
        }
    }

    function ensureEnabledServerSelection(changedServerId, enabled) {
        if (enabled) return
        if (!appViewModel || !appViewModel.serverList) return
        if (activeServerId !== changedServerId) return

        var fallbackIdx = appViewModel.serverList.firstEnabledServerIndex()
        if (fallbackIdx >= 0) {
            selectServer(appViewModel.serverList.serverIdAt(fallbackIdx))
        }
    }

    function selectCategory(catId) {
        selectedCategoryId = catId
        if (appViewModel) {
            appViewModel.channelList.categoryId = catId
        }
    }

    function categoryNameForId(catId) {
        if (!appViewModel || !appViewModel.categoryList || catId <= 0) return ""
        for (var i = 0; i < appViewModel.categoryList.count; i++) {
            if (appViewModel.categoryList.categoryIdAt(i) === catId) {
                return appViewModel.categoryList.categoryNameAt(i)
            }
        }
        return ""
    }

    function seedZapContextForCategory(catId, currentChannelId) {
        if (!appViewModel) return
        if (catId <= 0 || chSearchInput.text.length > 0) {
            appViewModel.clearZapContext()
            return
        }
        var zapItems = appViewModel.channelList.channelsForCategory(catId, 500)
        appViewModel.setZapContext(zapItems, currentChannelId, categoryNameForId(catId) || "Live TV")
    }

    function playLiveChannel(channelId, streamUrl, name, logoUrl, epgChannelId, categoryId) {
        if (!appViewModel || !streamUrl || !name) return
        seedZapContextForCategory(categoryId, channelId)
        appViewModel.player.play(streamUrl, name, logoUrl, channelId, epgChannelId || "", 0, true, true)
        appViewModel.currentView = "player"
    }

    Component.onCompleted: {
        if (appViewModel) {
            appViewModel.channelList.searchQuery = ""
            appViewModel.channelList.categoryId = 0
            appViewModel.channelList.typeFilter = "live"
        }
        if (appViewModel && appViewModel.serverList.count > 0) {
            var primaryIdx = appViewModel.serverList.primaryServerIndex()
            if (primaryIdx >= 0) {
                selectServer(appViewModel.serverList.serverIdAt(primaryIdx))
            } else {
                var firstEnabledIdx = appViewModel.serverList.firstEnabledServerIndex()
                if (firstEnabledIdx >= 0) {
                    selectServer(appViewModel.serverList.serverIdAt(firstEnabledIdx))
                }
            }
        }
    }

    Connections {
        target: appViewModel ? appViewModel.serverList : null
        function onServerEnabledChanged(serverId, enabled) {
            ensureEnabledServerSelection(serverId, enabled)
        }
    }

    Component.onDestruction: {
        if (appViewModel) {
            appViewModel.channelList.typeFilter = ""
            appViewModel.channelList.recentlyAddedFilter = false
        }
    }

    // Rename Category dialog
    Rectangle {
        id: renameDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 100

        property int categoryId: 0
        property string originalName: ""

        function open() {
            renameInput.text = originalName
            visible = true
            renameInput.forceActiveFocus()
            renameInput.selectAll()
        }
        function close() {
            visible = false
            Qt.callLater(function() {
                if (categoryList && categoryList.count > 0) {
                    categoryList.forceActiveFocus()
                } else {
                    focusCategorySidebar()
                }
            })
        }

        MouseArea { anchors.fill: parent; onClicked: renameDialog.close() }

        Rectangle {
            anchors.centerIn: parent
            width: 340
            height: renameCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.accent
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: renameCol
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                Text {
                    text: "Rename Category"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: "Original: " + renameDialog.originalName
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.borderRadius
                    color: Theme.surface
                    border.color: renameInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                        TextInput {
                            id: renameInput
                        anchors.fill: parent
                        anchors.margins: Theme.spacingSm
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textPrimary
                        clip: true
                        selectByMouse: true

                        Keys.onReturnPressed: {
                            if (appViewModel && renameDialog.categoryId > 0) {
                                appViewModel.categoryList.renameCategory(renameDialog.categoryId, renameInput.text)
                                renameDialog.close()
                                Qt.callLater(channelsView.reloadChannelRows)
                            }
                        }
                        Keys.onEscapePressed: renameDialog.close()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                renameDialog.close()
                                event.accepted = true
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    // Reset to original button
                    Rectangle {
                        width: resetLabel.implicitWidth + 20
                        height: 32
                        radius: Theme.borderRadius
                        color: resetHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        property bool resetHov: false

                        Text { id: resetLabel; anchors.centerIn: parent; text: "Reset"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: parent.resetHov = true; onExited: parent.resetHov = false
                            onClicked: {
                                if (appViewModel && renameDialog.categoryId > 0) {
                                    appViewModel.categoryList.renameCategory(renameDialog.categoryId, "")
                                    renameDialog.close()
                                    Qt.callLater(channelsView.reloadChannelRows)
                                }
                            }
                        }
                        Keys.onReturnPressed: {
                            if (appViewModel && renameDialog.categoryId > 0) {
                                appViewModel.categoryList.renameCategory(renameDialog.categoryId, "")
                                renameDialog.close()
                                Qt.callLater(channelsView.reloadChannelRows)
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                if (appViewModel && renameDialog.categoryId > 0) {
                                    appViewModel.categoryList.renameCategory(renameDialog.categoryId, "")
                                    renameDialog.close()
                                    Qt.callLater(channelsView.reloadChannelRows)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                renameDialog.close()
                                event.accepted = true
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: cancelLabel.implicitWidth + 20
                        height: 32
                        radius: Theme.borderRadius
                        color: cancelHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        property bool cancelHov: false

                        Text { id: cancelLabel; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.cancelHov = true; onExited: parent.cancelHov = false; onClicked: renameDialog.close() }
                        Keys.onReturnPressed: renameDialog.close()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                                    || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                renameDialog.close()
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        width: saveLabel.implicitWidth + 20
                        height: 32
                        radius: Theme.borderRadius
                        color: saveHov ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.80)
                        property bool saveHov: false

                        Text { id: saveLabel; anchors.centerIn: parent; text: "Save"; font.pixelSize: Theme.fontSizeSm; font.bold: true; color: Theme.textOnAccent }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: parent.saveHov = true; onExited: parent.saveHov = false
                            onClicked: {
                                if (appViewModel && renameDialog.categoryId > 0) {
                                    appViewModel.categoryList.renameCategory(renameDialog.categoryId, renameInput.text)
                                    renameDialog.close()
                                    Qt.callLater(channelsView.reloadChannelRows)
                                }
                            }
                        }
                        Keys.onReturnPressed: {
                            if (appViewModel && renameDialog.categoryId > 0) {
                                appViewModel.categoryList.renameCategory(renameDialog.categoryId, renameInput.text)
                                renameDialog.close()
                                Qt.callLater(channelsView.reloadChannelRows)
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                if (appViewModel && renameDialog.categoryId > 0) {
                                    appViewModel.categoryList.renameCategory(renameDialog.categoryId, renameInput.text)
                                    renameDialog.close()
                                    Qt.callLater(channelsView.reloadChannelRows)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                renameDialog.close()
                                event.accepted = true
                            }
                        }
                    }
                }
            }
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

        function toggleGroupAt(index) {
            if (!appViewModel || index < 0 || index >= groupOptionsModel.count) return
            var item = groupOptionsModel.get(index)
            if (!item) return
            if (item.inGroup) {
                appViewModel.groupList.removeChannel(item.gid, addToGroupPopup.channelId)
            } else {
                appViewModel.groupList.addChannel(item.gid, addToGroupPopup.channelId)
            }
            addToGroupPopup.refreshGroupOptions()
        }

        function open() {
            visible = true
            refreshGroupOptions()
            Qt.callLater(function() {
                if (groupOptionsList && groupOptionsModel.count > 0) {
                    if (groupOptionsList.currentIndex < 0) groupOptionsList.currentIndex = 0
                    groupOptionsList.forceActiveFocus()
                } else if (doneBtn) {
                    doneBtn.forceActiveFocus()
                }
            })
        }
        function close() {
            visible = false
            Qt.callLater(function() {
                focusPrimary()
            })
        }

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
                    keyNavigationEnabled: true
                    currentIndex: -1
                    highlightFollowsCurrentItem: true
                    onCountChanged: channelsView.clampListIndex(groupOptionsList)

                    Keys.onUpPressed: {
                        if (currentIndex > 0) {
                            currentIndex--
                        } else if (doneBtn) {
                            doneBtn.forceActiveFocus()
                        }
                    }
                    Keys.onDownPressed: {
                        if (currentIndex < count - 1) {
                            if (currentIndex < 0) currentIndex = 0
                            else currentIndex++
                        } else if (doneBtn) {
                            doneBtn.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: addToGroupPopup.toggleGroupAt(currentIndex)
                    Keys.onEnterPressed: addToGroupPopup.toggleGroupAt(currentIndex)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                addToGroupPopup.toggleGroupAt(currentIndex)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                addToGroupPopup.close()
                                event.accepted = true
                            }
                        }

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
                                color: model.inGroup ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.19) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.19)
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
                            onClicked: addToGroupPopup.toggleGroupAt(index)
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
                    id: doneBtn
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
                    Keys.onReturnPressed: addToGroupPopup.close()
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                                || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                            addToGroupPopup.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (groupOptionsList && groupOptionsModel.count > 0) {
                                groupOptionsList.forceActiveFocus()
                            }
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }
}
