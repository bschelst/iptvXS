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

            // --- Netflix-style category rows ---
            ListModel {
                id: vodCategoryModel
                // Each element: { catId: int, catName: string }
            }

            Flickable {
                id: netflixFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: netflixColumn.implicitHeight
                visible: vodSearch.text.length === 0
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                onContentYChanged: {
                    if (contentY + height > contentHeight - 400) {
                        loadMoreVodRows()
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
                        id: categoryRepeater
                        model: vodCategoryModel

                        delegate: Column {
                            id: categoryDelegate
                            width: netflixColumn.width
                            spacing: Theme.spacingSm
                            visible: rowModel.count > 0

                            property int catIdValue: model.catId
                            property string catNameValue: model.catName

                            ListModel {
                                id: rowModel
                            }

                            Component.onCompleted: {
                                if (!appViewModel) return
                                var items = appViewModel.channelList.channelsForCategory(catIdValue, 30)
                                for (var i = 0; i < items.length; i++) {
                                    rowModel.append(items[i])
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

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingSm
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28; height: 28; radius: 14
                                    color: vodScrollHov ? Theme.surfaceHover : "transparent"
                                    property bool vodScrollHov: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u203A"
                                        font.pixelSize: 22; font.bold: true
                                        color: parent.vodScrollHov ? Theme.textPrimary : Theme.textMuted
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.vodScrollHov = true; onExited: parent.vodScrollHov = false
                                        onClicked: rowListView.contentX = Math.min(rowListView.contentX + 600, rowListView.contentWidth - rowListView.width)
                                    }
                                }
                            }

                            // Horizontal poster row
                            ListView {
                                id: rowListView
                                width: parent.width
                                height: 170
                                orientation: ListView.Horizontal
                                spacing: Theme.spacingSm
                                clip: true
                                leftMargin: Theme.spacingMd
                                rightMargin: Theme.spacingMd
                                boundsBehavior: Flickable.StopAtBounds
                                model: rowModel

                                delegate: Item {
                                    width: 200
                                    height: 170

                                    Rectangle {
                                        id: posterCard
                                        anchors.fill: parent
                                        radius: 10
                                        color: Theme.surfaceElevated
                                        clip: true
                                        border.color: posterHov ? Theme.accent : "transparent"
                                        border.width: posterHov ? 2 : 0

                                        scale: posterHov ? 1.04 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                        property bool posterHov: false

                                        // Poster image
                                        Image {
                                            id: posterImg
                                            anchors.fill: parent
                                            source: model.logoUrl && model.logoUrl.indexOf("http") === 0 ? model.logoUrl : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                            cache: true
                                        }

                                        // Fallback: app logo for failed/missing images
                                        Image {
                                            anchors.centerIn: parent
                                            width: 48; height: 48
                                            source: "qrc:/images/iptvxs_tray.png"
                                            fillMode: Image.PreserveAspectFit
                                            opacity: 0.3
                                            visible: posterImg.status === Image.Error || posterImg.status === Image.Null
                                        }

                                        // Fallback: initial letter only when no URL at all
                                        Text {
                                            anchors.centerIn: parent
                                            text: {
                                                if (!model.name) return "?"
                                                var clean = model.name.replace(/^\[.*?\]\s*/, "")
                                                return clean.length > 0 ? clean.charAt(0).toUpperCase() : model.name.charAt(0)
                                            }
                                            font.pixelSize: 48
                                            font.bold: true
                                            color: Theme.accent
                                            opacity: 0.5
                                            visible: !model.logoUrl || model.logoUrl.indexOf("http") !== 0
                                        }

                                        // Dark gradient overlay at bottom
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 60
                                            radius: 10

                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 0.4; color: "#90000000" }
                                                GradientStop { position: 1.0; color: "#DD000000" }
                                            }

                                            // Fix top corners showing rounded
                                            Rectangle {
                                                anchors.top: parent.top
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                height: parent.radius
                                                color: "transparent"
                                            }
                                        }

                                        // Title text
                                        Text {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 30
                                            anchors.bottomMargin: 8
                                            text: model.name
                                            font.pixelSize: Theme.fontSizeSm
                                            font.bold: true
                                            color: "#FFFFFF"
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
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

                                        // Click area for play / series picker
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.rightMargin: 30
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: posterCard.posterHov = true
                                            onExited: posterCard.posterHov = false
                                            onClicked: {
                                                if (!appViewModel) return
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
                            }
                        }
                    }

                    // Empty state
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: vodCategoryModel.count === 0 && activeServerId > 0
                        topPadding: 80
                        text: "No VOD content found.\nSync the server first."
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: activeServerId === 0
                        topPadding: 80
                        text: "Select a server to browse VOD content."
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.textMuted
                    }
                }
            }

            // --- Search results grid (shown when search is active) ---
            GridView {
                id: vodGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: vodSearch.text.length > 0
                property int cols: appViewModel ? appViewModel.gridColumns : 2
                cellWidth: Math.floor(width / cols)
                cellHeight: 72
                clip: true
                focus: visible
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

                delegate: Item {
                    width: vodGrid.cellWidth - Theme.spacingSm
                    height: vodGrid.cellHeight - Theme.spacingSm

                    Rectangle {
                        id: searchCard
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.borderRadiusLarge
                        color: searchItemHov ? Theme.surfaceHover : Theme.surfaceElevated
                        border.color: searchItemHov ? Theme.accent + "60" : "transparent"
                        border.width: searchItemHov ? 2 : 1

                        scale: searchItemHov ? 1.02 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        property bool searchItemHov: false

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
                                    text: "\uD83C\uDFAC"
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

                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: searchFavHov ? Theme.surfaceHover : "transparent"
                                property bool searchFavHov: false
                                property bool isFav: appViewModel ? appViewModel.favoriteList.isFavorite(model.channelId) : false

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.isFav ? "\u2764" : "\u2661"
                                    font.pixelSize: 14
                                    color: parent.isFav ? Theme.error : Theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.searchFavHov = true
                                    onExited: parent.searchFavHov = false
                                    onClicked: {
                                        if (appViewModel) {
                                            appViewModel.favoriteList.toggleFavorite(model.channelId)
                                            parent.isFav = !parent.isFav
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 36
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: searchCard.searchItemHov = true
                            onExited: searchCard.searchItemHov = false
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
                }

                onAtYEndChanged: {
                    if (atYEnd && appViewModel) {
                        appViewModel.channelList.loadMore()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: vodGrid.count === 0
                    text: "No results found."
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
                        var episodes = episodeDialog.seasonsData[episodeDialog.selectedSeason].episodes
                        var ep = episodes[idx]
                        var seasonNum = episodeDialog.seasonsData[episodeDialog.selectedSeason].season
                        var displayTitle = episodeDialog.seriesTitle + " - S" + seasonNum + "E" + (ep.episodeNum || (idx + 1))
                        if (ep.title) displayTitle += " - " + ep.title
                        appViewModel.playSeriesEpisode(ep.id, ep.ext, displayTitle, ep.logoUrl)

                        // Set up auto-next episode
                        if (idx + 1 < episodes.length) {
                            var nextEp = episodes[idx + 1]
                            var nextNum = nextEp.episodeNum || (idx + 2)
                            var nextTitle = episodeDialog.seriesTitle + " - S" + seasonNum + "E" + nextNum
                            if (nextEp.title) nextTitle += " - " + nextEp.title
                            var nextUrl = vodView.buildEpisodeUrl(nextEp.id, nextEp.ext)
                            appViewModel.player.setNextEpisode(nextUrl, nextTitle, nextEp.logoUrl || "", 0)
                        }

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
                                text: {
                                    var t = modelData.title || ("Episode " + (index + 1))
                                    var series = episodeDialog.seriesTitle
                                    if (series && t.indexOf(series) === 0) {
                                        t = t.substring(series.length).replace(/^\s*-\s*/, "")
                                    }
                                    t = t.replace(/^S\d+E\d+\s*-?\s*/i, "")
                                    return t || ("Episode " + (index + 1))
                                }
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Watched indicator
                            Text {
                                visible: {
                                    if (!appViewModel) return false
                                    // Build the episode URL to check history
                                    var url = vodView.buildEpisodeUrl(modelData.id, modelData.ext)
                                    return appViewModel.hasWatchedUrl(url)
                                }
                                text: "\u2713"
                                font.pixelSize: 14
                                font.bold: true
                                color: Theme.success
                            }

                            Text {
                                text: "\u25B6"
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

                                    // Set up auto-next episode
                                    var episodes = episodeDialog.seasonsData[episodeDialog.selectedSeason].episodes
                                    if (index + 1 < episodes.length) {
                                        var nextEp = episodes[index + 1]
                                        var nextNum = nextEp.episodeNum || (index + 2)
                                        var nextTitle = episodeDialog.seriesTitle + " - S" + seasonNum + "E" + nextNum
                                        if (nextEp.title) nextTitle += " - " + nextEp.title
                                        var nextUrl = vodView.buildEpisodeUrl(nextEp.id, nextEp.ext)
                                        appViewModel.player.setNextEpisode(nextUrl, nextTitle, nextEp.logoUrl || "", 0)
                                    }

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

    function buildEpisodeUrl(episodeId, ext) {
        if (!appViewModel) return ""
        return appViewModel.buildSeriesEpisodeUrl(episodeId, ext)
    }

    property int vodRowsLoaded: 0
    property int vodRowsBatchSize: 8

    function reloadVodRows() {
        vodCategoryModel.clear()
        vodRowsLoaded = 0
        loadMoreVodRows()
    }

    function loadMoreVodRows() {
        if (!appViewModel) return
        var catList = appViewModel.categoryList
        if (!catList) return
        var end = Math.min(vodRowsLoaded + vodRowsBatchSize, catList.count)
        for (var i = vodRowsLoaded; i < end; i++) {
            var catId = catList.categoryIdAt(i)
            // Skip hidden categories
            if (catList.isCategoryHidden(catId)) continue
            vodCategoryModel.append({
                catId: catId,
                catName: catList.categoryNameAt(i)
            })
        }
        vodRowsLoaded = end
    }

    function reloadVod() {
        if (!appViewModel) return
        appViewModel.channelList.typeFilter = activeType
        appViewModel.channelList.serverId = activeServerId
        appViewModel.channelList.refresh()
        // Force category reload — shared categoryList may already have same serverId
        // from ChannelsView but with different filterType, causing no reload
        appViewModel.categoryList.filterType = activeType
        appViewModel.categoryList.serverId = activeServerId
        appViewModel.categoryList.refresh()
    }

    Connections {
        target: appViewModel ? appViewModel.categoryList : null
        function onCountChanged() {
            reloadVodRows()
        }
    }

    Component.onCompleted: {
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
