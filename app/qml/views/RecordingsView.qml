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

                Item { Layout.preferredWidth: Theme.spacingSm }

                Text {
                    property real usedGb: appViewModel ? appViewModel.recordingList.totalRecordingBytes() / (1024*1024*1024) : 0
                    property int maxGb: appViewModel ? appViewModel.maxRecordingSizeGb : 0
                    text: usedGb.toFixed(1) + " GB used" + (maxGb > 0 ? " / " + maxGb + " GB" : "")
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textMuted
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Theme.surface
                    border.color: Theme.surfaceBorder
                    border.width: 1
                    visible: appViewModel && appViewModel.maxRecordingSizeGb > 0

                    Rectangle {
                        width: {
                            if (!appViewModel || appViewModel.maxRecordingSizeGb <= 0) return 0
                            var ratio = appViewModel.recordingList.totalRecordingBytes() / (appViewModel.maxRecordingSizeGb * 1024*1024*1024)
                            return Math.min(1, ratio) * parent.width
                        }
                        height: parent.height
                        radius: 4
                        color: width / parent.width > 0.9 ? Theme.error : Theme.accent
                    }
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
                        color: Theme.textOnAccent
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
                            { label: "Uploading", value: "uploading" },
                            { label: "Uploaded", value: "uploaded" },
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
                                    return current === modelData.value ? Theme.textOnAccent : Theme.textSecondary
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

            section.property: "status"
            section.delegate: Rectangle {
                required property string section
                width: recordingsList.width
                height: 32
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMd
                    anchors.rightMargin: Theme.spacingMd

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: {
                            switch (section) {
                            case "recording": return Theme.error
                            case "scheduled": return Theme.accent
                            case "completed": return Theme.success
                            case "uploading": return Theme.accent
                            case "uploaded": return Theme.success
                            case "failed": return Theme.error
                            default: return Theme.textMuted
                            }
                        }
                    }

                    Text {
                        text: {
                            switch (section) {
                            case "recording": return "Recording"
                            case "scheduled": return "Scheduled"
                            case "completed": return "Completed"
                            case "uploading": return "Uploading"
                            case "uploaded": return "Uploaded"
                            case "failed": return "Failed"
                            default: return section
                            }
                        }
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        color: Theme.textSecondary
                        font.letterSpacing: 1
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.surfaceBorder
                    opacity: 0.5
                }
            }

            delegate: Rectangle {
                width: recordingsList.width - Theme.spacingMd * 2
                readonly property bool isUploading:
                    model.status === "uploading" && appViewModel &&
                    appViewModel.gdrive.uploading
                readonly property bool hasBottomBar:
                    (model.status === "failed" && model.errorMessage) || isUploading
                height: hasBottomBar ? 108 : 80
                x: Theme.spacingMd
                radius: Theme.borderRadius
                color: recHovered ? Theme.surfaceHover : Theme.surfaceElevated
                border.color: {
                    if (model.pinned) return Theme.accent + "80"
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
                    onClicked: {
                        if ((model.status === "completed" || model.status === "uploaded") && appViewModel) {
                            if (model.filePath && model.filePath.length > 0) {
                                appViewModel.pendingPlayUrl = model.filePath
                                appViewModel.pendingPlayName = model.channelName + " (Recording)"
                                appViewModel.currentView = "player"
                            } else {
                                noFileToast.show()
                            }
                        }
                    }
                    cursorShape: (model.status === "completed" || model.status === "uploaded")
                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                RowLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.spacingSm
                    anchors.rightMargin: Theme.spacingSm
                    anchors.topMargin: Theme.spacingSm
                    height: 72
                    spacing: Theme.spacingSm

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        Layout.alignment: Qt.AlignTop
                        radius: Theme.borderRadiusSmall
                        clip: true
                        color: {
                            switch (model.status) {
                            case "recording": return Theme.error + "20"
                            case "scheduled": return Theme.accent + "20"
                            case "completed": return Theme.success + "20"
                            case "uploading": return Theme.accent + "20"
                            case "uploaded": return Theme.success + "20"
                            case "failed": return Theme.error + "10"
                            default: return Theme.surface
                            }
                        }

                        Image {
                            id: recThumb
                            anchors.fill: parent
                            source: model.thumbnailUrl && model.thumbnailUrl.indexOf("http") === 0
                                ? model.thumbnailUrl : ""
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                            Text {
                                anchors.centerIn: parent
                                visible: !recThumb.visible
                                text: {
                                    switch (model.status) {
                                    case "recording": return "●"
                                    case "scheduled": return "◷"
                                    case "completed": return "✓"
                                    case "failed": return "✕"
                                    case "uploading": return "↑"
                                    case "uploaded": return "☁"
                                    default: return "▶"
                                    }
                                }
                                font.pixelSize: 20
                                font.bold: model.status === "completed" || model.status === "failed"
                                color: {
                                    switch (model.status) {
                                    case "recording": return Theme.error
                                    case "scheduled": return Theme.accent
                                    case "completed": return Theme.success
                                    case "uploading": return Theme.accent
                                    case "uploaded": return Theme.success
                                    case "failed": return Theme.error
                                    default: return Theme.textSecondary
                                    }
                                }
                            }

                        Rectangle {
                            visible: recThumb.visible
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: 16
                            height: 16
                            radius: 8
                            z: 10
                            color: {
                                switch (model.status) {
                                case "recording": return Theme.error
                                case "scheduled": return Theme.accent
                                case "completed": return Theme.success
                                case "uploading": return Theme.accent
                                case "uploaded": return Theme.success
                                case "failed": return Theme.error
                                default: return Theme.surface
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    switch (model.status) {
                                    case "recording": return "●"
                                    case "scheduled": return "◷"
                                    case "completed": return "✓"
                                    case "failed": return "✕"
                                    case "uploading": return "↑"
                                    case "uploaded": return "☁"
                                    default: return ""
                                    }
                                }
                                font.pixelSize: 9
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        SequentialAnimation on opacity {
                            running: model.status === "recording" || model.status === "uploading"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Text {
                                text: model.channelName
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: model.programmeTitle && model.programmeTitle.length > 0
                                text: model.programmeTitle || ""
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
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
                                    case "uploading": return Theme.accent
                                    case "uploaded": return Theme.success
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
                                    color: Theme.textOnAccent
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
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: Theme.spacingXs

                        // Pin button
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: model.pinned ? Theme.accent + "30" : pinBtnHov ? Theme.accent + "15" : "transparent"
                            border.color: model.pinned ? Theme.accent : "transparent"
                            border.width: model.pinned ? 1 : 0
                            property bool pinBtnHov: false

                            Text {
                                anchors.centerIn: parent
                                text: "\uD83D\uDCCC"
                                font.pixelSize: 14
                                opacity: model.pinned ? 1.0 : (parent.pinBtnHov ? 0.8 : 0.4)
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.pinBtnHov = true
                                onExited: parent.pinBtnHov = false
                                onClicked: {
                                    if (appViewModel)
                                        appViewModel.recordingList.togglePin(model.recordingId)
                                }
                            }
                        }

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
                                    if (!appViewModel) return
                                    if (model.isActive) {
                                        appViewModel.recordingList.stopRecording(model.recordingId)
                                    } else if (model.status === "recording" && appViewModel.player.recording) {
                                        appViewModel.player.stopStreamRecord()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: model.status === "uploaded" && model.filePath && model.filePath.length > 0
                            Layout.preferredWidth: delLocalLabel.implicitWidth + 16
                            Layout.preferredHeight: 28
                            radius: Theme.borderRadius
                            color: delLocalHov ? Theme.error + "30" : "transparent"
                            border.color: delLocalHov ? Theme.error : Theme.surfaceBorder
                            border.width: 1
                            property bool delLocalHov: false

                            Text {
                                id: delLocalLabel
                                anchors.centerIn: parent
                                text: "🗑 Local"
                                font.pixelSize: 10
                                color: parent.delLocalHov ? Theme.error : Theme.textMuted
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.delLocalHov = true
                                onExited: parent.delLocalHov = false
                                onClicked: {
                                    if (appViewModel)
                                        appViewModel.recordingList.deleteLocalFile(model.recordingId)
                                }
                            }
                        }

                        Rectangle {
                            visible: (model.status === "completed" || model.status === "failed") && appViewModel && appViewModel.gdrive.authenticated
                            Layout.preferredWidth: model.status === "failed" ? retryLabel.implicitWidth + 20 : 32
                            Layout.preferredHeight: 32
                            radius: model.status === "failed" ? Theme.borderRadius : 16
                            color: uploadBtnHovered
                                ? (model.status === "failed" ? Theme.warning : Theme.accent + "30")
                                : (model.status === "failed" ? Theme.warning + "20" : "transparent")

                            property bool uploadBtnHovered: false

                            Text {
                                id: retryLabel
                                anchors.centerIn: parent
                                text: model.status === "failed" ? "↻ Retry Upload" : "☁"
                                font.pixelSize: model.status === "failed" ? Theme.fontSizeXs : Theme.fontSizeMd
                                font.bold: model.status === "failed"
                                color: model.status === "failed"
                                    ? (parent.uploadBtnHovered ? Theme.textOnAccent : Theme.warning)
                                    : Theme.textSecondary
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
                                text: "✕"
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                                color: parent.deleteBtnHovered ? Theme.error : Theme.textMuted
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.deleteBtnHovered = true
                                onExited: parent.deleteBtnHovered = false
                                onClicked: {
                                    deleteConfirmDialog.recordingId = model.recordingId
                                    deleteConfirmDialog.recordingName = model.channelName || "Recording"
                                    deleteConfirmDialog.visible = true
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
                    anchors.bottomMargin: 4
                    anchors.leftMargin: Theme.spacingSm + 44 + Theme.spacingMd
                    anchors.rightMargin: Theme.spacingSm
                    height: visible ? 22 : 0
                    radius: 4
                    color: Theme.error + "30"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: dismissBtn.left
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        text: {
                            var msg = model.errorMessage || ""
                            var lines = msg.split("\n")
                            for (var i = 0; i < lines.length; i++) {
                                var l = lines[i].trim()
                                if (l.startsWith("Error opening") || l.startsWith("Error ")) {
                                    return l
                                }
                            }
                            return lines[lines.length - 1] || msg
                        }
                        font.pixelSize: 11
                        color: "#ff6b6b"
                        elide: Text.ElideRight
                    }

                    Text {
                        id: dismissBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        font.pixelSize: 12
                        color: Theme.error
                        opacity: dismissHov ? 1.0 : 0.6

                        property bool dismissHov: false

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.dismissHov = true
                            onExited: parent.dismissHov = false
                            onClicked: {
                                if (appViewModel)
                                    appViewModel.recordingList.clearError(model.recordingId)
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: isUploading
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottomMargin: 6
                    anchors.leftMargin: Theme.spacingSm + 44 + Theme.spacingMd
                    anchors.rightMargin: Theme.spacingSm
                    spacing: 2

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1

                        Rectangle {
                            width: {
                                var p = appViewModel ? appViewModel.gdrive.uploadProgress : 0
                                return Math.max(0, Math.min(1, p)) * parent.width
                            }
                            height: parent.height
                            radius: 3
                            color: Theme.accent

                            Behavior on width {
                                NumberAnimation { duration: 200 }
                            }
                        }
                    }

                    Text {
                        text: {
                            var p = appViewModel ? appViewModel.gdrive.uploadProgress : 0
                            var pct = Math.round(p * 100)
                            var status = appViewModel ? appViewModel.gdrive.uploadStatus : ""
                            return pct + "% — " + status
                        }
                        font.pixelSize: 10
                        color: Theme.textMuted
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
        height: 600
        modal: true
        padding: Theme.spacingLg

        property var selectedChannelId: 0
        property int durationMinutes: 60
        property bool startNow: true
        property int startHour: new Date().getHours()
        property int startMinute: new Date().getMinutes()
        property int startDay: 0

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
                delegate: ItemDelegate {
                    width: serverCombo.width
                    height: model.enabled ? 36 : 0
                    visible: model.enabled
                    contentItem: Text {
                        text: model.name
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: model.isPrimary
                        color: highlighted ? Theme.textOnAccent : Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                    }
                    highlighted: serverCombo.highlightedIndex === index
                    background: Rectangle {
                        color: highlighted ? Theme.accent : (hovered ? Theme.surfaceHover : Theme.surfaceElevated)
                    }
                }
                popup: Popup {
                    y: serverCombo.height
                    width: serverCombo.width
                    implicitHeight: contentItem.implicitHeight + 2
                    padding: 1
                    contentItem: ListView {
                        clip: true
                        implicitHeight: Math.min(contentHeight, 250)
                        model: serverCombo.popup.visible ? serverCombo.delegateModel : null
                        ScrollBar.vertical: ScrollBar { active: true }
                    }
                    background: Rectangle {
                        color: Theme.surfaceElevated
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        radius: Theme.borderRadiusSmall
                    }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && appViewModel) {
                        var srvId = appViewModel.serverList.serverIdAt(currentIndex)
                        channelCombo.model = null
                        appViewModel.channelList.typeFilter = "live"
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
                delegate: ItemDelegate {
                    width: channelCombo.width
                    contentItem: Text {
                        text: model.name
                        font.pixelSize: Theme.fontSizeSm
                        color: highlighted ? Theme.textOnAccent : Theme.textPrimary
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    highlighted: channelCombo.highlightedIndex === index
                    background: Rectangle {
                        color: highlighted ? Theme.accent : (hovered ? Theme.surfaceHover : Theme.surfaceElevated)
                    }
                }
                popup: Popup {
                    y: channelCombo.height
                    width: channelCombo.width
                    implicitHeight: contentItem.implicitHeight + 2
                    padding: 1
                    contentItem: ListView {
                        clip: true
                        implicitHeight: Math.min(contentHeight, 300)
                        model: channelCombo.popup.visible ? channelCombo.delegateModel : null
                        ScrollBar.vertical: ScrollBar { active: true }
                    }
                    background: Rectangle {
                        color: Theme.surfaceElevated
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        radius: Theme.borderRadiusSmall
                    }
                }
                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && appViewModel) {
                        manualRecordDialog.selectedChannelId = appViewModel.channelList.data(
                            appViewModel.channelList.index(currentIndex, 0), 257)
                    }
                }
            }

            Text { text: "Start Time"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }

            Row {
                spacing: Theme.spacingSm

                Repeater {
                    model: [
                        { label: "Now", value: true },
                        { label: "Schedule", value: false }
                    ]

                    Rectangle {
                        width: startModeLabel.implicitWidth + Theme.spacingMd * 2
                        height: 32
                        radius: Theme.borderRadiusSmall
                        color: manualRecordDialog.startNow === modelData.value ? Theme.accent : startModeHov ? Theme.surfaceHover : Theme.surface
                        border.width: 1
                        border.color: Theme.surfaceBorder
                        property bool startModeHov: false

                        Text {
                            id: startModeLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeXs
                            color: manualRecordDialog.startNow === modelData.value ? Theme.textOnAccent : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.startModeHov = true
                            onExited: parent.startModeHov = false
                            onClicked: manualRecordDialog.startNow = modelData.value
                        }
                    }
                }
            }

            RowLayout {
                visible: !manualRecordDialog.startNow
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                ComboBox {
                    id: dayCombo
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 32
                    model: {
                        var days = []
                        var now = new Date()
                        for (var i = 0; i < 7; i++) {
                            var d = new Date(now.getTime() + i * 86400000)
                            days.push(i === 0 ? "Today" : i === 1 ? "Tomorrow" : Qt.formatDate(d, "ddd dd MMM"))
                        }
                        return days
                    }
                    currentIndex: manualRecordDialog.startDay
                    onCurrentIndexChanged: manualRecordDialog.startDay = currentIndex
                    background: Rectangle { radius: Theme.borderRadiusSmall; color: Theme.surface; border.color: Theme.surfaceBorder; border.width: 1 }
                    contentItem: Text { leftPadding: Theme.spacingSm; text: dayCombo.currentText; font.pixelSize: Theme.fontSizeSm; color: Theme.textPrimary; verticalAlignment: Text.AlignVCenter }
                }

                SpinBox {
                    id: hourSpin
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 36
                    from: 0; to: 23
                    value: manualRecordDialog.startHour
                    onValueChanged: manualRecordDialog.startHour = value
                    editable: true
                    background: Rectangle { radius: Theme.borderRadiusSmall; color: Theme.surface; border.color: Theme.surfaceBorder; border.width: 1 }
                    contentItem: TextInput { text: hourSpin.textFromValue(hourSpin.value, hourSpin.locale); font.pixelSize: Theme.fontSizeMd; font.bold: true; color: Theme.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; readOnly: !hourSpin.editable; validator: hourSpin.validator; inputMethodHints: Qt.ImhDigitsOnly; selectionColor: Theme.accent }
                    up.indicator: Rectangle { x: parent.width - width; width: 24; height: parent.height; radius: Theme.borderRadiusSmall; color: hourSpin.up.pressed ? Theme.accent : Theme.surfaceHover; Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; font.bold: true; color: Theme.textPrimary } }
                    down.indicator: Rectangle { x: 0; width: 24; height: parent.height; radius: Theme.borderRadiusSmall; color: hourSpin.down.pressed ? Theme.accent : Theme.surfaceHover; Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 16; font.bold: true; color: Theme.textPrimary } }
                    textFromValue: function(value) { return value.toString().padStart(2, '0') }
                }

                Text { text: ":"; font.pixelSize: 20; font.bold: true; color: Theme.textPrimary }

                SpinBox {
                    id: minuteSpin
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 36
                    from: 0; to: 59; stepSize: 5
                    value: manualRecordDialog.startMinute
                    onValueChanged: manualRecordDialog.startMinute = value
                    editable: true
                    background: Rectangle { radius: Theme.borderRadiusSmall; color: Theme.surface; border.color: Theme.surfaceBorder; border.width: 1 }
                    contentItem: TextInput { text: minuteSpin.textFromValue(minuteSpin.value, minuteSpin.locale); font.pixelSize: Theme.fontSizeMd; font.bold: true; color: Theme.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; readOnly: !minuteSpin.editable; validator: minuteSpin.validator; inputMethodHints: Qt.ImhDigitsOnly; selectionColor: Theme.accent }
                    up.indicator: Rectangle { x: parent.width - width; width: 24; height: parent.height; radius: Theme.borderRadiusSmall; color: minuteSpin.up.pressed ? Theme.accent : Theme.surfaceHover; Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 16; font.bold: true; color: Theme.textPrimary } }
                    down.indicator: Rectangle { x: 0; width: 24; height: parent.height; radius: Theme.borderRadiusSmall; color: minuteSpin.down.pressed ? Theme.accent : Theme.surfaceHover; Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 16; font.bold: true; color: Theme.textPrimary } }
                    textFromValue: function(value) { return value.toString().padStart(2, '0') }
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
                                ? Theme.textOnAccent : Theme.textSecondary
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
                    color: startRecHov ? Theme.accentHover : Theme.accent
                    opacity: manualRecordDialog.selectedChannelId > 0 ? 1.0 : 0.4
                    property bool startRecHov: false
                    Text {
                        id: startRecText
                        anchors.centerIn: parent
                        text: manualRecordDialog.startNow ? "Start Recording" : "Schedule"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: Theme.textOnAccent
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: manualRecordDialog.selectedChannelId > 0 ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onEntered: parent.startRecHov = true; onExited: parent.startRecHov = false
                        onClicked: {
                            if (manualRecordDialog.selectedChannelId > 0 && appViewModel) {
                                var startEpoch
                                if (manualRecordDialog.startNow) {
                                    startEpoch = Math.floor(Date.now() / 1000)
                                } else {
                                    var now = new Date()
                                    var d = new Date(now.getTime() + manualRecordDialog.startDay * 86400000)
                                    d.setHours(manualRecordDialog.startHour, manualRecordDialog.startMinute, 0, 0)
                                    startEpoch = Math.floor(d.getTime() / 1000)
                                }
                                var endEpoch = startEpoch + manualRecordDialog.durationMinutes * 60
                                if (manualRecordDialog.startNow) {
                                    appViewModel.recordingList.startNow(
                                        manualRecordDialog.selectedChannelId,
                                        manualRecordDialog.durationMinutes * 60, "original")
                                } else {
                                    appViewModel.recordingList.scheduleRecording(manualRecordDialog.selectedChannelId, startEpoch, endEpoch, "original")
                                }
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
            startNow = true
            startDay = 0
            var now = new Date()
            startHour = now.getHours()
            startMinute = now.getMinutes()
            channelCombo.currentIndex = -1
            if (appViewModel) {
                appViewModel.channelList.typeFilter = "live"
                var primary = appViewModel.serverList.primaryServerIndex()
                var idx = primary >= 0 ? primary : 0
                serverCombo.currentIndex = -1
                serverCombo.currentIndex = idx
            }
        }

        onClosed: {
            if (appViewModel)
                appViewModel.channelList.typeFilter = ""
        }
    }

    Rectangle {
        id: deleteConfirmDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 200

        property int recordingId: 0
        property string recordingName: ""

        MouseArea {
            anchors.fill: parent
            onClicked: deleteConfirmDialog.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: confirmCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.surfaceBorder
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: confirmCol
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                Text {
                    text: "Delete Recording"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: "Are you sure you want to delete this recording?\nThe file will be permanently removed from disk."
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    lineHeight: 1.4
                }

                Text {
                    text: deleteConfirmDialog.recordingName
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: cancelBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: cancelBtnHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        property bool cancelBtnHov: false

                        Text {
                            id: cancelBtnText
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.cancelBtnHov = true
                            onExited: parent.cancelBtnHov = false
                            onClicked: deleteConfirmDialog.visible = false
                        }
                    }

                    Rectangle {
                        width: deleteBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: deleteBtnHov ? Qt.darker(Theme.error, 1.2) : Theme.error

                        property bool deleteBtnHov: false

                        Text {
                            id: deleteBtnText
                            anchors.centerIn: parent
                            text: "Delete"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.deleteBtnHov = true
                            onExited: parent.deleteBtnHov = false
                            onClicked: {
                                if (appViewModel) {
                                    appViewModel.recordingList.deleteRecordingWithFile(deleteConfirmDialog.recordingId)
                                    appViewModel.recordingList.refresh()
                                }
                                deleteConfirmDialog.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: noFileToast
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: toastText.implicitWidth + 32
        height: 36
        radius: 18
        color: Theme.surfaceElevated
        border.color: Theme.surfaceBorder
        border.width: 1
        opacity: 0
        z: 100

        function show() {
            opacity = 1
            toastHideTimer.restart()
        }

        Behavior on opacity { NumberAnimation { duration: 300 } }

        Timer {
            id: toastHideTimer
            interval: 2500
            onTriggered: noFileToast.opacity = 0
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            text: "No local file available — recording was uploaded to Google Drive"
            font.pixelSize: Theme.fontSizeXs
            color: Theme.textSecondary
        }
    }
}
