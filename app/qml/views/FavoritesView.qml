// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: favoritesView

    function focusPrimary() {
        if (favoritesGrid.count > 0) {
            if (favoritesGrid.currentIndex < 0 || favoritesGrid.currentIndex >= favoritesGrid.count) {
                favoritesGrid.currentIndex = 0
            }
            favoritesGrid.forceActiveFocus()
        } else if (Window.window && Window.window.focusSidebar) {
            Window.window.focusSidebar()
        }
    }

    ColumnLayout {
        anchors.fill: parent
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
                        var c = appViewModel ? appViewModel.favoriteList.count : 0
                        return c + (c === 1 ? " favorite" : " favorites")
                    }
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                }

                Item { Layout.fillWidth: true }
            }
        }

        GridView {
            id: favoritesGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appViewModel ? appViewModel.favoriteList : null
            cellWidth: 158
            cellHeight: 232
            leftMargin: Theme.spacingMd
            rightMargin: Theme.spacingMd
            topMargin: Theme.spacingSm
            keyNavigationEnabled: true
            highlightFollowsCurrentItem: true
            currentIndex: -1

            property int cols: Math.max(1, Math.floor((width - leftMargin - rightMargin) / cellWidth))

            onCountChanged: {
                if (count <= 0) {
                    currentIndex = -1
                } else if (currentIndex < 0 || currentIndex >= count) {
                    currentIndex = 0
                }
            }

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            Keys.onUpPressed: {
                if (currentIndex >= cols) {
                    currentIndex -= cols
                } else if (currentIndex >= 0 && Window.window && Window.window.focusSidebar) {
                    Window.window.focusSidebar()
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
                    event.accepted = true
                }
            }
            Keys.onRightPressed: {
                // Standard grid nav: advance to the next card in the row.
                // Press X (Qt.Key_Space) to toggle the favorite off — see
                // the delegate's Keys.onPressed handler. The remove button
                // is no longer reachable via D-pad Right to keep nav
                // intuitive.
                if (currentIndex + 1 < count
                        && (currentIndex + 1) % cols !== 0) {
                    currentIndex++
                    event.accepted = true
                }
            }
            Keys.onReturnPressed: activateCurrentItem()
            Keys.onEnterPressed: activateCurrentItem()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
                    if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                    event.accepted = true
                } else if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    activateCurrentItem()
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_X) {
                    if (currentIndex >= 0 && currentItem && appViewModel) {
                        appViewModel.favoriteList.toggleFavorite(currentItem.itemChannelId)
                    }
                    event.accepted = true
                }
            }

            function activateCurrentItem() {
                if (currentIndex < 0 || !currentItem || !appViewModel) return
                currentItem.activate()
            }

            delegate: Item {
                width: favoritesGrid.cellWidth
                height: favoritesGrid.cellHeight
                focus: favoritesGrid.activeFocus && favoritesGrid.currentIndex === index
                activeFocusOnTab: true

                property int itemChannelId: model.channelId || 0

                function activate() {
                    if (!appViewModel) return
                    if (model.type === "series") {
                        favEpDialog.seriesChannelId = model.channelId
                        appViewModel.fetchSeriesEpisodes(model.serverId, model.externalId, model.name, model.logoUrl)
                    } else {
                        if (model.type === "live") {
                            appViewModel.setZapContext(appViewModel.favoriteList.favoritesAsList(), model.channelId, "Favorites")
                        } else {
                            appViewModel.clearZapContext()
                        }
                        appViewModel.player.play(model.streamUrl, model.name, model.logoUrl, model.channelId, "", 0, true, true)
                        appViewModel.currentView = "player"
                    }
                }

                Rectangle {
                    id: favCard
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 10
                    color: Theme.surfaceElevated
                    border.width: favoritesGrid.activeFocus && favoritesGrid.currentIndex === index ? 2 : 1
                    border.color: favoritesGrid.activeFocus && favoritesGrid.currentIndex === index
                        ? Theme.accent
                        : Theme.surfaceBorder
                    clip: true
                    property bool cardHovered: false

                    Rectangle {
                        id: favLogoArea
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height - 52
                        color: "transparent"

                        Image {
                            id: favPoster
                            anchors.centerIn: parent
                            width: parent.width - 24
                            height: parent.height - 16
                            source: model.logoUrl || ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                    }

                    Image {
                        visible: !favPoster.visible
                        anchors.centerIn: favCard
                        width: Math.min(favCard.width, favCard.height) - 48
                        height: width
                        source: "qrc:/images/iptvxs_tray.png"
                        fillMode: Image.PreserveAspectFit
                        asynchronous: false
                        cache: true
                        opacity: 0.15
                    }

                    Rectangle {
                        anchors.top: favLogoArea.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        color: "transparent"

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

                    MouseArea {
                        anchors.fill: parent
                        z: 120
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: favCard.cardHovered = true
                        onExited: favCard.cardHovered = false
                        onPressed: activate()
                        onClicked: activate()
                    }

                    Rectangle {
                        visible: favCard.cardHovered && !favoritesGrid.activeFocus
                        anchors.fill: parent
                        radius: favCard.radius
                        color: Qt.rgba(Theme.surfaceHover.r, Theme.surfaceHover.g, Theme.surfaceHover.b, 0.0)
                        border.color: Theme.surfaceHover
                        border.width: 1
                        z: 101
                    }

                    Rectangle {
                        visible: (model.tvArchive || 0) > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: 26
                        height: 26
                        radius: 13
                        color: "#C0000000"

                        Text {
                            anchors.centerIn: parent
                            text: "\u21BB"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "DejaVu Sans"
                            color: "#ffffff"
                        }
                    }

                    Rectangle {
                        id: favRemoveBtn
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8
                        width: 28
                        height: 28
                        radius: 14
                        z: 130
                        color: removeHovered || activeFocus ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22) : "#26000000"
                        border.width: activeFocus ? 2 : 1
                        border.color: activeFocus ? Theme.error : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.50)
                        focus: false
                        activeFocusOnTab: true

                        property bool removeHovered: false

                        Text {
                            anchors.centerIn: parent
                            text: "\u232B"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            font.family: "DejaVu Sans"
                            color: parent.removeHovered || parent.activeFocus ? "#ffffff" : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.removeHovered = true
                            onExited: parent.removeHovered = false
                            onClicked: {
                                if (appViewModel) {
                                    appViewModel.favoriteList.toggleFavorite(model.channelId)
                                }
                            }
                        }

                        Keys.onLeftPressed: {
                            if (favoritesGrid) favoritesGrid.forceActiveFocus()
                        }
                        Keys.onUpPressed: {
                            if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
                        }
                        Keys.onReturnPressed: {
                            if (appViewModel) {
                                appViewModel.favoriteList.toggleFavorite(model.channelId)
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                                    || event.key === Qt.Key_Delete || event.key === Qt.Key_X) {
                                if (appViewModel) {
                                    appViewModel.favoriteList.toggleFavorite(model.channelId)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Left) {
                                if (favoritesGrid) favoritesGrid.forceActiveFocus()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                if (Window.window && Window.window.focusSidebar) {
                                    Window.window.focusSidebar()
                                }
                                event.accepted = true
                            }
                        }
                    }

                    Keys.onReturnPressed: activate()
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    // Right used to focus the remove button on the same
                    // card, but that broke standard grid navigation. The
                    // GridView's own Keys.onRightPressed now advances to
                    // the next card; remove-via-X is unchanged via
                    // delegate's Keys.onPressed below.
                    Keys.onUpPressed: {
                        if (index >= favoritesGrid.cols) {
                            favoritesGrid.currentIndex = index - favoritesGrid.cols
                        } else if (Window.window && Window.window.focusSidebar) {
                            Window.window.focusSidebar()
                        }
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            activate()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_X) {
                            if (appViewModel) {
                                appViewModel.favoriteList.toggleFavorite(model.channelId)
                            }
                            event.accepted = true
                        }
                    }
                }

            }

            Text {
                anchors.centerIn: parent
                visible: favoritesGrid.count === 0
                text: "No favorites yet.\nClick the star on any channel to add it here."
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }

    property bool favReturnPending: false

    function closeFavEpisodesDialog() {
        if (!favEpDialog) return
        favEpDialog.visible = false
        Qt.callLater(function() {
            if (favoritesGrid && favoritesGrid.count > 0) {
                if (favoritesGrid.currentIndex < 0 || favoritesGrid.currentIndex >= favoritesGrid.count) {
                    favoritesGrid.currentIndex = 0
                }
                favoritesGrid.forceActiveFocus()
            } else if (favoritesView && favoritesView.focusPrimary) {
                favoritesView.focusPrimary()
            }
        })
    }

    Connections {
        target: appViewModel
        function onSeriesEpisodesReady(seriesName, seasons) {
            favEpDialog.seriesTitle = seriesName
            favEpDialog.seasonsData = seasons
            favEpDialog.selectedSeason = 0
            favEpDialog.visible = true
        }
    }

        Rectangle {
            id: favEpDialog
            visible: false
            width: parent.width
            height: parent.height
            color: "#C0000000"
            z: 200

        property string seriesTitle: ""
        property var seasonsData: []
        property int selectedSeason: 0
        property int seriesChannelId: 0

        function focusSeasonTab(index) {
            if (!seasonsRepeater || seasonsRepeater.count <= 0) return
            index = Math.max(0, Math.min(seasonsRepeater.count - 1, index))
            var item = seasonsRepeater.itemAt(index)
            if (item && item.forceActiveFocus) item.forceActiveFocus()
        }

        onVisibleChanged: {
            if (visible) {
                favEpList.currentIndex = 0
                favEpList.forceActiveFocus()
            }
        }

        onSelectedSeasonChanged: {
            if (favEpList.count > 0) {
                favEpList.currentIndex = 0
            } else {
                favEpList.currentIndex = -1
            }
        }

        MouseArea { anchors.fill: parent; onClicked: closeFavEpisodesDialog() }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 600)
            height: Math.min(parent.height - 80, 500)
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.surfaceBorder; border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: favEpDialog.seriesTitle
                        font.pixelSize: Theme.fontSizeLg; font.bold: true
                        color: Theme.textPrimary; elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: favCloseHov ? Theme.surfaceHover : "transparent"
                        property bool favCloseHov: false
                        Text { anchors.centerIn: parent; text: "\u2715"; font.pixelSize: 16; font.bold: true; color: Theme.textSecondary }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.favCloseHov = true; onExited: parent.favCloseHov = false; onClicked: closeFavEpisodesDialog() }
                    }
                }

                Row {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        id: seasonsRepeater
                        model: favEpDialog.seasonsData
                        Rectangle {
                            width: favSeasonLbl.implicitWidth + 20; height: 28; radius: 14
                            color: favEpDialog.selectedSeason === index ? Theme.accent : "transparent"
                            border.color: favEpDialog.selectedSeason === index ? Theme.accent : Theme.surfaceBorder; border.width: 1
                            focus: false
                            activeFocusOnTab: true
                            Text { id: favSeasonLbl; anchors.centerIn: parent; text: modelData.name || ("Season " + (index + 1)); font.pixelSize: Theme.fontSizeXs; font.bold: favEpDialog.selectedSeason === index; color: favEpDialog.selectedSeason === index ? Theme.textOnAccent : Theme.textSecondary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { favEpDialog.selectedSeason = index; favEpDialog.focusSeasonTab(index) } }

                            Keys.onLeftPressed: favEpDialog.focusSeasonTab(index - 1)
                            Keys.onRightPressed: favEpDialog.focusSeasonTab(index + 1)
                            Keys.onDownPressed: {
                                if (favEpList.count > 0) favEpList.forceActiveFocus()
                            }
                            Keys.onReturnPressed: favEpDialog.selectedSeason = index
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    favEpDialog.selectedSeason = index
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }

                ListView {
                    id: favEpList
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                    model: favEpDialog.seasonsData.length > 0 ? favEpDialog.seasonsData[favEpDialog.selectedSeason].episodes : []
                    onCountChanged: {
                        if (count <= 0) {
                            currentIndex = -1
                        } else if (currentIndex < 0 || currentIndex >= count) {
                            currentIndex = 0
                        }
                    }
                    ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }
                    keyNavigationEnabled: true
                    highlightFollowsCurrentItem: true
                    currentIndex: 0

                    Keys.onReturnPressed: playFavEpisode(currentIndex)
                    Keys.onEnterPressed: playFavEpisode(currentIndex)
                    Keys.onEscapePressed: closeFavEpisodesDialog()
                    Keys.onUpPressed: {
                        if (favEpDialog.seasonsData.length > 0) {
                            favEpDialog.focusSeasonTab(favEpDialog.selectedSeason)
                        }
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            playFavEpisode(currentIndex)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Back || event.key === Qt.Key_B) {
                            closeFavEpisodesDialog()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left) {
                            if (favEpDialog.selectedSeason > 0) {
                                favEpDialog.selectedSeason--
                                favEpDialog.focusSeasonTab(favEpDialog.selectedSeason)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right) {
                            if (favEpDialog.selectedSeason < favEpDialog.seasonsData.length - 1) {
                                favEpDialog.selectedSeason++
                                favEpDialog.focusSeasonTab(favEpDialog.selectedSeason)
                            }
                            event.accepted = true
                        }
                    }

                    function playFavEpisode(idx) {
                        if (idx < 0 || !appViewModel) return
                        var ep = favEpDialog.seasonsData[favEpDialog.selectedSeason].episodes[idx]
                        var ext = ep.containerExtension || ep.ext || "mkv"
                        var url = appViewModel.buildSeriesEpisodeUrl(ep.id, ext)
                        if (url) {
                            appViewModel.player.play(url, ep.title || favEpDialog.seriesTitle, "", favEpDialog.seriesChannelId)
                            appViewModel.currentView = "player"
                            closeFavEpisodesDialog()
                        }
                    }

                    delegate: Rectangle {
                        width: favEpList.width; height: 44; radius: Theme.borderRadiusSmall
                        color: {
                            if (favEpList.activeFocus && favEpList.currentIndex === index) return Theme.surfaceHover
                            return favEpHov ? Theme.surfaceHover : Theme.surface
                        }
                        border.width: (favEpList.activeFocus && favEpList.currentIndex === index) ? 2 : 0
                        border.color: Theme.accent
                        property bool favEpHov: false

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingMd
                            anchors.rightMargin: Theme.spacingMd
                            spacing: Theme.spacingSm

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "E" + (modelData.episodeNum || (index + 1))
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: Theme.accent
                                width: 36
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    var t = modelData.title || ("Episode " + (index + 1))
                                    // Strip series name prefix if present
                                    var series = favEpDialog.seriesTitle
                                    if (series && t.indexOf(series) === 0) {
                                        t = t.substring(series.length).replace(/^\s*-\s*/, "")
                                    }
                                    // Strip SxxExx prefix
                                    t = t.replace(/^S\d+E\d+\s*-?\s*/i, "")
                                    return t || ("Episode " + (index + 1))
                                }
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                width: parent.width - 60

                            }

                            Canvas {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12
                                height: 12
                                antialiasing: true
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.fillStyle = Theme.textPrimary
                                    ctx.beginPath()
                                    ctx.moveTo(3, 2)
                                    ctx.lineTo(10, 6)
                                    ctx.lineTo(3, 10)
                                    ctx.closePath()
                                    ctx.fill()
                                }
                                Component.onCompleted: requestPaint()
                                Connections {
                                    target: Theme
                                    function onTextPrimaryChanged() { parent.requestPaint() }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: parent.favEpHov = true; onExited: parent.favEpHov = false
                            onClicked: {
                                if (!appViewModel) return
                                var ep = favEpDialog.seasonsData[favEpDialog.selectedSeason].episodes[index]
                                var ext = ep.containerExtension || ep.ext || "mkv"
                                var url = appViewModel.buildSeriesEpisodeUrl(ep.id, ext)
                                if (url) {
                                    var title = ep.title || favEpDialog.seriesTitle
                                    appViewModel.player.play(url, title, "", favEpDialog.seriesChannelId)
                                    appViewModel.currentView = "player"
                                    closeFavEpisodesDialog()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
}
