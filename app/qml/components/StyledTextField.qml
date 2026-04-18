import QtQuick
import QtQuick.Controls
import app.iptvxs

Rectangle {
    id: root

    property alias text: textInput.text
    property alias placeholderText: placeholder.text
    property alias echoMode: textInput.echoMode

    height: 40
    radius: Theme.borderRadius
    color: Theme.surface
    border.color: textInput.activeFocus ? Theme.accent : Theme.surfaceBorder
    border.width: 1

    Behavior on border.color {
        ColorAnimation { duration: Theme.animFast }
    }

    TextInput {
        id: textInput
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: Theme.fontSizeSm
        color: Theme.textPrimary
        clip: true
        selectByMouse: true
        selectionColor: Theme.accent
        selectedTextColor: "#ffffff"

        Text {
            id: placeholder
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textMuted
            visible: !textInput.text && !textInput.activeFocus
        }
    }
}
