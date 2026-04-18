import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: settingsView

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXl
        spacing: Theme.spacingLg

        Text {
            text: "Settings"
            font.pixelSize: Theme.fontSizeXl
            font.bold: true
            color: Theme.textPrimary
        }

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
                        onToggled: console.log("Start minimized:", checked)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMd

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Auto-sync on startup"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Automatically sync all servers when the app starts"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
                    }

                    Switch {
                        checked: true
                        onToggled: console.log("Auto-sync:", checked)
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
                        text: "Version"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                    }

                    Text {
                        text: appViewModel ? appViewModel.appVersion : "0.1.0"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textPrimary
                    }
                }

                RowLayout {
                    spacing: Theme.spacingMd

                    Text {
                        text: "Database"
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

        Item { Layout.fillHeight: true }
    }
}
