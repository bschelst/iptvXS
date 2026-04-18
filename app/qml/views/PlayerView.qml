import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: playerView

    property string channelUrl: ""
    property string channelName: ""
    property string channelLogo: ""

    Rectangle {
        anchors.fill: parent
        color: "#000000"

        MpvVideoItem {
            id: videoSurface
            anchors.fill: parent
            player: appViewModel ? appViewModel.player.mpvPlayer : null
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: controlsTimer.restart()
            onClicked: {
                if (appViewModel) appViewModel.player.togglePause()
                controlsTimer.restart()
            }
            onDoubleClicked: toggleFullscreen()
        }

        Rectangle {
            id: controlsOverlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 120
            visible: opacity > 0
            opacity: controlsVisible ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animNormal }
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.4; color: "#80000000" }
                GradientStop { position: 1.0; color: "#cc000000" }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Slider {
                    id: seekSlider
                    Layout.fillWidth: true
                    from: 0
                    to: appViewModel ? appViewModel.player.duration : 0
                    value: appViewModel ? appViewModel.player.position : 0
                    enabled: appViewModel ? appViewModel.player.duration > 0 : false

                    onMoved: {
                        if (appViewModel) appViewModel.player.seek(value)
                    }

                    background: Rectangle {
                        x: seekSlider.leftPadding
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - 2
                        width: seekSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Theme.surfaceBorder

                        Rectangle {
                            width: seekSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }

                    handle: Rectangle {
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: seekSlider.pressed ? Theme.accentHover : Theme.accent
                        visible: seekSlider.hovered || seekSlider.pressed
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd

                    PlayerButton {
                        text: appViewModel && appViewModel.player.playing ? "⏸" : "▶"
                        onClicked: {
                            if (appViewModel) appViewModel.player.togglePause()
                        }
                    }

                    PlayerButton {
                        text: "⏹"
                        onClicked: {
                            if (appViewModel) appViewModel.player.stop()
                        }
                    }

                    Text {
                        text: {
                            if (!appViewModel) return "--:-- / --:--"
                            var pos = appViewModel.player.formatTime(appViewModel.player.position)
                            var dur = appViewModel.player.formatTime(appViewModel.player.duration)
                            return pos + " / " + dur
                        }
                        font.pixelSize: Theme.fontSizeXs
                        color: "#ffffff"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: appViewModel ? appViewModel.player.channelName.length > 0 : false
                        text: appViewModel ? appViewModel.player.channelName : ""
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: "#ffffff"
                        elide: Text.ElideRight
                        Layout.maximumWidth: 300
                    }

                    Item { Layout.fillWidth: true }

                    PlayerButton {
                        text: appViewModel && appViewModel.player.muted ? "🔇" : "🔊"
                        onClicked: {
                            if (appViewModel) appViewModel.player.toggleMute()
                        }
                    }

                    Slider {
                        id: volumeSlider
                        Layout.preferredWidth: 100
                        from: 0
                        to: 100
                        value: appViewModel ? appViewModel.player.volume : 100

                        onMoved: {
                            if (appViewModel) appViewModel.player.volume = value
                        }

                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - 2
                            width: volumeSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Theme.surfaceBorder

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: "#ffffff"
                            }
                        }

                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: 12
                            height: 12
                            radius: 6
                            color: "#ffffff"
                        }
                    }

                    PlayerButton {
                        text: "⛶"
                        font.pixelSize: Theme.fontSizeLg
                        onClicked: toggleFullscreen()
                    }
                }
            }
        }

        Rectangle {
            id: topOverlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56
            visible: controlsOverlay.visible
            opacity: controlsOverlay.opacity

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#cc000000" }
                GradientStop { position: 0.6; color: "#80000000" }
                GradientStop { position: 1.0; color: "transparent" }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd

                PlayerButton {
                    text: "←"
                    font.pixelSize: Theme.fontSizeLg
                    onClicked: goBack()
                }

                Text {
                    text: appViewModel ? appViewModel.player.channelName : ""
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: appViewModel ? appViewModel.player.stopped : true
            text: "Select a channel to start playing"
            font.pixelSize: Theme.fontSizeLg
            color: Theme.textMuted
        }

        BusyIndicator {
            anchors.centerIn: parent
            visible: appViewModel ? !appViewModel.player.playing && !appViewModel.player.paused && !appViewModel.player.stopped : false
            running: visible
            width: 48
            height: 48
        }
    }

    property bool controlsVisible: true

    Timer {
        id: controlsTimer
        interval: 3000
        running: appViewModel ? appViewModel.player.playing : false
        onTriggered: controlsVisible = false
    }

    Component.onCompleted: {
        if (channelUrl && appViewModel) {
            appViewModel.player.play(channelUrl, channelName, channelLogo)
        }
    }

    function toggleFullscreen() {
        var win = playerView.Window.window
        if (win) {
            if (win.visibility === Window.FullScreen)
                win.showNormal()
            else
                win.showFullScreen()
        }
    }

    function goBack() {
        if (appViewModel) {
            appViewModel.player.stop()
            appViewModel.currentView = "channels"
        }
    }

    Keys.onSpacePressed: { if (appViewModel) appViewModel.player.togglePause() }
    Keys.onLeftPressed: { if (appViewModel) appViewModel.player.seek(Math.max(0, appViewModel.player.position - 10)) }
    Keys.onRightPressed: { if (appViewModel) appViewModel.player.seek(appViewModel.player.position + 10) }
    Keys.onUpPressed: { if (appViewModel) appViewModel.player.volumeUp() }
    Keys.onDownPressed: { if (appViewModel) appViewModel.player.volumeDown() }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_M) {
            if (appViewModel) appViewModel.player.toggleMute()
        } else if (event.key === Qt.Key_F) {
            toggleFullscreen()
        }
    }

    focus: true

    component PlayerButton: Rectangle {
        property alias text: btnText.text
        property alias font: btnText.font
        signal clicked()

        width: 36
        height: 36
        radius: Theme.borderRadius
        color: btnHovered ? "#40ffffff" : "transparent"

        property bool btnHovered: false

        Text {
            id: btnText
            anchors.centerIn: parent
            font.pixelSize: Theme.fontSizeMd
            color: "#ffffff"
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.btnHovered = true
            onExited: parent.btnHovered = false
            onClicked: parent.clicked()
        }
    }
}
