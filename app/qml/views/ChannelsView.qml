import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: channelsView

    property int64_t activeServerId: 0

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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingMd
                        anchors.rightMargin: Theme.spacingMd

                        Text {
                            text: "Servers"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textMuted
                            Layout.fillWidth: true
                        }
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
                            ? Theme.accentGlow : srvHovered ? Theme.surfaceHover : "transparent"

                        property bool srvHovered: false

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingMd
                            anchors.verticalCenter: parent.verticalCenter
                            text: model.name
                            font.pixelSize: Theme.fontSizeSm
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
                    height: 1
                    color: Theme.surfaceBorder
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingMd
                        anchors.rightMargin: Theme.spacingMd

                        Text {
                            text: "Categories"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textMuted
                            Layout.fillWidth: true
                        }

                        Text {
                            text: appViewModel ? appViewModel.categoryList.count : 0
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
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
                    model: appViewModel ? appViewModel.categoryList : null

                    delegate: Rectangle {
                        width: categoryList.width
                        height: 36
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

                    Text {
                        text: {
                            var total = appViewModel ? appViewModel.channelList.totalCount : 0
                            return total + " channels"
                        }
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 240
                        Layout.preferredHeight: 32
                        radius: 16
                        color: Theme.surfaceElevated
                        border.color: channelSearch.activeFocus ? Theme.accent : Theme.surfaceBorder
                        border.width: 1

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingSm
                            anchors.rightMargin: Theme.spacingSm
                            spacing: Theme.spacingSm

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "🔍"
                                font.pixelSize: Theme.fontSizeXs
                                opacity: 0.5
                            }

                            TextInput {
                                id: channelSearch
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search channels..."
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textMuted
                                    visible: !channelSearch.text && !channelSearch.activeFocus
                                }

                                onTextChanged: searchTimer.restart()

                                Timer {
                                    id: searchTimer
                                    interval: 300
                                    onTriggered: {
                                        if (appViewModel)
                                            appViewModel.channelList.searchQuery = channelSearch.text
                                    }
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
                cellWidth: 220
                cellHeight: 72
                clip: true
                model: appViewModel ? appViewModel.channelList : null

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
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
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
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
                                font.pixelSize: Theme.fontSizeMd
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
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.chHovered = true
                        onExited: parent.chHovered = false
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.player.play(model.streamUrl, model.name, model.logoUrl)
                                appViewModel.currentView = "player"
                            }
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

    property int64_t selectedCategoryId: 0

    function selectServer(serverId) {
        activeServerId = serverId
        selectedCategoryId = 0
        if (appViewModel) {
            appViewModel.channelList.serverId = serverId
            appViewModel.categoryList.serverId = serverId
        }
    }

    function selectCategory(catId) {
        selectedCategoryId = catId
        if (appViewModel) {
            appViewModel.channelList.categoryId = catId
        }
    }

    Component.onCompleted: {
        if (appViewModel && appViewModel.serverList.count > 0) {
            selectServer(appViewModel.serverList.serverIdAt(0))
        }
    }
}
