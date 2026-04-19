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

                Rectangle {
                    Layout.preferredWidth: newRecBtnText.implicitWidth + Theme.spacingLg
                    Layout.preferredHeight: 32
                    radius: 16
                    color: newRecBtnHov ? Theme.accent : Theme.accentHover

                    property bool newRecBtnHov: false

                    Text {
                        id: newRecBtnText
                        anchors.centerIn: parent
                        text: "+ Record"
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.newRecBtnHov = true
                        onExited: parent.newRecBtnHov = false
                        onClicked: manualRecordDialog.open()
                    }
                }

                Item { Layout.preferredWidth: Theme.spacingSm }

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
                    onDoubleClicked: {
                        if (model.status === "completed" && model.filePath && appViewModel) {
                            appViewModel.pendingPlayUrl = model.filePath
                            appViewModel.pendingPlayName = model.channelName + " (Recording)"
                            appViewModel.currentView = "player"
                        }
                    }
                    cursorShape: model.status === "completed" ? Qt.PointingHandCursor : Qt.ArrowCursor
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
                                width: statusLabel.implicitWidth + 16
                                height: 20
                                radius: 10
                                color: {
                                    switch (model.status) {
                                    case "recording": return Theme.error
                                    case "scheduled": return Theme.accent
                                    case "completed": return Theme.success
                                    case "failed": return Theme.error + "cc"
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
                                    color: "#ffffff"
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
                text: "No recordings yet.\nUse the record button on any channel\nor click '+ Record' to schedule one."
                font.pixelSize: Theme.fontSizeMd
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }
    }

    Dialog {
        id: manualRecordDialog
        anchors.centerIn: parent
        width: 480
        height: 520
        modal: true
        padding: Theme.spacingLg

        property var selectedChannelId: 0
        property int durationMinutes: 60

        background: Rectangle {
            color: Theme.surfaceElevated
            radius: Theme.borderRadiusLarge
            border.color: Theme.accent
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacingMd

            Text {
                text: "New Recording"
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                color: Theme.textPrimary
            }

            Text { text: "Server"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }

            ComboBox {
                id: serverCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                model: appViewModel ? appViewModel.serverList : null
                textRole: "name"
                currentIndex: -1
                displayText: currentIndex >= 0 ? currentText : "Select a server..."
                background: Rectangle { radius: Theme.borderRadiusSmall; color: Theme.surface; border.color: Theme.surfaceBorder; border.width: 1 }
                contentItem: Text { leftPadding: Theme.spacingSm; text: serverCombo.displayText; font.pixelSize: Theme.fontSizeSm; color: serverCombo.currentIndex >= 0 ? Theme.textPrimary : Theme.textMuted; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && appViewModel) {
                        var srvId = appViewModel.serverList.serverIdAt(currentIndex)
                        channelCombo.model = null
                        appViewModel.channelList.serverId = srvId
                        channelCombo.model = appViewModel.channelList
                    }
                }
            }

            Text { text: "Channel"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }

            ComboBox {
                id: channelCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                model: null
                textRole: "name"
                currentIndex: -1
                displayText: currentIndex >= 0 ? currentText : "Select a channel..."
                background: Rectangle { radius: Theme.borderRadiusSmall; color: Theme.surface; border.color: Theme.surfaceBorder; border.width: 1 }
                contentItem: Text { leftPadding: Theme.spacingSm; text: channelCombo.displayText; font.pixelSize: Theme.fontSizeSm; color: channelCombo.currentIndex >= 0 ? Theme.textPrimary : Theme.textMuted; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && appViewModel) {
                        manualRecordDialog.selectedChannelId = appViewModel.channelList.data(
                            appViewModel.channelList.index(currentIndex, 0), 257)
                    }
                }
            }

            Text { text: "Duration"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Repeater {
                    model: [
                        { value: 30, label: "30 min" },
                        { value: 60, label: "1 hour" },
                        { value: 120, label: "2 hours" },
                        { value: 180, label: "3 hours" },
                        { value: 360, label: "6 hours" }
                    ]

                    Rectangle {
                        width: durLabel.implicitWidth + Theme.spacingMd * 2
                        height: 32
                        radius: Theme.borderRadiusSmall
                        color: manualRecordDialog.durationMinutes === modelData.value
                            ? Theme.accent : durHov ? Theme.surfaceHover : Theme.surface
                        border.width: 1
                        border.color: Theme.surfaceBorder
                        property bool durHov: false

                        Text {
                            id: durLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeXs
                            color: manualRecordDialog.durationMinutes === modelData.value
                                ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.durHov = true
                            onExited: parent.durHov = false
                            onClicked: manualRecordDialog.durationMinutes = modelData.value
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: cancelRecText.implicitWidth + Theme.spacingLg * 2
                    Layout.preferredHeight: 36
                    radius: Theme.borderRadius
                    color: cancelRecHov ? Theme.surfaceHover : "transparent"
                    border.color: Theme.surfaceBorder; border.width: 1
                    property bool cancelRecHov: false
                    Text { id: cancelRecText; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.cancelRecHov = true; onExited: parent.cancelRecHov = false; onClicked: manualRecordDialog.close() }
                }

                Rectangle {
                    Layout.preferredWidth: startRecText.implicitWidth + Theme.spacingLg * 2
                    Layout.preferredHeight: 36
                    radius: Theme.borderRadius
                    color: startRecHov ? Theme.error : Theme.error + "cc"
                    opacity: manualRecordDialog.selectedChannelId > 0 ? 1.0 : 0.4
                    property bool startRecHov: false
                    Text { id: startRecText; anchors.centerIn: parent; text: "Start Recording"; font.pixelSize: Theme.fontSizeSm; font.bold: true; color: "#ffffff" }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: manualRecordDialog.selectedChannelId > 0 ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onEntered: parent.startRecHov = true; onExited: parent.startRecHov = false
                        onClicked: {
                            if (manualRecordDialog.selectedChannelId > 0 && appViewModel) {
                                var now = Math.floor(Date.now() / 1000)
                                var endTime = now + manualRecordDialog.durationMinutes * 60
                                appViewModel.recordingList.scheduleRecording(manualRecordDialog.selectedChannelId, now, endTime, "original")
                                appViewModel.recordingList.refresh()
                                manualRecordDialog.close()
                            }
                        }
                    }
                }
            }
        }

        Overlay.modal: Rectangle { color: "#80000000" }

        onOpened: {
            selectedChannelId = 0
            durationMinutes = 60
            serverCombo.currentIndex = -1
            channelCombo.currentIndex = -1
        }
    }
}
