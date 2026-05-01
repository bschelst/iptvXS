// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Dialog {
    id: dialog

    anchors.centerIn: parent
    width: 480
    modal: true
    title: "Add Server"
    implicitHeight: Math.min(parent.height * 0.85, 520)

    property Item firstTypeOption: null
    property string serverType: "xtream"
    property bool canAdd: nameField.text.length > 0 && urlField.text.length > 0
    property bool editMode: false
    property int editIndex: -1

    background: Rectangle {
        color: Theme.surfaceElevated
        radius: Theme.borderRadiusLarge
        border.color: Theme.surfaceBorder
        border.width: 1
    }

    header: Rectangle {
        height: 56
        color: "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingLg
            anchors.verticalCenter: parent.verticalCenter
            text: editMode ? "Edit Server" : "Add Server"
            font.pixelSize: Theme.fontSizeLg
            font.bold: true
            color: Theme.textPrimary
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.surfaceBorder
        }
    }

    contentItem: ScrollView {
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: Theme.spacingMd

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Repeater {
                    id: serverTypeRepeater
                    model: [
                        { value: "xtream", label: "Xtream Codes", icon: "📡" },
                        { value: "m3u", label: "M3U Playlist", icon: "📋" }
                    ]

                    delegate: Rectangle {
                        id: typeOption
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: Theme.borderRadius
                        color: serverType === modelData.value
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.19)
                            : typeHovered ? Theme.surfaceHover : Theme.surface
                        border.color: serverType === modelData.value
                            ? Theme.accent : Theme.surfaceBorder
                        border.width: 1
                        focus: dialog.visible && ((index === 0 && !dialog.firstTypeOption) || dialog.firstTypeOption === typeOption)
                        activeFocusOnTab: true

                        property bool typeHovered: false

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        Component.onCompleted: {
                            if (index === 0) {
                                dialog.firstTypeOption = typeOption
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Theme.spacingSm

                            Text {
                                text: modelData.icon
                                font.pixelSize: Theme.fontSizeMd
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: serverType === modelData.value
                                color: serverType === modelData.value
                                    ? Theme.textPrimary : Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Keys.onLeftPressed: {
                            if (index > 0) {
                                var prev = serverTypeRepeater.itemAt(index - 1)
                                if (prev) prev.forceActiveFocus()
                            }
                        }
                        Keys.onRightPressed: {
                            if (index < serverTypeRepeater.count - 1) {
                                var next = serverTypeRepeater.itemAt(index + 1)
                                if (next) next.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: {
                            if (nameField) nameField.forceActiveFocus()
                        }
                        Keys.onReturnPressed: {
                            serverType = modelData.value
                            if (nameField) nameField.forceActiveFocus()
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                serverType = modelData.value
                                if (nameField) nameField.forceActiveFocus()
                                event.accepted = true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.typeHovered = true
                            onExited: parent.typeHovered = false
                            onClicked: serverType = modelData.value
                        }
                    }
                }
            }

            StyledTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "Server Name"
                nextItem: urlField
                prevItem: firstTypeOption
            }

            StyledTextField {
                id: urlField
                Layout.fillWidth: true
                placeholderText: serverType === "xtream"
                    ? "http://example.com:8080"
                    : "http://example.com/playlist.m3u"
                nextItem: usernameField.visible ? usernameField : epgUrlField
                prevItem: nameField
            }

            StyledTextField {
                id: usernameField
                visible: serverType === "xtream"
                Layout.fillWidth: true
                placeholderText: "Username"
                nextItem: passwordField
                prevItem: urlField
            }

            StyledTextField {
                id: passwordField
                visible: serverType === "xtream"
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                nextItem: epgUrlField
                prevItem: usernameField
            }

            StyledTextField {
                id: epgUrlField
                Layout.fillWidth: true
                placeholderText: "EPG URL (optional, XMLTV format)"
                nextItem: cancelButton
                prevItem: passwordField.visible ? passwordField : urlField
            }
        }
    }

    footer: Rectangle {
        height: 64
        color: "transparent"

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.surfaceBorder
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMd
            spacing: Theme.spacingSm

            Item { Layout.fillWidth: true }

            Rectangle {
                id: cancelButton
                Layout.preferredWidth: cancelText.width + Theme.spacingLg * 2
                Layout.preferredHeight: 36
                radius: Theme.borderRadius
                color: cancelHovered || cancelButton.activeFocus ? Theme.surfaceHover : "transparent"
                border.color: Theme.surfaceBorder
                border.width: 1
                focus: false
                activeFocusOnTab: true

                property bool cancelHovered: false

                Text {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.cancelHovered = true
                    onExited: parent.cancelHovered = false
                    onClicked: dialog.close()
                }

                Keys.onUpPressed: {
                    if (epgUrlField) epgUrlField.forceActiveFocus()
                }
                Keys.onRightPressed: {
                    if (addButton) addButton.forceActiveFocus()
                }
                Keys.onReturnPressed: dialog.close()
                Keys.onEnterPressed: Keys.onReturnPressed(event)
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space
                            || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                        dialog.close()
                        event.accepted = true
                    }
                }
            }

            Rectangle {
                id: addButton
                Layout.preferredWidth: addText.width + Theme.spacingLg * 2
                Layout.preferredHeight: 36
                radius: Theme.borderRadius
                color: addHovered || addButton.activeFocus ? Theme.accentHover : Theme.accent
                opacity: canAdd ? 1.0 : 0.5
                focus: false
                activeFocusOnTab: true

                property bool addHovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Text {
                    id: addText
                    anchors.centerIn: parent
                    text: editMode ? "Save" : "Add Server"
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: Theme.textOnAccent
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: parent.addHovered = true
                    onExited: parent.addHovered = false
                    onClicked: addButton.performActivate()
                }

                function performActivate() {
                    if (!canAdd) return
                    if (appViewModel) {
                        if (editMode) {
                            appViewModel.serverList.updateServer(
                                editIndex, nameField.text, urlField.text,
                                usernameField.text, passwordField.text,
                                epgUrlField.text)
                        } else {
                            appViewModel.serverList.addServer(
                                nameField.text, serverType, urlField.text,
                                usernameField.text, passwordField.text,
                                epgUrlField.text)
                        }
                    }
                    dialog.close()
                    resetFields()
                }

                Keys.onUpPressed: {
                    if (epgUrlField) epgUrlField.forceActiveFocus()
                }
                Keys.onLeftPressed: {
                    if (cancelButton) cancelButton.forceActiveFocus()
                }
                Keys.onReturnPressed: performActivate()
                Keys.onEnterPressed: Keys.onReturnPressed(event)
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                        performActivate()
                        event.accepted = true
                    } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                        dialog.close()
                        event.accepted = true
                    }
                }
            }
        }
    }

    function openForEdit(index, name, type, url, username, password, epgUrl) {
        editMode = true
        editIndex = index
        serverType = type
        nameField.text = name
        urlField.text = url
        usernameField.text = username
        passwordField.text = password || ""
        epgUrlField.text = epgUrl || ""
        dialog.open()
    }

    function resetFields() {
        nameField.text = ""
        urlField.text = ""
        usernameField.text = ""
        passwordField.text = ""
        epgUrlField.text = ""
        serverType = "xtream"
        editMode = false
        editIndex = -1
    }

    onOpened: {
        focusFirstTypeTimer.restart()
    }

    onClosed: resetFields()

    Timer {
        id: focusFirstTypeTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (firstTypeOption) {
                firstTypeOption.forceActiveFocus()
            }
        }
    }

    Overlay.modal: Rectangle {
        color: "#80000000"
    }
}
