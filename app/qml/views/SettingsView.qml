import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: settingsView

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width - Theme.spacingXl * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Theme.spacingXl

            Item { Layout.preferredHeight: Theme.spacingLg }

            Text {
                text: "Settings"
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.preferredHeight: Theme.spacingSm }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: themeCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: themeCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Theme"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Repeater {
                            model: Theme.themeNames

                            Rectangle {
                                width: 120
                                height: 72
                                radius: Theme.borderRadius
                                color: Theme.themes[modelData].background
                                border.color: Theme.currentTheme === modelData
                                    ? Theme.accent : themeCardHovered ? Theme.surfaceBorder : "transparent"
                                border.width: 2

                                property bool themeCardHovered: false

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingSm
                                    spacing: 4

                                    Text {
                                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                        font.pixelSize: Theme.fontSizeXs
                                        font.bold: Theme.currentTheme === modelData
                                        color: Theme.themes[modelData].textPrimary
                                    }

                                    Row {
                                        spacing: 4
                                        Repeater {
                                            model: [
                                                Theme.themes[modelData].accent,
                                                Theme.themes[modelData].success,
                                                Theme.themes[modelData].warning,
                                                Theme.themes[modelData].error
                                            ]

                                            Rectangle {
                                                width: 14
                                                height: 14
                                                radius: 7
                                                color: modelData
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 8
                                        radius: 4
                                        color: Theme.themes[modelData].surface

                                        Rectangle {
                                            width: parent.width * 0.6
                                            height: parent.height
                                            radius: 4
                                            color: Theme.themes[modelData].accent
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.themeCardHovered = true
                                    onExited: parent.themeCardHovered = false
                                    onClicked: Theme.applyTheme(modelData)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: generalCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: generalCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "General"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXs

                            Text {
                                text: "Start minimized to tray"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "Launch the application minimized in the system tray"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }

                        Switch {
                            checked: false
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: syncCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: syncCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Auto-Sync"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Channel sync interval"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Automatically sync server channels in the background"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: 0, label: "Off" },
                                    { value: 1, label: "1h" },
                                    { value: 6, label: "6h" },
                                    { value: 12, label: "12h" },
                                    { value: 24, label: "24h" },
                                    { value: 48, label: "48h" }
                                ]

                                Rectangle {
                                    width: 52
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.autoSyncInterval === modelData.value
                                        ? Theme.accent : syncChHovered
                                            ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder

                                    property bool syncChHovered: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.autoSyncInterval === modelData.value
                                            ? Theme.textPrimary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.syncChHovered = true
                                        onExited: parent.syncChHovered = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.autoSyncInterval = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.surfaceBorder
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "EPG sync interval"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Automatically refresh the electronic programme guide"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: 0, label: "Off" },
                                    { value: 1, label: "1h" },
                                    { value: 6, label: "6h" },
                                    { value: 12, label: "12h" },
                                    { value: 24, label: "24h" },
                                    { value: 48, label: "48h" }
                                ]

                                Rectangle {
                                    width: 52
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.autoSyncEpgInterval === modelData.value
                                        ? Theme.accent : syncEpgHovered
                                            ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder

                                    property bool syncEpgHovered: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.autoSyncEpgInterval === modelData.value
                                            ? Theme.textPrimary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.syncEpgHovered = true
                                        onExited: parent.syncEpgHovered = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.autoSyncEpgInterval = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: gdriveCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: gdriveCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Google Drive"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXs

                            Text {
                                text: "Connection Status"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                            }

                            RowLayout {
                                spacing: Theme.spacingSm

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: appViewModel && appViewModel.gdrive.authenticated
                                        ? Theme.success : Theme.textMuted
                                }

                                Text {
                                    text: appViewModel && appViewModel.gdrive.authenticated
                                        ? "Connected" : "Not connected"
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textPrimary
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: gdriveBtn.implicitWidth + Theme.spacingLg
                            Layout.preferredHeight: 36
                            radius: Theme.borderRadius
                            color: gdriveBtnHovered
                                ? (appViewModel && appViewModel.gdrive.authenticated ? Theme.error + "30" : Theme.accent)
                                : (appViewModel && appViewModel.gdrive.authenticated ? Theme.error + "20" : Theme.accentHover)
                            border.color: appViewModel && appViewModel.gdrive.authenticated
                                ? Theme.error : Theme.accent
                            border.width: 1

                            property bool gdriveBtnHovered: false

                            Text {
                                id: gdriveBtn
                                anchors.centerIn: parent
                                text: appViewModel && appViewModel.gdrive.authenticated
                                    ? "Disconnect" : "Connect"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.gdriveBtnHovered = true
                                onExited: parent.gdriveBtnHovered = false
                                onClicked: {
                                    if (appViewModel) {
                                        if (appViewModel.gdrive.authenticated) {
                                            appViewModel.gdrive.logout()
                                        } else {
                                            appViewModel.gdrive.login()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Client ID"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Theme.borderRadiusSmall
                            color: Theme.surface
                            border.color: gdriveClientIdInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                            border.width: 1

                            TextInput {
                                id: gdriveClientIdInput
                                anchors.fill: parent
                                anchors.margins: Theme.spacingSm
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                clip: true
                                selectByMouse: true
                                echoMode: TextInput.Password

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Enter Google OAuth Client ID..."
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textMuted
                                    visible: !gdriveClientIdInput.text && !gdriveClientIdInput.activeFocus
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Client Secret"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Theme.borderRadiusSmall
                            color: Theme.surface
                            border.color: gdriveClientSecretInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                            border.width: 1

                            TextInput {
                                id: gdriveClientSecretInput
                                anchors.fill: parent
                                anchors.margins: Theme.spacingSm
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                                clip: true
                                selectByMouse: true
                                echoMode: TextInput.Password

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Enter Google OAuth Client Secret..."
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textMuted
                                    visible: !gdriveClientSecretInput.text && !gdriveClientSecretInput.activeFocus
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: saveGdriveBtn.implicitWidth + Theme.spacingLg
                        Layout.preferredHeight: 32
                        radius: Theme.borderRadiusSmall
                        color: saveGdriveBtnHovered ? Theme.accent : Theme.accentHover

                        property bool saveGdriveBtnHovered: false

                        Text {
                            id: saveGdriveBtn
                            anchors.centerIn: parent
                            text: "Save Credentials"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.saveGdriveBtnHovered = true
                            onExited: parent.saveGdriveBtnHovered = false
                            onClicked: {
                                if (appViewModel && gdriveClientIdInput.text && gdriveClientSecretInput.text) {
                                    appViewModel.gdrive.setClientCredentials(
                                        gdriveClientIdInput.text,
                                        gdriveClientSecretInput.text
                                    )
                                }
                            }
                        }
                    }

                    Text {
                        visible: appViewModel && appViewModel.gdrive.uploadStatus
                        text: appViewModel ? appViewModel.gdrive.uploadStatus : ""
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dbCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: dbCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Database"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "Status"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: appViewModel && appViewModel.databaseReady
                                ? Theme.success : Theme.error
                        }

                        Text {
                            text: appViewModel && appViewModel.databaseReady
                                ? "Connected" : "Disconnected"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }
                    }

                    Text {
                        text: "Reset will delete all servers, channels, recordings, favorites, and settings."
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: resetBtnText.implicitWidth + Theme.spacingLg * 2
                        Layout.preferredHeight: 36
                        radius: Theme.borderRadius
                        color: resetBtnHovered ? Theme.error : Theme.error + "30"
                        border.color: Theme.error
                        border.width: 1

                        property bool resetBtnHovered: false

                        Text {
                            id: resetBtnText
                            anchors.centerIn: parent
                            text: "Reset Database"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.resetBtnHovered = true
                            onExited: parent.resetBtnHovered = false
                            onClicked: resetConfirmDialog.open()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: aboutCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: aboutCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "About"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "iptvxs"
                            font.pixelSize: Theme.fontSizeLg
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "v" + (appViewModel ? appViewModel.appVersion : "0.1.0")
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                            anchors.baseline: parent.children[0].baseline
                        }
                    }

                    Text {
                        text: "Cross-platform IPTV viewer built with Qt6 and libmpv"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textMuted
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingLg }
        }
    }

    Dialog {
        id: resetConfirmDialog
        anchors.centerIn: parent
        width: 400
        modal: true
        title: "Reset Database"

        background: Rectangle {
            color: Theme.surfaceElevated
            radius: Theme.borderRadiusLarge
            border.color: Theme.error
            border.width: 1
        }

        header: Rectangle {
            height: 48
            color: "transparent"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingLg
                anchors.verticalCenter: parent.verticalCenter
                text: "Confirm Reset"
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                color: Theme.error
            }
        }

        contentItem: Text {
            text: "This will permanently delete all data including servers, channels, favorites, recordings, and settings. This cannot be undone."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
        }

        footer: Rectangle {
            height: 56
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: cancelResetText.implicitWidth + Theme.spacingLg * 2
                    Layout.preferredHeight: 36
                    radius: Theme.borderRadius
                    color: cancelResetHov ? Theme.surfaceHover : "transparent"
                    border.color: Theme.surfaceBorder
                    border.width: 1

                    property bool cancelResetHov: false

                    Text {
                        id: cancelResetText
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.cancelResetHov = true
                        onExited: parent.cancelResetHov = false
                        onClicked: resetConfirmDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: confirmResetText.implicitWidth + Theme.spacingLg * 2
                    Layout.preferredHeight: 36
                    radius: Theme.borderRadius
                    color: confirmResetHov ? Theme.error : Theme.error + "80"

                    property bool confirmResetHov: false

                    Text {
                        id: confirmResetText
                        anchors.centerIn: parent
                        text: "Reset"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.confirmResetHov = true
                        onExited: parent.confirmResetHov = false
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.resetDatabase()
                            }
                            resetConfirmDialog.close()
                        }
                    }
                }
            }
        }

        Overlay.modal: Rectangle {
            color: "#80000000"
        }
    }
}
