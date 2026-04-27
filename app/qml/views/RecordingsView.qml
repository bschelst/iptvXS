// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: recordingsView

    function focusPrimary() {
        if (recordingSectionRepeater && recordingSectionRepeater.count > 0) {
            for (var i = 0; i < recordingSectionRepeater.count; i++) {
                var section = recordingSectionRepeater.itemAt(i)
                if (section && section.rowItems && section.rowItems.length > 0) {
                    section.focusCardAt(section.currentCardIndex >= 0 ? section.currentCardIndex : 0)
                    return
                }
            }
        }
        if (newRecButton) {
            newRecButton.forceActiveFocus()
        }
    }

    function focusAdjacentSection(sectionIdx, currentCardIdx, delta) {
        if (!recordingSectionRepeater) return
        for (var i = sectionIdx + delta;
             i >= 0 && i < recordingSectionRepeater.count;
             i += delta) {
            var section = recordingSectionRepeater.itemAt(i)
            if (section && section.rowItems && section.rowItems.length > 0) {
                var targetCard = Math.min(currentCardIdx, section.rowItems.length - 1)
                section.focusCardAt(targetCard)
                ensureSectionVisible(section)
                return
            }
        }
    }

    function ensureSectionVisible(section) {
        if (!recordingsFlickable || !section) return
        var sectionY = section.mapToItem(recordingsColumn, 0, 0).y
        var viewTop = recordingsFlickable.contentY
        var viewBottom = viewTop + recordingsFlickable.height
        if (sectionY < viewTop) {
            recordingsFlickable.contentY = Math.max(0, sectionY - 20)
        } else if (sectionY + 286 > viewBottom) {
            recordingsFlickable.contentY = Math.min(
                recordingsFlickable.contentHeight - recordingsFlickable.height,
                sectionY + 286 - recordingsFlickable.height + 20)
        }
    }

    function ensureCardVisible(section, cardIndex) {
        if (!section) return
        var rowFlickable = section.rowFlickable
        if (!rowFlickable) return
        var cardX = Theme.spacingMd + cardIndex * (220 + Theme.spacingSm)
        var viewLeft = rowFlickable.contentX
        var viewRight = viewLeft + rowFlickable.width
        if (cardX < viewLeft) {
            rowFlickable.contentX = Math.max(0, cardX - Theme.spacingMd)
        } else if (cardX + 220 > viewRight) {
            rowFlickable.contentX = Math.min(
                rowFlickable.contentWidth - rowFlickable.width,
                cardX + 220 - rowFlickable.width + Theme.spacingMd)
        }
    }

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
                    id: newRecButton
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

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                            manualRecordDialog.open()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            recordingsView.focusPrimary()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left) {
                            if (Window.window && Window.window.focusSidebar) {
                                Window.window.focusSidebar()
                            }
                            event.accepted = true
                        }
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

        Flickable {
            id: recordingsFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: recordingsColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: recordingsColumn
                width: parent.width
                spacing: Theme.spacingMd

                Repeater {
                    id: recordingSectionRepeater
                    model: {
                        var rev = appViewModel ? appViewModel.recordingList.modelRevision : 0
                        return appViewModel ? appViewModel.recordingList.recordingSections() : []
                    }

                    delegate: Column {
                        id: recordingSection
                        property int sectionIdx: index
                        width: recordingsColumn.width
                        spacing: Theme.spacingSm

                        property string sectionName: modelData
                        property var rowItems: appViewModel
                            ? ((appViewModel.recordingList.modelRevision, appViewModel.recordingList.recordingsForSection(sectionName)))
                            : []
                        property int currentCardIndex: 0
                        property alias rowFlickable: rowListView

                        function focusCardAt(i) {
                            if (!rowRepeater || rowItems.length <= 0) return
                            currentCardIndex = Math.max(0, Math.min(i, rowItems.length - 1))
                            var item = rowRepeater.itemAt(currentCardIndex)
                            if (item) {
                                item.forceActiveFocus()
                                recordingsView.ensureCardVisible(recordingSection, currentCardIndex)
                                recordingsView.ensureSectionVisible(recordingSection)
                            }
                        }

                        Item {
                            width: parent.width
                            height: 36

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingMd
                                anchors.verticalCenter: parent.verticalCenter
                                text: sectionName
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingSm
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: recScrollLeftHov ? Theme.surfaceHover : "transparent"
                                    property bool recScrollLeftHov: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u2039"
                                        font.pixelSize: 22
                                        font.bold: true
                                        color: parent.recScrollLeftHov ? Theme.textPrimary : Theme.textMuted
                                    }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.recScrollLeftHov = true
                                            onExited: parent.recScrollLeftHov = false
                                            onClicked: rowListView.contentX = Math.max(rowListView.contentX - 260, 0)
                                        }
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: recScrollRightHov ? Theme.surfaceHover : "transparent"
                                    property bool recScrollRightHov: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u203A"
                                        font.pixelSize: 22
                                        font.bold: true
                                        color: parent.recScrollRightHov ? Theme.textPrimary : Theme.textMuted
                                    }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.recScrollRightHov = true
                                            onExited: parent.recScrollRightHov = false
                                            onClicked: rowListView.contentX = Math.min(
                                                rowListView.contentX + 260,
                                                Math.max(0, rowListView.contentWidth - rowListView.width))
                                        }
                                }
                            }
                        }

                        Flickable {
                            id: rowListView
                            width: parent.width
                            height: 286
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            interactive: false
                            contentWidth: rowContent.width + rowContent.x + Theme.spacingMd
                            contentHeight: height

                            Row {
                                id: rowContent
                                x: Theme.spacingMd
                                spacing: Theme.spacingSm

                                Repeater {
                                    id: rowRepeater
                                    model: rowItems

                                    delegate: FocusScope {
                                        id: recordingCard
                                        width: 220
                                        height: 272
                                        focus: recordingSection.currentCardIndex === cardIndex
                                        activeFocusOnTab: true

                                        property int cardIndex: index

                                        readonly property bool playable:
                                            (modelData.status === "completed" || modelData.status === "uploaded")
                                            && modelData.filePath && modelData.filePath.length > 0
                                        readonly property bool isUploading:
                                            modelData.status === "uploading" && appViewModel && appViewModel.gdrive.uploading

                                        function openRecording() {
                                            if (!appViewModel) return
                                            if (playable) {
                                                appViewModel.pendingPlayUrl = modelData.filePath
                                                appViewModel.pendingPlayName = modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                    ? modelData.programmeTitle
                                                    : modelData.channelName
                                                appViewModel.currentView = "player"
                                            } else if (modelData.status === "recording" && appViewModel.player.recording) {
                                                appViewModel.player.stopStreamRecord()
                                            }
                                        }

                                        function requestDelete() {
                                            if (!appViewModel) return
                                            if (modelData.status === "uploaded" && modelData.filePath && modelData.filePath.length > 0) {
                                                deleteLocalDialog.recordingId = modelData.recordingId
                                                deleteLocalDialog.recordingName = modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                    ? modelData.programmeTitle
                                                    : modelData.channelName
                                                deleteLocalDialog.visible = true
                                            } else {
                                                deleteConfirmDialog.recordingId = modelData.recordingId
                                                deleteConfirmDialog.recordingName = modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                    ? modelData.programmeTitle
                                                    : modelData.channelName
                                                deleteConfirmDialog.visible = true
                                            }
                                        }

                                        function togglePinned() {
                                            if (!appViewModel || !appViewModel.recordingList) return
                                            appViewModel.recordingList.togglePin(modelData.recordingId)
                                        }

                                        Keys.onPressed: function(event) {
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                                    || event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                                                openRecording()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                                                requestDelete()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Left) {
                                                if (cardIndex > 0) {
                                                    recordingSection.focusCardAt(cardIndex - 1)
                                                } else {
                                                    if (Window.window && Window.window.focusSidebar) {
                                                        Window.window.focusSidebar()
                                                    }
                                                }
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Right) {
                                                if (cardIndex < rowItems.length - 1) {
                                                    recordingSection.focusCardAt(cardIndex + 1)
                                                }
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Up) {
                                                recordingsView.focusAdjacentSection(sectionRepeaterIndex, cardIndex, -1)
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Down) {
                                                recordingsView.focusAdjacentSection(sectionRepeaterIndex, cardIndex, 1)
                                                event.accepted = true
                                            }
                                        }

                                        property int sectionRepeaterIndex: recordingSection.sectionIdx

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: {
                                                recordingSection.currentCardIndex = cardIndex
                                                recordingCard.forceActiveFocus()
                                            }
                                            onClicked: {
                                                recordingSection.currentCardIndex = cardIndex
                                                openRecording()
                                            }
                                            cursorShape: recordingCard.playable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.borderRadiusLarge
                                            color: recordingCard.activeFocus || recordingSection.currentCardIndex === cardIndex
                                                ? Theme.surfaceHover : Theme.surfaceElevated
                                            border.width: 1
                                            border.color: {
                                                if (recordingSection.currentCardIndex === cardIndex || recordingCard.activeFocus) return Theme.accent
                                                if (modelData.pinned) return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.50)
                                                if (modelData.status === "recording") return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.38)
                                                return Theme.surfaceBorder
                                            }

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.spacingSm
                                                spacing: Theme.spacingSm

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 110
                                                    radius: Theme.borderRadius
                                                    clip: true
                                                    color: {
                                                        switch (modelData.status) {
                                                        case "recording": return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.09)
                                                        case "scheduled": return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.09)
                                                        case "completed": return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.09)
                                                        case "uploading": return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.09)
                                                        case "uploaded": return Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.09)
                                                        case "failed": return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.06)
                                                        default: return Theme.surface
                                                        }
                                                    }

                                                    Image {
                                                        id: recThumb
                                                        anchors.fill: parent
                                                        source: modelData.thumbnailUrl && modelData.thumbnailUrl.indexOf("http") === 0
                                                            ? modelData.thumbnailUrl : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        visible: status === Image.Ready
                                                        cache: true
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: !recThumb.visible
                                                        color: "transparent"
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "REC"
                                                            font.pixelSize: Theme.fontSizeSm
                                                            font.bold: true
                                                            color: Theme.textSecondary
                                                        }
                                                    }

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.margins: 8
                                                        radius: 10
                                                        height: 20
                                                        width: statusTag.implicitWidth + 16
                                                        color: (modelData.status === "uploaded" || modelData.status === "completed")
                                                            ? Theme.success
                                                            : (modelData.status === "failed" ? Theme.error : Theme.accent)

                                                        Text {
                                                            id: statusTag
                                                            anchors.centerIn: parent
                                                            text: modelData.status
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            font.capitalization: Font.AllUppercase
                                                            color: (modelData.status === "uploaded" || modelData.status === "completed")
                                                                ? "#000000"
                                                                : Theme.textOnAccent
                                                        }
                                                    }

                                                    Rectangle {
                                                        visible: modelData.pinned
                                                        anchors.right: parent.right
                                                        anchors.top: parent.top
                                                        anchors.margins: 8
                                                        radius: 10
                                                        height: 20
                                                        width: pinText.implicitWidth + 16
                                                        color: Theme.accent
                                                        Text {
                                                            id: pinText
                                                            anchors.centerIn: parent
                                                            text: "📌"
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            color: Theme.textOnAccent
                                                        }
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 0

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                            ? modelData.programmeTitle
                                                            : modelData.channelName
                                                        font.pixelSize: Theme.fontSizeSm
                                                        font.bold: true
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        visible: modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                        text: modelData.channelName
                                                        font.pixelSize: Theme.fontSizeXs
                                                        color: Theme.textSecondary
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: appViewModel ? appViewModel.recordingList.formatDateTime(modelData.startTime) : ""
                                                        font.pixelSize: Theme.fontSizeXs
                                                        color: Theme.textMuted
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: modelData.status === "uploaded" && modelData.filePath && modelData.filePath.length > 0 ? 78 : 50
                                                    radius: 12
                                                    color: Theme.surfaceElevated
                                                    border.width: 1
                                                    border.color: Theme.surfaceBorder
                                                    clip: true

                                                    ColumnLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: Theme.spacingSm
                                                        spacing: Theme.spacingXs

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: Theme.spacingXs

                                                            Rectangle {
                                                                visible: recordingCard.playable
                                                                Layout.preferredWidth: 58
                                                                Layout.preferredHeight: 28
                                                                radius: 14
                                                                color: openHov ? Theme.accentHover : Theme.accent
                                                                property bool openHov: false
                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: "Open"
                                                                    font.pixelSize: Theme.fontSizeXs
                                                                    font.bold: true
                                                                    color: Theme.textOnAccent
                                                                }
                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.openHov = true
                                                                    onExited: parent.openHov = false
                                                                    onClicked: recordingCard.openRecording()
                                                                }
                                                            }

                                                            Rectangle {
                                                                Layout.preferredWidth: 52
                                                                Layout.preferredHeight: 28
                                                                radius: 14
                                                                color: modelData.pinned ? Theme.accent : (pinHov ? Theme.surfaceHover : Theme.surfaceElevated)
                                                                border.width: 1
                                                                border.color: modelData.pinned ? Theme.accent : Theme.surfaceBorder
                                                                property bool pinHov: false
                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: modelData.pinned ? "Pinned" : "Pin"
                                                                    font.pixelSize: Theme.fontSizeXs
                                                                    font.bold: true
                                                                    color: modelData.pinned ? Theme.textOnAccent : Theme.textPrimary
                                                                }
                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.pinHov = true
                                                                    onExited: parent.pinHov = false
                                                                    onClicked: recordingCard.togglePinned()
                                                                }
                                                            }

                                                            Rectangle {
                                                                Layout.preferredWidth: 54
                                                                Layout.preferredHeight: 28
                                                                radius: 14
                                                                color: deleteHov ? Theme.error : Theme.error
                                                                border.width: 1
                                                                border.color: Theme.error
                                                                property bool deleteHov: false
                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: "Delete"
                                                                    font.pixelSize: Theme.fontSizeXs
                                                                    font.bold: true
                                                                    color: Theme.textOnAccent
                                                                }
                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.deleteHov = true
                                                                    onExited: parent.deleteHov = false
                                                                    onClicked: recordingCard.requestDelete()
                                                                }
                                                            }
                                                        }

                                                        Rectangle {
                                                            visible: modelData.status === "uploaded" && modelData.filePath && modelData.filePath.length > 0
                                                            Layout.fillWidth: true
                                                            Layout.preferredHeight: 26
                                                            Layout.bottomMargin: Theme.spacingSm
                                                            radius: 14
                                                            color: localDeleteHov ? Theme.surfaceHover : Theme.surfaceElevated
                                                            border.width: 1
                                                            border.color: Theme.surfaceBorder
                                                            property bool localDeleteHov: false

                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "Delete File"
                                                                font.pixelSize: Theme.fontSizeXs
                                                                font.bold: true
                                                                color: Theme.textPrimary
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onEntered: parent.localDeleteHov = true
                                                                onExited: parent.localDeleteHov = false
                                                                onClicked: {
                                                                    deleteLocalDialog.recordingId = modelData.recordingId
                                                                    deleteLocalDialog.recordingName = modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                                        ? modelData.programmeTitle
                                                                        : modelData.channelName
                                                                    deleteLocalDialog.visible = true
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: recordingsColumn.children.length <= 0 || (appViewModel && appViewModel.recordingList.count === 0)
                    text: "No recordings yet.\nUse the record button on any channel\nor click '+ Record' to schedule one."
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.5
                }
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
        property var channelChoices: []

        function refreshChannelChoices() {
            if (!appViewModel) {
                channelChoices = []
                selectedChannelId = 0
                return
            }
            if (serverCombo.currentIndex < 0) {
                channelChoices = []
                selectedChannelId = 0
                return
            }
            var srvId = appViewModel.serverList.serverIdAt(serverCombo.currentIndex)
            channelChoices = srvId > 0
                ? appViewModel.channelList.channelsForServerAndType(srvId, "live")
                : []
            channelCombo.currentIndex = -1
            selectedChannelId = 0
        }

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
                    manualRecordDialog.refreshChannelChoices()
                }
            }

            Text { text: "Channel"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }

            ComboBox {
                id: channelCombo
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                model: manualRecordDialog.channelChoices
                textRole: "name"
                currentIndex: -1
                displayText: currentIndex >= 0 ? currentText : "Select a channel..."
                background: Rectangle { radius: Theme.borderRadiusSmall; color: Theme.surface; border.color: Theme.surfaceBorder; border.width: 1 }
                contentItem: Text { leftPadding: Theme.spacingSm; text: channelCombo.displayText; font.pixelSize: Theme.fontSizeSm; color: channelCombo.currentIndex >= 0 ? Theme.textPrimary : Theme.textMuted; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                delegate: ItemDelegate {
                    width: channelCombo.width
                    contentItem: Text {
                        text: modelData.isFavorite ? "★ " + modelData.name : modelData.name
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: modelData.isFavorite
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
                    if (currentIndex >= 0 && manualRecordDialog.channelChoices.length > currentIndex) {
                        manualRecordDialog.selectedChannelId =
                            manualRecordDialog.channelChoices[currentIndex].channelId
                    } else {
                        manualRecordDialog.selectedChannelId = 0
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
                    width: modeLabel.implicitWidth + Theme.spacingMd * 2
                    height: 32
                    radius: Theme.borderRadiusSmall
                    color: manualRecordDialog.startNow === modelData.value
                        ? Theme.accent
                        : startModeHov ? Theme.surfaceHover : Theme.surface
                    border.width: 1
                    border.color: manualRecordDialog.startNow === modelData.value ? Theme.accent : Theme.surfaceBorder
                    property bool startModeHov: false

                    Text {
                        id: modeLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: manualRecordDialog.startNow === modelData.value
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
                        width: durationLabel.implicitWidth + Theme.spacingMd * 2
                        height: 32
                        radius: Theme.borderRadiusSmall
                        color: manualRecordDialog.durationMinutes === modelData.value
                            ? Theme.accent
                            : durationHov ? Theme.surfaceHover : Theme.surface
                        border.width: 1
                        border.color: manualRecordDialog.durationMinutes === modelData.value ? Theme.accent : Theme.surfaceBorder
                        property bool durationHov: false

                        Text {
                            id: durationLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeXs
                            font.bold: manualRecordDialog.durationMinutes === modelData.value
                            color: manualRecordDialog.durationMinutes === modelData.value ? Theme.textOnAccent : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.durationHov = true
                            onExited: parent.durationHov = false
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
                    width: cancelRecordLabel.implicitWidth + Theme.spacingLg * 2
                    height: 36
                    radius: Theme.borderRadius
                    color: cancelRecordHov ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.surfaceBorder
                    border.width: 1
                    property bool cancelRecordHov: false

                    Text {
                        id: cancelRecordLabel
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.cancelRecordHov = true
                        onExited: parent.cancelRecordHov = false
                        onClicked: manualRecordDialog.close()
                    }
                }

                Rectangle {
                    id: startRecordButton
                    width: startRecordLabel.implicitWidth + Theme.spacingLg * 2
                    height: 36
                    radius: Theme.borderRadius
                    color: !enabled ? Theme.surfaceElevated : (startRecordHov ? Theme.accentHover : Theme.accent)
                    opacity: enabled ? 1.0 : 0.4
                    property bool startRecordHov: false
                    property bool enabled: manualRecordDialog.selectedChannelId > 0

                    Text {
                        id: startRecordLabel
                        anchors.centerIn: parent
                        text: manualRecordDialog.startNow ? "Start Recording" : "Schedule"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: parent.enabled ? Theme.textOnAccent : Theme.textMuted
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onEntered: parent.startRecordHov = true
                        onExited: parent.startRecordHov = false
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
                var primary = appViewModel.serverList.primaryServerIndex()
                var idx = primary >= 0 ? primary : 0
                serverCombo.currentIndex = -1
                serverCombo.currentIndex = idx
            }
            refreshChannelChoices()
            serverCombo.forceActiveFocus()
        }

        onClosed: {
            channelChoices = []
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
        id: deleteLocalDialog
        visible: false
        anchors.fill: parent
        color: "#C0000000"
        z: 200

        property int recordingId: 0
        property string recordingName: ""

        MouseArea {
            anchors.fill: parent
            onClicked: deleteLocalDialog.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: localConfirmCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.surfaceBorder
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: localConfirmCol
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingMd

                Text {
                    text: "Delete Local File"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: "Remove the downloaded file from disk and keep the recording entry in the library."
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    lineHeight: 1.4
                }

                Text {
                    text: deleteLocalDialog.recordingName
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
                        width: cancelLocalBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: cancelLocalBtnHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        property bool cancelLocalBtnHov: false

                        Text {
                            id: cancelLocalBtnText
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.cancelLocalBtnHov = true
                            onExited: parent.cancelLocalBtnHov = false
                            onClicked: deleteLocalDialog.visible = false
                        }
                    }

                    Rectangle {
                        width: deleteLocalBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: deleteLocalBtnHov ? Qt.darker(Theme.error, 1.2) : Theme.error

                        property bool deleteLocalBtnHov: false

                        Text {
                            id: deleteLocalBtnText
                            anchors.centerIn: parent
                            text: "Delete File"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.deleteLocalBtnHov = true
                            onExited: parent.deleteLocalBtnHov = false
                            onClicked: {
                                if (appViewModel) {
                                    appViewModel.recordingList.deleteLocalFile(deleteLocalDialog.recordingId)
                                }
                                deleteLocalDialog.visible = false
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
