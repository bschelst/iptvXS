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
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Theme.borderRadius
            color: collapseHovered ? Theme.surfaceHover : "transparent"

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
        }

        Text {
            text: topBar.title
            font.pixelSize: Theme.fontSizeLg
            font.bold: true
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        Text {
            text: Qt.formatTime(clockTimer.currentTime, "HH:mm")
            font.pixelSize: Theme.fontSizeLg
            font.bold: true
            color: Theme.textPrimary
            Layout.rightMargin: Theme.spacingSm

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
