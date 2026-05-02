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
    property bool canAdd: nameField.text.length > 0
                            && (builtinFreeServer || urlField.text.length > 0)
    property bool editMode: false
    property int editIndex: -1
    property bool builtinFreeServer: false
    property string builtinFreeServerUrl: "https://iptvxs.schelstraete.org/api/v1/playlist.m3u"
    property string builtinFreeServerLabel: "Built-in iptvXS Free server"
    property int epgSourceId: 0
    property bool showEpgSelector: editMode && editIndex >= 0 && !builtinFreeServer
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
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                dialog.close()
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
                nextItem: builtinFreeServer ? (showEpgSelector ? epgSourceCombo : addButton) : urlField
                prevItem: firstTypeOption
                escapeAction: function() { dialog.close() }
            }

            StyledTextField {
                id: urlField
                visible: !builtinFreeServer
                Layout.fillWidth: true
                placeholderText: serverType === "xtream"
                    ? "http://example.com:8080"
                    : "http://example.com/playlist.m3u"
                nextItem: usernameField.visible
                    ? usernameField
                    : (showEpgSelector ? epgSourceCombo : addButton)
                prevItem: nameField
                escapeAction: function() { dialog.close() }
            }

            StyledTextField {
                id: usernameField
                visible: serverType === "xtream"
                Layout.fillWidth: true
                placeholderText: "Username"
                nextItem: passwordField
                prevItem: urlField
                escapeAction: function() { dialog.close() }
            }

            StyledTextField {
                id: passwordField
                visible: serverType === "xtream"
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                nextItem: showEpgSelector ? epgSourceCombo : addButton
                prevItem: usernameField
                escapeAction: function() { dialog.close() }
            }

            ComboBox {
                id: epgSourceCombo
                visible: showEpgSelector
                Layout.fillWidth: true
                model: appViewModel ? appViewModel.epgSourceList : null
                textRole: "name"
                valueRole: "epgSourceId"
                currentIndex: -1

                background: Rectangle {
                    radius: Theme.borderRadiusSmall
                    color: Theme.surfaceElevated
                    border.color: epgSourceCombo.activeFocus ? Theme.accent : Theme.surfaceBorder
                    border.width: 1
                }

                contentItem: Text {
                    text: epgSourceCombo.currentIndex >= 0
                        ? epgSourceCombo.displayText
                        : "EPG Source (optional)"
                    font.pixelSize: Theme.fontSizeSm
                    color: epgSourceCombo.currentIndex >= 0 ? Theme.textPrimary : Theme.textMuted
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: Theme.spacingSm
                    elide: Text.ElideRight
                }

                delegate: ItemDelegate {
                    width: epgSourceCombo.width
                    height: model.enabled ? 36 : 0
                    visible: model.enabled
                    contentItem: Text {
                        text: model.name
                        font.pixelSize: Theme.fontSizeSm
                        color: highlighted ? Theme.textOnAccent : Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                    }
                    highlighted: epgSourceCombo.highlightedIndex === index
                    background: Rectangle {
                        color: highlighted ? Theme.accent : (hovered ? Theme.surfaceHover : Theme.surfaceElevated)
                    }
                }

                popup: Popup {
                    y: epgSourceCombo.height
                    width: epgSourceCombo.width
                    implicitHeight: contentItem.implicitHeight + 2
                    padding: 1
                    contentItem: ListView {
                        clip: true
                        implicitHeight: Math.min(contentHeight, 250)
                        model: epgSourceCombo.popup.visible ? epgSourceCombo.delegateModel : null
                        ScrollBar.vertical: ScrollBar { active: true }
                    }
                    background: Rectangle {
                        color: Theme.surfaceElevated
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        radius: Theme.borderRadiusSmall
                    }
                }

                onCurrentValueChanged: {
                    if (currentValue > 0) {
                        epgSourceId = currentValue
                    } else if (currentIndex < 0) {
                        epgSourceId = 0
                    }
                }

                Keys.onDownPressed: {
                    if (cancelButton) cancelButton.forceActiveFocus()
                }
                Keys.onUpPressed: {
                    if (passwordField.visible) passwordField.forceActiveFocus()
                    else if (usernameField.visible) usernameField.forceActiveFocus()
                    else if (urlField.visible) urlField.forceActiveFocus()
                    else if (nameField) nameField.forceActiveFocus()
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                        dialog.close()
                        event.accepted = true
                    }
                }
            }

            Text {
                visible: builtinFreeServer
                Layout.fillWidth: true
                text: builtinFreeServerLabel
                font.pixelSize: Theme.fontSizeSm
                color: Theme.textSecondary
            }

            Text {
                visible: builtinFreeServer
                Layout.fillWidth: true
                text: "Attached EPG source: Built-in EPG"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.textSecondary
                elide: Text.ElideRight
            }

            Text {
                visible: showEpgSelector
                Layout.fillWidth: true
                text: epgSourceId > 0 && appViewModel && appViewModel.epgSourceList
                    ? "Attached EPG source: " + appViewModel.epgSourceList.sourceNameAt(
                          appViewModel.epgSourceList.indexOfSource(epgSourceId))
                    : (serverType === "xtream"
                        ? "Attached EPG source: Built-in EPG"
                        : "Attached EPG source: none")
                font.pixelSize: Theme.fontSizeSm
                color: Theme.textSecondary
                elide: Text.ElideRight
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
                    if (epgSourceCombo) epgSourceCombo.forceActiveFocus()
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
                opacity: canAdd && !validationPending ? 1.0 : 0.5
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
                    cursorShape: canAdd && !validationPending ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: parent.addHovered = true
                    onExited: parent.addHovered = false
                    onClicked: addButton.performActivate()
                }

                function performActivate() {
                    if (!canAdd || validationPending) return
                    validationMessage = ""
                    if (!appViewModel) {
                        performSave()
                        return
                    }
                    if (builtinFreeServer) {
                        performSave()
                        return
                    }
                    validationPending = true
                    if (serverType === "xtream") {
                        appViewModel.validateServerInput(
                            serverType,
                            builtinFreeServer ? builtinFreeServerUrl : urlField.text,
                            usernameField.text,
                            passwordField.text)
                    } else {
                        appViewModel.validateServerInput(
                            serverType,
                            builtinFreeServer ? builtinFreeServerUrl : urlField.text,
                            "",
                            "")
                    }
                }

                function performSave() {
                    if (appViewModel) {
                        if (editMode) {
                            appViewModel.serverList.updateServer(
                                editIndex, nameField.text, builtinFreeServer ? builtinFreeServerUrl : urlField.text,
                                usernameField.text, passwordField.text,
                                "",
                                epgSourceId)
                        } else {
                            appViewModel.serverList.addServer(
                                nameField.text, serverType,
                                builtinFreeServer ? builtinFreeServerUrl : urlField.text,
                                usernameField.text, passwordField.text,
                                "",
                                epgSourceId)
                        }
                    }
                    dialog.close()
                    resetFields()
                }

                Keys.onUpPressed: {
                    if (epgSourceCombo) epgSourceCombo.forceActiveFocus()
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

    function openForEdit(index, name, type, url, username, password, epgSourceIdValue, isBuiltinFreeServer) {
        editMode = true
        editIndex = index
        serverType = type
        builtinFreeServer = !!isBuiltinFreeServer
        nameField.text = name
        urlField.text = builtinFreeServer ? builtinFreeServerUrl : url
        usernameField.text = username
        passwordField.text = password || ""
        epgSourceId = epgSourceIdValue || 0
        if (epgSourceCombo && showEpgSelector) {
            epgSourceCombo.currentIndex = (appViewModel && appViewModel.epgSourceList)
                ? appViewModel.epgSourceList.indexOfSource(epgSourceId)
                : -1
        }
        dialog.open()
    }

    function resetFields() {
        nameField.text = ""
        urlField.text = ""
        usernameField.text = ""
        passwordField.text = ""
        epgSourceId = 0
        if (epgSourceCombo) epgSourceCombo.currentIndex = -1
        serverType = "xtream"
        builtinFreeServer = false
        editMode = false
        editIndex = -1
    }

    onOpened: {
        if (editIndex < 0) {
            editMode = false
            epgSourceId = 0
            if (epgSourceCombo) epgSourceCombo.currentIndex = -1
        }
        validationPending = false
        validationMessage = ""
        focusFirstTypeTimer.restart()
    }

    onClosed: {
        validationPending = false
        validationMessage = ""
        resetFields()
    }

    Connections {
        target: appViewModel
        function onUrlValidationFinished(context, ok, message) {
            if (context !== "server" || !dialog.validationPending) {
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
