// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import app.iptvxs

Item {
    id: control

    property bool checked: false
    signal toggled(bool checked)
    function toggle() {
        checked = !checked
        toggled(checked)
    }

    implicitWidth: 56
    implicitHeight: 30
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: control.enabled
            ? (control.checked ? Theme.accent : Theme.surfaceBorder)
            : Theme.surfaceBorder
        opacity: control.enabled ? 1.0 : 0.45
        border.width: 1
        border.color: control.activeFocus
            ? Theme.accent
            : (control.checked ? Theme.accent : Theme.surfaceBorder)
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: control.activeFocus ? 2 : 0
        border.color: Theme.accent
        opacity: control.activeFocus ? 1.0 : 0.0
    }

    Rectangle {
        width: 24
        height: 24
        radius: width / 2
        y: Math.round((control.height - height) / 2)
        x: Math.round(control.checked ? (control.width - width - 2) : 2)
        color: control.checked ? Theme.background : Theme.textOnAccent
        border.color: control.checked ? Theme.background : Theme.textOnAccent
        border.width: 1
        opacity: control.enabled ? 1.0 : 0.65

        Behavior on x {
            NumberAnimation { duration: Theme.animFast }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggle()
    }

    Keys.onSpacePressed: control.toggle()
    Keys.onReturnPressed: control.toggle()
    Keys.onEnterPressed: control.toggle()
}
