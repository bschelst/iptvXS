// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: historyView

    function focusPrimary() {
        if (historyList.count > 0) {
            if (historyList.currentIndex < 0) historyList.currentIndex = 0
            historyList.forceActiveFocus()
        }
    }

    function focusClearHistoryButton() {
        if (clearHistoryBtn && clearHistoryBtn.visible) {
            clearHistoryBtn.forceActiveFocus()
        } else if (historyList) {
            historyList.forceActiveFocus()
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
                        var c = appViewModel ? appViewModel.history.count : 0
                        return c + (c === 1 ? " entry" : " entries")
                    }
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: clearHistoryBtn
                    Layout.preferredWidth: clearBtnText.implicitWidth + Theme.spacingLg
                    Layout.preferredHeight: 32
                    radius: 16
                    color: clearBtnHov || clearHistoryBtn.activeFocus ? Theme.error : Theme.surfaceHover
                    visible: appViewModel && appViewModel.history.count > 0
                    focus: false
                    activeFocusOnTab: true

                    property bool clearBtnHov: false

                    Text {
                        id: clearBtnText
                        anchors.centerIn: parent
                        text: "Clear History"
                        font.pixelSize: Theme.fontSizeXs
                        color: clearBtnHov ? Theme.textOnAccent : Theme.textSecondary

                        property bool clearBtnHov: parent.clearBtnHov
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.clearBtnHov = true
                        onExited: parent.clearBtnHov = false
                        onClicked: {
                            if (appViewModel) appViewModel.history.clearHistory()
                        }
                    }

                    Keys.onLeftPressed: {
                        if (historyList) historyList.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (historyList) {
                            if (historyList.currentIndex < 0 && historyList.count > 0) {
                                historyList.currentIndex = 0
                            }
                            historyList.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: {
                        if (appViewModel) appViewModel.history.clearHistory()
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            if (appViewModel) appViewModel.history.clearHistory()
                            event.accepted = true
                        } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                            if (historyList) historyList.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appViewModel ? appViewModel.history : null
            focus: true
            keyNavigationEnabled: true
            highlight: Rectangle { color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13); radius: Theme.borderRadiusSmall }
            highlightFollowsCurrentItem: true

            function focusDeleteForCurrentItem() {
                if (currentIndex < 0) return false
                positionViewAtIndex(currentIndex, ListView.Contain)
                Qt.callLater(function() {
                    if (currentIndex < 0) return
                    if (historyList.currentItem && historyList.currentItem.deleteBtn) {
                        historyList.currentItem.deleteBtn.forceActiveFocus()
                    } else {
                        var fallbackItem = itemAtIndex(currentIndex)
                        if (fallbackItem && fallbackItem.deleteBtn) {
                            fallbackItem.deleteBtn.forceActiveFocus()
                        }
                    }
                })
                return true
            }

            Keys.onUpPressed: {
                if (currentIndex > 0) {
                    currentIndex--
                } else {
                    historyView.focusClearHistoryButton()
                }
            }
            Keys.onDownPressed: { if (currentIndex < count - 1) currentIndex++ }
            Keys.onLeftPressed: {
                if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
            }
            Keys.onRightPressed: {
                focusDeleteForCurrentItem()
            }
            Keys.onReturnPressed: playCurrentItem()
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                    playCurrentItem()
                    event.accepted = true
                }
            }

            function playCurrentItem() {
                if (currentIndex < 0 || !appViewModel) return
                var idx = appViewModel.history.index(currentIndex, 0)
                var channelId = appViewModel.history.data(idx, 258)  // ChannelIdRole
                var streamUrl = appViewModel.history.data(idx, 264)  // StreamUrlRole
                var name = appViewModel.history.data(idx, 259)       // ChannelNameRole
                var logo = appViewModel.history.data(idx, 260)       // ChannelLogoRole
                if (channelId > 0) {
                    appViewModel.playChannelById(channelId)
                } else if (streamUrl) {
                    appViewModel.player.play(streamUrl, name, logo, 0)
                    appViewModel.currentView = "player"
                }
            }

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            section.property: "channelType"
            section.delegate: Rectangle {
                required property string section
                width: historyList.width
                height: 32
                color: Theme.surface

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingMd
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.section === "live" ? "Live TV"
                        : parent.section === "vod" ? "Movies"
                        : parent.section === "series" ? "Series"
                        : "Other"
                    font.pixelSize: Theme.fontSizeXs
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    color: Theme.accent
                    font.letterSpacing: 1
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.accent
                    opacity: 0.3
                }
            }

            delegate: Rectangle {
                width: historyList.width
                height: 64
                color: "transparent"
                border.width: historyList.activeFocus && historyList.currentIndex === index ? 2 : 0
                border.color: historyList.activeFocus && historyList.currentIndex === index
                    ? Theme.accent : "transparent"
                property bool histHov: false

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMd
                    anchors.rightMargin: Theme.spacingMd
                    spacing: Theme.spacingSm

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: Theme.borderRadiusSmall
                        color: Theme.surface
                        clip: true

                        Image {
                            id: histLogo
                            anchors.fill: parent
                            source: model.channelLogo && model.channelLogo.indexOf("http") === 0
                                ? model.channelLogo : ""
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            source: "qrc:/images/iptvxs_tray.png"
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.4
                            visible: !histLogo.visible
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: model.channelName || "Unknown"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: Theme.spacingSm

                            Text {
                                text: model.watchedAt || ""
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }

                            Text {
                                visible: model.channelType !== ""
                                text: model.channelType === "live" ? "Live" : model.channelType === "vod" ? "Movie" : "Series"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.accent
                            }

                            Text {
                                visible: model.duration !== ""
                                text: model.duration
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }
                    }

                    property bool isFocused: historyList.activeFocus && historyList.currentIndex === index

                    FocusScope {
                        id: deleteBtn
                        width: deleteLabel.implicitWidth + 38
                        height: 28
                        focus: false
                        activeFocusOnTab: true
                        property bool delHistHov: false
                        property bool selected: deleteBtn.activeFocus || (historyList.activeFocus && historyList.currentIndex === index)

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: deleteBtn.delHistHov || deleteBtn.selected ? Theme.error : "transparent"
                            border.width: 1
                            border.color: deleteBtn.delHistHov || deleteBtn.selected ? Theme.textOnAccent : Theme.surfaceBorder
                            opacity: histHov || deleteBtn.delHistHov || deleteBtn.selected ? 1.0 : 0.0
                            visible: opacity > 0.0
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\u232B"
                                font.pixelSize: 15
                                font.bold: true
                                font.family: "DejaVu Sans"
                                color: deleteBtn.delHistHov || deleteBtn.selected ? "#ffffff" : Theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: deleteLabel
                                text: "Remove"
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: true
                                font.family: "DejaVu Sans"
                                color: deleteBtn.delHistHov || deleteBtn.selected ? "#ffffff" : Theme.textMuted
                                anchors.verticalCenter: parent.verticalCenter
                                visible: deleteBtn.delHistHov || deleteBtn.selected
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.delHistHov = true
                            onExited: parent.delHistHov = false
                            onClicked: {
                                if (appViewModel) appViewModel.history.removeEntry(model.historyId)
                            }
                        }

                        onActiveFocusChanged: delHistHov = activeFocus

                        Keys.onUpPressed: {
                            if (historyList && historyList.currentIndex === index) {
                                historyView.focusClearHistoryButton()
                            }
                        }
                        Keys.onDownPressed: {
                            if (historyList) {
                                historyList.forceActiveFocus()
                            }
                        }

                        Keys.onLeftPressed: {
                            historyList.forceActiveFocus()
                        }
                        Keys.onReturnPressed: {
                            if (appViewModel) appViewModel.history.removeEntry(model.historyId)
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                Keys.onReturnPressed(event)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                historyList.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.histHov = true
                    onExited: parent.histHov = false
                    onClicked: {
                        if (!appViewModel) return
                        if (model.channelId > 0) {
                            appViewModel.playChannelById(model.channelId)
                        } else if (model.streamUrl) {
                            appViewModel.player.play(model.streamUrl, model.channelName, model.channelLogo, 0)
                            appViewModel.currentView = "player"
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.surfaceBorder
                    opacity: 0.3
                }
            }

            onAtYEndChanged: {
                if (atYEnd && appViewModel) {
                    appViewModel.history.loadMore()
                }
            }

            Text {
                anchors.centerIn: parent
                visible: historyList.count === 0
                text: "No play history yet.\nChannels you watch will appear here."
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }
    }

    Component.onCompleted: {
        if (appViewModel) appViewModel.history.refresh()
    }
}
