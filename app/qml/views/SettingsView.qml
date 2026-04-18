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

        Item { Layout.fillHeight: true }
    }
}
