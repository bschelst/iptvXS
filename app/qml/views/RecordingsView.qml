import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: recordingsView

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: Theme.surface

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.surfaceBorder
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMd
                anchors.rightMargin: Theme.spacingMd

                Text {
                    text: {
                        var c = appViewModel ? appViewModel.recordingList.count : 0
                        var active = appViewModel ? appViewModel.recordingList.activeCount : 0
                        var label = c + (c === 1 ? " recording" : " recordings")
                        if (active > 0) {
                            label += " · " + active + " active"
                        }
                        return label
                    }
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: Theme.spacingXs

                    Repeater {
                        model: [
                            { label: "All", value: "" },
                            { label: "Recording", value: "recording" },
                            { label: "Scheduled", value: "scheduled" },
                            { label: "Completed", value: "completed" },
                            { label: "Failed", value: "failed" }
                        ]

                        Rectangle {
                            width: filterLabel.implicitWidth + Theme.spacingMd * 2
                            height: 28
                            radius: 14
                            color: {
                                var current = appViewModel ? appViewModel.recordingList.filterStatus : ""
                                return current === modelData.value ? Theme.accent : (filterBtnHovered ? Theme.surfaceHover : "transparent")
                            }
                            border.color: {
                                var current = appViewModel ? appViewModel.recordingList.filterStatus : ""
                                return current === modelData.value ? Theme.accent : "transparent"
                            }
                            border.width: 1

                            property bool filterBtnHovered: false

                            Text {
                                id: filterLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: true
                                color: {
                                    var current = appViewModel ? appViewModel.recordingList.filterStatus : ""
                                    return current === modelData.value ? Theme.textPrimary : Theme.textSecondary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.filterBtnHovered = true
                                onExited: parent.filterBtnHovered = false
                                onClicked: {
                                    if (appViewModel) {
                                        appViewModel.recordingList.filterStatus = modelData.value
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: recordingsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: appViewModel ? appViewModel.recordingList : null
            spacing: Theme.spacingXs

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: recordingsList.width - Theme.spacingMd * 2
                height: 80
                x: Theme.spacingMd
                radius: Theme.borderRadius
                color: recHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.color: {
                    if (model.status === "recording") return Theme.error + "60"
                    return recHovered ? Theme.accent + "40" : "transparent"
                }
                border.width: 1

                property bool recHovered: false

                Behavior on color {
                    ColorAnimation { duration: Theme.animFast }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.recHovered = true
                    onExited: parent.recHovered = false
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    spacing: Theme.spacingMd

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: Theme.borderRadiusSmall
                        color: {
                            switch (model.status) {
                            case "recording": return Theme.error + "20"
                            case "scheduled": return Theme.accent + "20"
                            case "completed": return Theme.success + "20"
                            case "failed": return Theme.error + "10"
                            default: return Theme.surface
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                switch (model.status) {
                                case "recording": return "⏺"
                                case "scheduled": return "⏰"
                                case "completed": return "✅"
                                case "failed": return "❌"
                                case "uploading": return "☁"
                                case "uploaded": return "☁"
                                default: return "📹"
                                }
                            }
                            font.pixelSize: 20
                        }

                        SequentialAnimation on opacity {
                            running: model.status === "recording"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: model.channelName
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: Theme.spacingSm

                            Text {
                                text: appViewModel ? appViewModel.recordingList.formatDateTime(model.startTime) : ""
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }

                            Text {
                                visible: model.endTime > 0
                                text: "→ " + (appViewModel ? appViewModel.recordingList.formatDateTime(model.endTime) : "")
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }

                            Rectangle {
                                width: 1
                                height: 12
                                color: Theme.surfaceBorder
                            }

                            Text {
                                text: appViewModel ? appViewModel.recordingList.formatDuration(model.startTime, model.endTime) : ""
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                            }
                        }

                        RowLayout {
                            spacing: Theme.spacingSm

                            Rectangle {
                                width: statusLabel.implicitWidth + 12
                                height: 18
                                radius: 9
                                color: {
                                    switch (model.status) {
                                    case "recording": return Theme.error + "30"
                                    case "scheduled": return Theme.accent + "30"
                                    case "completed": return Theme.success + "30"
                                    case "failed": return Theme.error + "20"
                                    default: return Theme.surface
                                    }
                                }

                                Text {
                                    id: statusLabel
                                    anchors.centerIn: parent
                                    text: model.status
                                    font.pixelSize: 10
                                    font.capitalization: Font.AllUppercase
                                    font.bold: true
                                    color: {
                                        switch (model.status) {
                                        case "recording": return Theme.error
                                        case "scheduled": return Theme.accent
                                        case "completed": return Theme.success
                                        case "failed": return Theme.error
                                        default: return Theme.textSecondary
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: model.fileSize > 0
                                text: appViewModel ? appViewModel.recordingList.formatFileSize(model.fileSize) : ""
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }

                            Text {
                                visible: model.quality !== "original"
                                text: model.quality
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }
                    }

                    RowLayout {
                        spacing: Theme.spacingXs

                        Rectangle {
                            visible: model.status === "recording" || model.status === "scheduled"
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: stopBtnHovered ? Theme.error + "30" : "transparent"

                            property bool stopBtnHovered: false

                            Text {
                                anchors.centerIn: parent
                                text: model.status === "recording" ? "⏹" : "▶"
                                font.pixelSize: Theme.fontSizeMd
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.stopBtnHovered = true
                                onExited: parent.stopBtnHovered = false
                                onClicked: {
                                    if (appViewModel) {
                                        appViewModel.recordingList.stopRecording(model.recordingId)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: model.status === "completed" && appViewModel && appViewModel.gdrive.authenticated
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: uploadBtnHovered ? Theme.accent + "30" : "transparent"

                            property bool uploadBtnHovered: false

                            Text {
                                anchors.centerIn: parent
                                text: "☁"
                                font.pixelSize: Theme.fontSizeMd
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.uploadBtnHovered = true
                                onExited: parent.uploadBtnHovered = false
                                onClicked: {
                                    if (appViewModel) {
                                        appViewModel.gdrive.uploadRecording(model.recordingId)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: deleteBtnHovered ? Theme.error + "30" : "transparent"

                            property bool deleteBtnHovered: false

                            Text {
                                anchors.centerIn: parent
                                text: "🗑"
                                font.pixelSize: Theme.fontSizeSm
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.deleteBtnHovered = true
                                onExited: parent.deleteBtnHovered = false
                                onClicked: {
                                    if (appViewModel) {
                                        appViewModel.recordingList.deleteRecording(model.recordingId)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: model.status === "failed" && model.errorMessage
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.spacingSm
                    height: visible ? errorText.implicitHeight + 8 : 0
                    radius: 4
                    color: Theme.error + "10"

                    Text {
                        id: errorText
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: model.errorMessage || ""
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.error
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: recordingsList.count === 0
                text: "No recordings yet.\nUse the record button on any channel to start recording."
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }
    }
}
