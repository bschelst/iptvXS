// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Rectangle {
    id: topBar

    property string title: "Home"

    signal toggleSidebar()

    height: Theme.topBarHeight
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
        spacing: Theme.spacingMd

        Rectangle {
            id: collapseButton
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Theme.borderRadius
            color: collapseHovered || collapseButton.activeFocus ? Theme.surfaceHover : "transparent"
            focus: false
            activeFocusOnTab: true

            property bool collapseHovered: false

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Column {
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: 3
                    Rectangle { width: 18; height: 2; radius: 1; color: Theme.textSecondary }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.collapseHovered = true
                onExited: parent.collapseHovered = false
                onClicked: topBar.toggleSidebar()
            }

            Keys.onReturnPressed: topBar.toggleSidebar()
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    topBar.toggleSidebar()
                    event.accepted = true
                }
            }
        }

        Text {
            text: topBar.title
            font.pixelSize: Theme.fontSizeLg
            font.bold: true
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            visible: appViewModel && appViewModel.chromecast && appViewModel.chromecast.connected
            Layout.preferredWidth: castRow.implicitWidth + Theme.spacingMd * 2
            Layout.preferredHeight: 28
            radius: 14
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
            border.width: 1

            Row {
                id: castRow
                anchors.centerIn: parent
                spacing: 6

                Canvas {
                    width: 14
                    height: 11
                    anchors.verticalCenter: parent.verticalCenter
                    antialiasing: true
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = Theme.accent
                        ctx.fillStyle = Theme.accent
                        ctx.lineWidth = 1.2
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.moveTo(1, 9)
                        ctx.lineTo(1, 2)
                        ctx.quadraticCurveTo(1, 0.5, 2, 0.5)
                        ctx.lineTo(12, 0.5)
                        ctx.quadraticCurveTo(13, 0.5, 13, 2)
                        ctx.lineTo(13, 9)
                        ctx.quadraticCurveTo(13, 10.5, 12, 10.5)
                        ctx.lineTo(8, 10.5)
                        ctx.stroke()
                        ctx.beginPath(); ctx.arc(1, 10, 1.2, -Math.PI/2, 0); ctx.stroke()
                        ctx.beginPath(); ctx.arc(1, 10, 3.5, -Math.PI/2, 0); ctx.stroke()
                        ctx.beginPath(); ctx.arc(1, 10, 5.8, -Math.PI/2, 0); ctx.stroke()
                    }
                }

                Text {
                    text: "Casting to " + (appViewModel ? appViewModel.chromecast.connectedDeviceName : "")
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 120)
                }

                Rectangle {
                    id: castStopButton
                    width: 18
                    height: 18
                    radius: 9
                    color: topBarCastStopHov || castStopButton.activeFocus ? Theme.error : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    focus: false
                    activeFocusOnTab: true
                    property bool topBarCastStopHov: false

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 9
                        font.bold: true
                        color: (parent.topBarCastStopHov || castStopButton.activeFocus)
                            ? "#ffffff" : Theme.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.topBarCastStopHov = true
                        onExited: parent.topBarCastStopHov = false
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.chromecast.stopMedia()
                                appViewModel.chromecast.disconnect()
                            }
                        }
                    }

                    Keys.onReturnPressed: {
                        if (appViewModel) {
                            appViewModel.chromecast.stopMedia()
                            appViewModel.chromecast.disconnect()
                        }
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            Keys.onReturnPressed(event)
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Row {
            Layout.rightMargin: Theme.spacingSm
            spacing: 0

            Text {
                text: Qt.formatTime(clockTimer.currentTime, "HH")
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: ":"
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { to: 0.0; duration: 1000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: Qt.formatTime(clockTimer.currentTime, "mm")
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

            Timer {
                id: clockTimer
                property date currentTime: new Date()
                interval: 10000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: currentTime = new Date()
            }
        }
    }
}
