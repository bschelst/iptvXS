import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Rectangle {
    id: topBar

    property string title: "Home"
    property string searchPlaceholder: "Search channels..."

    signal searchTextChanged(string text)
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

            Text {
                anchors.centerIn: parent
                text: "☰"
                font.pixelSize: Theme.fontSizeLg
                color: Theme.textSecondary
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

        Rectangle {
            Layout.preferredWidth: 320
            Layout.preferredHeight: 36
            radius: 18
            color: Theme.surfaceElevated
            border.color: searchField.activeFocus ? Theme.accent : Theme.surfaceBorder
            border.width: 1

            Behavior on border.color {
                ColorAnimation { duration: Theme.animFast }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd
                spacing: Theme.spacingSm

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🔍"
                    font.pixelSize: Theme.fontSizeSm
                    opacity: 0.5
                }

                TextInput {
                    id: searchField
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textPrimary
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: topBar.searchPlaceholder
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textMuted
                        visible: !searchField.text && !searchField.activeFocus
                    }

                    onTextChanged: {
                        searchTimer.restart()
                    }

                    Timer {
                        id: searchTimer
                        interval: 300
                        onTriggered: topBar.searchTextChanged(searchField.text)
                    }
                }
            }
        }
    }
}
