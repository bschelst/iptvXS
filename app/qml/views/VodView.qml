import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: vodView

    property var activeServerId: 0
    property string activeType: "vod"

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
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
                        height: model.enabled ? 36 : 0
                        visible: model.enabled
                        clip: true
                        color: activeServerId === model.serverId
                            ? Theme.accent + "25" : srvHov ? Theme.surfaceHover : "transparent"

                        property bool srvHov: false

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
                            onEntered: parent.srvHov = true
                            onExited: parent.srvHov = false
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

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingMd
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        text: "TYPE"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: Theme.textMuted
                        opacity: 0.7
                    }
                }

                Repeater {
                    model: [
                        { type: "vod", label: "Movies" },
                        { type: "series", label: "Series" }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: activeType === modelData.type
                            ? Theme.accent + "25" : typeHov ? Theme.surfaceHover : "transparent"

                        property bool typeHov: false

                        Rectangle {
                            visible: activeType === modelData.type
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 20; radius: 2
                            color: Theme.accent
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingLg
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: activeType === modelData.type
                            color: activeType === modelData.type
                                ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.typeHov = true
                            onExited: parent.typeHov = false
                            onClicked: {
                                activeType = modelData.type
                                reloadVod()
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
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
                            return total + " " + (activeType === "vod" ? "movies" : "series")
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
                        border.color: vodSearch.activeFocus ? Theme.accent : Theme.surfaceBorder
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: vodSearch.forceActiveFocus()
                            cursorShape: Qt.IBeamCursor
                        }

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
                                id: vodSearch
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                clip: true
                                selectByMouse: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Search..."
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textMuted
                                    visible: !vodSearch.text && !vodSearch.activeFocus
                                }

                                onTextChanged: vodSearchTimer.restart()

                                Timer {
                                    id: vodSearchTimer
                                    interval: 300
                                    onTriggered: {
                                        if (appViewModel)
                                            appViewModel.channelList.searchQuery = vodSearch.text
                                    }
                                }
                            }
                        }
                    }
                }
            }

            GridView {
                id: vodGrid
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

                function playCurrentItem() {
                    if (currentIndex < 0 || !appViewModel) return
                    var cl = appViewModel.channelList
                    var type = cl.typeAt(currentIndex)
                    if (type === "series") {
                        appViewModel.fetchSeriesEpisodes(cl.serverIdAt(currentIndex),
                                                         cl.externalIdAt(currentIndex),
                                                         cl.nameAt(currentIndex),
                                                         cl.logoUrlAt(currentIndex))
                    } else {
                        appViewModel.player.play(cl.streamUrlAt(currentIndex),
                                                 cl.nameAt(currentIndex),
                                                 cl.logoUrlAt(currentIndex),
                                                 cl.channelIdAt(currentIndex))
                        appViewModel.currentView = "player"
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

                delegate: Rectangle {
                    width: vodGrid.cellWidth - Theme.spacingSm
                    height: vodGrid.cellHeight - Theme.spacingSm
                    radius: Theme.borderRadius
                    color: vodItemHov ? Theme.surfaceHover : Theme.surfaceElevated
                    border.color: vodItemHov ? Theme.accent + "40" : "transparent"
                    border.width: 1

                    property bool vodItemHov: false

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
                                source: model.logoUrl && model.logoUrl.indexOf("http") === 0 ? model.logoUrl : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "🎬"
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
                                text: model.type === "vod" ? "Movie" : "Series"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.vodItemHov = true
                        onExited: parent.vodItemHov = false
                        onClicked: {
                            if (appViewModel) {
                                if (model.type === "series") {
                                    appViewModel.fetchSeriesEpisodes(model.serverId, model.externalId, model.name, model.logoUrl)
                                } else {
                                    appViewModel.player.play(model.streamUrl, model.name, model.logoUrl, model.channelId)
                                    appViewModel.currentView = "player"
                                }
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
                    visible: vodGrid.count === 0 && activeServerId > 0
                    text: "No VOD content found.\nSync the server first."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }

                Text {
                    anchors.centerIn: parent
                    visible: activeServerId === 0
                    text: "Select a server to browse VOD content."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                }
            }
        }
    }

    Connections {
        target: appViewModel ? appViewModel.serverList : null
        function onSyncFinished(serverId) {
            if (serverId === activeServerId) {
                reloadVod()
            }
        }
        function onSyncingChanged() {}
    }

    Connections {
        target: appViewModel
        function onSeriesEpisodesReady(seriesName, seasons) {
            episodeDialog.seriesTitle = seriesName
            episodeDialog.seasonsData = seasons
            episodeDialog.selectedSeason = 0
            episodeDialog.visible = true
            episodeList.forceActiveFocus()
            episodeList.currentIndex = 0
        }
    }

    Rectangle {
        id: episodeDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 200

        property string seriesTitle: ""
        property var seasonsData: []
        property int selectedSeason: 0

        MouseArea {
            anchors.fill: parent
            onClicked: episodeDialog.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 600)
            height: Math.min(parent.height - 80, 500)
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.surfaceBorder
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: episodeDialog.seriesTitle
                        font.pixelSize: Theme.fontSizeLg
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: closeBtnHov ? Theme.surfaceHover : "transparent"
                        property bool closeBtnHov: false

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 16
                            font.bold: true
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.closeBtnHov = true
                            onExited: parent.closeBtnHov = false
                            onClicked: episodeDialog.visible = false
                        }
                    }
                }

                Row {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: episodeDialog.seasonsData

                        Rectangle {
                            width: seasonLabel.implicitWidth + 20
                            height: 32
                            radius: 16
                            color: episodeDialog.selectedSeason === index
                                ? Theme.accent : seasonTabHov ? Theme.surfaceHover : Theme.surface
                            border.color: episodeDialog.selectedSeason === index
                                ? Theme.accent : Theme.surfaceBorder
                            border.width: 1
                            property bool seasonTabHov: false

                            Text {
                                id: seasonLabel
                                anchors.centerIn: parent
                                text: "S" + modelData.season
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: episodeDialog.selectedSeason === index
                                color: episodeDialog.selectedSeason === index
                                    ? "#FFFFFF" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.seasonTabHov = true
                                onExited: parent.seasonTabHov = false
                                onClicked: episodeDialog.selectedSeason = index
                            }
                        }
                    }
                }

                ListView {
                    id: episodeList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    focus: true
                    keyNavigationEnabled: true
                    highlight: Rectangle { color: Theme.accent + "20"; radius: Theme.borderRadiusSmall }
                    highlightFollowsCurrentItem: true
                    model: episodeDialog.seasonsData.length > 0
                        ? episodeDialog.seasonsData[episodeDialog.selectedSeason].episodes
                        : []

                    Keys.onReturnPressed: playEpisode(currentIndex)
                    Keys.onEnterPressed: playEpisode(currentIndex)
                    Keys.onEscapePressed: episodeDialog.visible = false
                    Keys.onLeftPressed: {
                        if (episodeDialog.selectedSeason > 0) episodeDialog.selectedSeason--
                    }
                    Keys.onRightPressed: {
                        if (episodeDialog.selectedSeason < episodeDialog.seasonsData.length - 1) episodeDialog.selectedSeason++
                    }

                    function playEpisode(idx) {
                        if (idx < 0 || !appViewModel) return
                        var ep = episodeDialog.seasonsData[episodeDialog.selectedSeason].episodes[idx]
                        var seasonNum = episodeDialog.seasonsData[episodeDialog.selectedSeason].season
                        var displayTitle = episodeDialog.seriesTitle + " - S" + seasonNum + "E" + (ep.episodeNum || (idx + 1))
                        if (ep.title) displayTitle += " - " + ep.title
                        appViewModel.playSeriesEpisode(ep.id, ep.ext, displayTitle, ep.logoUrl)
                        episodeDialog.visible = false
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        width: episodeList.width
                        height: 44
                        radius: Theme.borderRadiusSmall
                        color: epHov ? Theme.surfaceHover : "transparent"
                        property bool epHov: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingMd
                            anchors.rightMargin: Theme.spacingMd
                            spacing: Theme.spacingSm

                            Text {
                                text: "E" + (modelData.episodeNum || (index + 1))
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: Theme.accent
                                Layout.preferredWidth: 36
                            }

                            Text {
                                text: modelData.title || ("Episode " + (index + 1))
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "▶"
                                font.pixelSize: 14
                                color: Theme.textMuted
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.epHov = true
                            onExited: parent.epHov = false
                            onClicked: {
                                if (appViewModel) {
                                    var seasonNum = episodeDialog.seasonsData[episodeDialog.selectedSeason].season
                                    var displayTitle = episodeDialog.seriesTitle + " - S" + seasonNum + "E" + (modelData.episodeNum || (index + 1))
                                    if (modelData.title) displayTitle += " - " + modelData.title
                                    appViewModel.playSeriesEpisode(modelData.id, modelData.ext, displayTitle, modelData.logoUrl)
                                    episodeDialog.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: syncBanner
        visible: appViewModel && appViewModel.serverList.syncing
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        width: syncRow.implicitWidth + 32
        height: 40
        radius: 20
        color: Theme.surfaceElevated
        border.color: Theme.accent
        border.width: 1
        z: 100

        Row {
            id: syncRow
            anchors.centerIn: parent
            spacing: 8

            BusyIndicator {
                width: 20
                height: 20
                running: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: appViewModel ? appViewModel.serverList.syncStatus : ""
                font.pixelSize: Theme.fontSizeSm
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    function selectServer(serverId) {
        activeServerId = serverId
        reloadVod()
    }

    function reloadVod() {
        if (!appViewModel) return
        appViewModel.channelList.typeFilter = activeType
        appViewModel.channelList.serverId = activeServerId
        appViewModel.channelList.refresh()
    }

    Component.onCompleted: {
        vodGrid.forceActiveFocus()
        if (appViewModel) {
            appViewModel.channelList.searchQuery = ""
            appViewModel.channelList.categoryId = 0
        }
        if (appViewModel && appViewModel.serverList.count > 0) {
            selectServer(appViewModel.serverList.serverIdAt(0))
        }
    }

    Component.onDestruction: {
        if (appViewModel) {
            appViewModel.channelList.typeFilter = ""
        }
    }
}
