// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import app.iptvxs

Rectangle {
    id: root

    property alias text: textInput.text
    property alias placeholderText: placeholder.text
    property alias echoMode: textInput.echoMode
    property Item nextItem: null
    property Item prevItem: null
    property Item escapeItem: null
    property bool autoShowInputMethod: true

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

        onActiveFocusChanged: {
            if (!root.autoShowInputMethod) return
            if (activeFocus) {
                Qt.inputMethod.show()
            } else {
                Qt.inputMethod.hide()
            }
        }

        Keys.onUpPressed: {
            if (root.prevItem) {
                root.prevItem.forceActiveFocus()
            } else if (root.escapeItem) {
                root.escapeItem.forceActiveFocus()
            }
        }
        Keys.onDownPressed: {
            if (root.nextItem) {
                root.nextItem.forceActiveFocus()
            }
        }

        Text {
            id: placeholder
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textMuted
            visible: !textInput.text && !textInput.activeFocus
        }
    }
}
