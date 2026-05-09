// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: favoritesView

    function focusPrimary() {
        if (favoritesList.count > 0) {
            if (favoritesList.currentIndex < 0 || favoritesList.currentIndex >= favoritesList.count) {
                favoritesList.currentIndex = 0
            }
            favoritesList.forceActiveFocus()
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

        ListView {
            id: favoritesList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appViewModel ? appViewModel.favoriteList : null
            spacing: Theme.spacingXs
            keyNavigationEnabled: true
            highlightFollowsCurrentItem: true
            currentIndex: -1

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

            Keys.onUpPressed: { if (currentIndex > 0) currentIndex-- }
            Keys.onDownPressed: { if (currentIndex < count - 1) currentIndex++ }
            Keys.onLeftPressed: {
                if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
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

            delegate: Rectangle {
                width: favoritesList.width - Theme.spacingMd * 2
                height: 64
                x: Theme.spacingMd
                radius: Theme.borderRadius
                color: favHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.color: {
                    if (favoritesList.activeFocus && favoritesList.currentIndex === index) return Theme.accent
                    if (favHovered) return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                    return "transparent"
                }
                border.width: (favoritesList.activeFocus && favoritesList.currentIndex === index) ? 2 : 1

                property bool favHovered: false
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

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    spacing: Theme.spacingMd

                    Text {
                        text: (index + 1).toString()
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        color: Theme.textMuted
                        Layout.preferredWidth: 28
                        horizontalAlignment: Text.AlignHCenter
                    }

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

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 16
                        color: removeHovered ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.19) : "transparent"

                        property bool removeHovered: false

                        Text {
                            anchors.centerIn: parent
                            text: "\u232B"
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            font.family: "DejaVu Sans"
                            color: parent.removeHovered ? "#ffffff" : Theme.textMuted
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
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.favHovered = true
                    onExited: parent.favHovered = false
                    onClicked: {
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

                    z: -1
                }
            }

            Text {
                anchors.centerIn: parent
                visible: favoritesList.count === 0
                text: "No favorites yet.\nClick the star on any channel to add it here."
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }
    }

    property bool favReturnPending: false

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
        anchors.fill: parent
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

            function closeDialog() {
            visible = false
            Qt.callLater(function() {
                if (favoritesList && favoritesList.count > 0) {
                    if (favoritesList.currentIndex < 0 || favoritesList.currentIndex >= favoritesList.count) {
                        favoritesList.currentIndex = 0
                    }
                    favoritesList.forceActiveFocus()
                } else if (favoritesView && favoritesView.focusPrimary) {
                    favoritesView.focusPrimary()
                }
            })
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

        MouseArea { anchors.fill: parent; onClicked: favEpDialog.closeDialog() }

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
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.favCloseHov = true; onExited: parent.favCloseHov = false; onClicked: favEpDialog.closeDialog() }
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
                    Keys.onEscapePressed: favEpDialog.closeDialog()
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
                            favEpDialog.closeDialog()
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
                            favEpDialog.closeDialog()
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

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u25B6"
                                font.pixelSize: 12
                                color: Theme.accent
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
                                    favEpDialog.closeDialog()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
