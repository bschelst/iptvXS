// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: favoritesView

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

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: favoritesList.width - Theme.spacingMd * 2
                height: 64
                x: Theme.spacingMd
                radius: Theme.borderRadius
                color: favHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.color: favHovered ? Theme.accent + "40" : "transparent"
                border.width: 1

                property bool favHovered: false

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
                        color: removeHovered ? Theme.error + "30" : "transparent"

                        property bool removeHovered: false

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            color: parent.removeHovered ? Theme.error : Theme.textMuted
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
                        if (appViewModel) {
                            if (model.type === "series") {
                                favEpDialog.seriesChannelId = model.channelId
                                appViewModel.fetchSeriesEpisodes(model.serverId, model.externalId, model.name, model.logoUrl)
                            } else {
                                appViewModel.player.play(model.streamUrl, model.name, model.logoUrl, model.channelId)
                                appViewModel.currentView = "player"
                            }
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

        MouseArea { anchors.fill: parent; onClicked: favEpDialog.visible = false }

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
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.favCloseHov = true; onExited: parent.favCloseHov = false; onClicked: favEpDialog.visible = false }
                    }
                }

                Row {
                    Layout.fillWidth: true; spacing: 4
                    Repeater {
                        model: favEpDialog.seasonsData
                        Rectangle {
                            width: favSeasonLbl.implicitWidth + 20; height: 28; radius: 14
                            color: favEpDialog.selectedSeason === index ? Theme.accent : "transparent"
                            border.color: favEpDialog.selectedSeason === index ? Theme.accent : Theme.surfaceBorder; border.width: 1
                            Text { id: favSeasonLbl; anchors.centerIn: parent; text: modelData.name || ("Season " + (index + 1)); font.pixelSize: Theme.fontSizeXs; font.bold: favEpDialog.selectedSeason === index; color: favEpDialog.selectedSeason === index ? Theme.textOnAccent : Theme.textSecondary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: favEpDialog.selectedSeason = index }
                        }
                    }
                }

                ListView {
                    id: favEpList
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 4
                    model: favEpDialog.seasonsData.length > 0 ? favEpDialog.seasonsData[favEpDialog.selectedSeason].episodes : []
                    ScrollBar.vertical: ScrollBar { active: true; policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        width: favEpList.width; height: 44; radius: Theme.borderRadiusSmall
                        color: favEpHov ? Theme.surfaceHover : Theme.surface
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
                                    favEpDialog.visible = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
