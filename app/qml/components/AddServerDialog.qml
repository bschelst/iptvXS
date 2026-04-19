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
                model: [
                    { value: "xtream", label: "Xtream Codes", icon: "📡" },
                    { value: "m3u", label: "M3U Playlist", icon: "📋" }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Theme.borderRadius
                    color: serverType === modelData.value
                        ? Theme.accent + "30"
                        : typeHovered ? Theme.surfaceHover : Theme.surface
                    border.color: serverType === modelData.value
                        ? Theme.accent : Theme.surfaceBorder
                    border.width: 1

                    property bool typeHovered: false

                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast }
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
        }

        StyledTextField {
            id: urlField
            Layout.fillWidth: true
            placeholderText: serverType === "xtream"
                ? "http://example.com:8080"
                : "http://example.com/playlist.m3u"
        }

        StyledTextField {
            id: usernameField
            visible: serverType === "xtream"
            Layout.fillWidth: true
            placeholderText: "Username"
        }

        StyledTextField {
            id: passwordField
            visible: serverType === "xtream"
            Layout.fillWidth: true
            placeholderText: "Password"
            echoMode: TextInput.Password
        }

        StyledTextField {
            id: epgUrlField
            Layout.fillWidth: true
            placeholderText: "EPG URL (optional, XMLTV format)"
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
                Layout.preferredWidth: cancelText.width + Theme.spacingLg * 2
                Layout.preferredHeight: 36
                radius: Theme.borderRadius
                color: cancelHovered ? Theme.surfaceHover : "transparent"
                border.color: Theme.surfaceBorder
                border.width: 1

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
            }

            Rectangle {
                Layout.preferredWidth: addText.width + Theme.spacingLg * 2
                Layout.preferredHeight: 36
                radius: Theme.borderRadius
                color: addHovered ? Theme.accentHover : Theme.accent
                opacity: canAdd ? 1.0 : 0.5

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
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: parent.addHovered = true
                    onExited: parent.addHovered = false
                    onClicked: {
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
                }
            }
        }
    }

    property string serverType: "xtream"
    property bool canAdd: nameField.text.length > 0 && urlField.text.length > 0
    property bool editMode: false
    property int editIndex: -1

    function openForEdit(index, name, type, url, username, epgUrl) {
        editMode = true
        editIndex = index
        serverType = type
        nameField.text = name
        urlField.text = url
        usernameField.text = username
        passwordField.text = ""
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

    onClosed: resetFields()

    Overlay.modal: Rectangle {
        color: "#80000000"
    }
}
