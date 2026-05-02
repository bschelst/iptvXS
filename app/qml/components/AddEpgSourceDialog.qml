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
    title: "Add EPG Source"
    implicitHeight: Math.min(parent.height * 0.65, 360)

    property bool editMode: false
    property int editIndex: -1
    property bool validationPending: false
    property string validationMessage: ""

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
            text: editMode ? "Edit EPG Source" : "Add EPG Source"
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

            StyledTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "EPG Source Name"
                nextItem: urlField
                escapeAction: function() { dialog.close() }
            }

            StyledTextField {
                id: urlField
                Layout.fillWidth: true
                placeholderText: "XMLTV URL"
                prevItem: nameField
                nextItem: cancelButton
                escapeAction: function() { dialog.close() }
            }

            Text {
                visible: validationPending || validationMessage.length > 0
                Layout.fillWidth: true
                text: validationPending ? "Validating URL..." : validationMessage
                font.pixelSize: Theme.fontSizeSm
                color: validationPending ? Theme.textMuted : Theme.error
                wrapMode: Text.WordWrap
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
                    if (urlField) urlField.forceActiveFocus()
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
                opacity: addButton.canAdd && !validationPending ? 1.0 : 0.5
                focus: false
                activeFocusOnTab: true

                property bool addHovered: false
                readonly property bool canAdd: nameField.text.length > 0 && urlField.text.length > 0

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                Text {
                    id: addText
                    anchors.centerIn: parent
                    text: editMode ? "Save" : "Add EPG Source"
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: Theme.textOnAccent
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: addButton.canAdd && !validationPending ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: parent.addHovered = true
                    onExited: parent.addHovered = false
                    onClicked: addButton.performActivate()
                }

                function performActivate() {
                    if (!addButton.canAdd || validationPending) return
                    validationMessage = ""
                    if (!appViewModel) {
                        performSave()
                        return
                    }
                    validationPending = true
                    appViewModel.validateEpgSourceInput(urlField.text)
                }

                function performSave() {
                    if (appViewModel && appViewModel.epgSourceList) {
                        if (editMode) {
                            appViewModel.epgSourceList.updateSource(editIndex, nameField.text, urlField.text)
                        } else {
                            appViewModel.epgSourceList.addSource(nameField.text, urlField.text)
                        }
                    }
                    dialog.close()
                    resetFields()
                }

                Keys.onUpPressed: {
                    if (urlField) urlField.forceActiveFocus()
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

    function openForEdit(index, name, url) {
        editMode = true
        editIndex = index
        nameField.text = name
        urlField.text = url
        dialog.open()
    }

    function resetFields() {
        nameField.text = ""
        urlField.text = ""
        editMode = false
        editIndex = -1
    }

    onOpened: {
        if (nameField) {
            nameField.forceActiveFocus()
        }
        validationPending = false
        validationMessage = ""
    }

    onClosed: {
        validationPending = false
        validationMessage = ""
        resetFields()
    }

    Connections {
        target: appViewModel
        function onUrlValidationFinished(context, ok, message) {
            if (context !== "epg" || !dialog.validationPending) {
                return
            }
            dialog.validationPending = false
            if (!ok) {
                dialog.validationMessage = message
                return
            }
            addButton.performSave()
        }
    }

    Overlay.modal: Rectangle {
        color: "#80000000"
    }
}
