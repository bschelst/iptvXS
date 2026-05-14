// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: recordingsView

    readonly property var filterValues: ["", "recording", "scheduled", "completed", "uploading", "uploaded", "failed"]
    property bool focusRestorePending: false
    property int focusRestoreAttempts: 0

    function cycleFilter(direction) {
        if (!appViewModel) return
        var current = appViewModel.recordingList.filterStatus
        var idx = filterValues.indexOf(current)
        if (idx < 0) idx = 0
        idx = (idx + direction + filterValues.length) % filterValues.length
        appViewModel.recordingList.filterStatus = filterValues[idx]
    }

    function focusPrimary() {
        focusFirstRecordingCard()
    }

    function focusFirstRecordingCard() {
        for (var i = 0; i < recordingSectionRepeater.count; i++) {
            var section = recordingSectionRepeater.itemAt(i)
            if (section && section.rowItems && section.rowItems.length > 0) {
                section.focusCardAt(0)
                return
            }
        }
        focusHeaderStrip()
    }

    function requestFocusRestore() {
        focusRestorePending = true
        focusRestoreAttempts = 0
        focusRestoreTimer.restart()
    }

    function tryRestoreFocus() {
        if (!focusRestorePending) return
        if (!appViewModel || appViewModel.currentView !== "recordings") {
            focusRestorePending = false
            return
        }
        if (!recordingSectionRepeater || recordingSectionRepeater.count === 0) {
            if (++focusRestoreAttempts < 40) {
                focusRestoreTimer.restart()
            } else {
                focusRestorePending = false
            }
            return
        }

        for (var i = 0; i < recordingSectionRepeater.count; i++) {
            var section = recordingSectionRepeater.itemAt(i)
            if (section && section.rowItems && section.rowItems.length > 0) {
                section.focusCardAt(0)
                focusRestorePending = false
                return
            }
        }

        if (++focusRestoreAttempts < 40) {
            focusRestoreTimer.restart()
        } else {
            focusRestorePending = false
        }
    }

    function focusFilterStrip() {
        if (filterRepeater && filterRepeater.count > 0) {
            var currentFilter = appViewModel ? appViewModel.recordingList.filterStatus : ""
            for (var i = 0; i < filterRepeater.count; i++) {
                var filterItem = filterRepeater.itemAt(i)
                if (filterItem && filterItem.filterValue === currentFilter) {
                    filterItem.forceActiveFocus()
                    return
                }
            }
            var firstFilter = filterRepeater.itemAt(0)
            if (firstFilter) {
                firstFilter.forceActiveFocus()
                return
            }
        }
        if (newRecButton) newRecButton.forceActiveFocus()
    }

    function focusHeaderStrip() {
        if (newRecButton) {
            newRecButton.forceActiveFocus()
            return
        }
        focusFilterStrip()
    }

    function focusAdjacentSection(sectionIdx, currentCardIdx, delta) {
        if (!recordingSectionRepeater) return
        for (var i = sectionIdx + delta;
             i >= 0 && i < recordingSectionRepeater.count;
             i += delta) {
            var section = recordingSectionRepeater.itemAt(i)
            if (section && section.rowItems && section.rowItems.length > 0) {
                var targetCard = Math.max(0, Math.min(currentCardIdx, section.rowItems.length - 1))
                section.focusCardAt(targetCard)
                ensureSectionVisible(section)
                return
            }
        }
        if (delta < 0) {
            if (Window.window && Window.window.focusSidebar) {
                Window.window.focusSidebar()
            } else {
                recordingsView.focusFilterStrip()
            }
            recordingsFlickable.contentY = 0
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

    function hasLocalRecordingFile(filePath) {
        return appViewModel && filePath && filePath.length > 0 && appViewModel.fileExists(filePath)
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
                    color: newRecBtnHov || newRecButton.activeFocus ? Theme.accent : Theme.accentHover
                    focus: false
                    activeFocusOnTab: true

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
                            recordingsView.focusFilterStrip()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Left) {
                            if (Window.window && Window.window.focusSidebar) {
                                Window.window.focusSidebar()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Right) {
                            if (filterRepeater && filterRepeater.count > 0) {
                                var firstFilter = filterRepeater.itemAt(0)
                                if (firstFilter) firstFilter.forceActiveFocus()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
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
                        id: filterRepeater
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
                            id: filterChip
                            width: filterLabel.implicitWidth + Theme.spacingMd * 2
                            height: 28
                            radius: 14
                            property string filterValue: modelData.value
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

                            Keys.onLeftPressed: {
                                if (index > 0) {
                                    var prev = filterRepeater.itemAt(index - 1)
                                    if (prev) prev.forceActiveFocus()
                                } else if (newRecButton) {
                                    newRecButton.forceActiveFocus()
                                }
                            }
                            Keys.onRightPressed: {
                                if (index < filterRepeater.count - 1) {
                                    var next = filterRepeater.itemAt(index + 1)
                                    if (next) next.forceActiveFocus()
                                }
                            }
                            Keys.onDownPressed: {
                                recordingsView.focusPrimary()
                            }
                            Keys.onUpPressed: {
                                if (Window.window && Window.window.focusSidebar) {
                                    Window.window.focusSidebar()
                                }
                            }
                            Keys.onReturnPressed: {
                                if (appViewModel) {
                                    appViewModel.recordingList.filterStatus = modelData.value
                                }
                            }
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    if (appViewModel) {
                                        appViewModel.recordingList.filterStatus = modelData.value
                                    }
                                    event.accepted = true
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
                        property int currentCardIndex: -1
                        property alias rowFlickable: rowListView

                        function snapRowContent(direction) {
                            if (!rowListView || rowRepeater.count <= 0) return

                            var step = 220 + rowContent.spacing
                            if (step <= 0) return

                            var minX = 0
                            var maxX = Math.max(minX, rowListView.contentWidth - rowListView.width)
                            var current = rowListView.contentX
                            var target

                            if (direction < 0) {
                                target = Math.floor((current - minX - 0.001) / step) * step
                            } else {
                                target = Math.ceil((current - minX + 0.001) / step) * step
                            }

                            target = Math.max(minX, Math.min(maxX, target))
                            rowListView.contentX = target
                        }

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
                                    id: recScrollLeftBtn
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: recScrollLeftHov || recScrollLeftBtn.activeFocus ? Theme.surfaceHover : "transparent"
                                    property bool recScrollLeftHov: false
                                    focus: false
                                    activeFocusOnTab: true

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
                                            onClicked: recordingSection.snapRowContent(-1)
                                        }

                                        Keys.onRightPressed: {
                                            if (recScrollRightBtn) recScrollRightBtn.forceActiveFocus()
                                        }
                                        Keys.onDownPressed: {
                                            if (rowRepeater && rowRepeater.count > 0) {
                                                if (recordingSection.currentCardIndex < 0) recordingSection.currentCardIndex = 0
                                                recordingSection.focusCardAt(recordingSection.currentCardIndex)
                                            }
                                        }
                                        Keys.onReturnPressed: recordingSection.snapRowContent(-1)
                                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                                        Keys.onPressed: function(event) {
                                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                                recordingSection.snapRowContent(-1)
                                                event.accepted = true
                                            }
                                        }
                                }

                                Rectangle {
                                    id: recScrollRightBtn
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: recScrollRightHov || recScrollRightBtn.activeFocus ? Theme.surfaceHover : "transparent"
                                    property bool recScrollRightHov: false
                                    focus: false
                                    activeFocusOnTab: true

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
                                            onClicked: recordingSection.snapRowContent(1)
                                        }

                                        Keys.onLeftPressed: {
                                            if (recScrollLeftBtn) recScrollLeftBtn.forceActiveFocus()
                                        }
                                        Keys.onDownPressed: {
                                            if (rowRepeater && rowRepeater.count > 0) {
                                                if (recordingSection.currentCardIndex < 0) recordingSection.currentCardIndex = 0
                                                recordingSection.focusCardAt(recordingSection.currentCardIndex)
                                            }
                                        }
                                        Keys.onReturnPressed: recordingSection.snapRowContent(1)
                                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                                        Keys.onPressed: function(event) {
                                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                                recordingSection.snapRowContent(1)
                                                event.accepted = true
                                            }
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
                                        property bool cardHovered: false

                                        readonly property bool playable: Boolean(
                                            (modelData.status === "completed" || modelData.status === "uploaded" || modelData.status === "recording")
                                            && ((modelData.filePath && modelData.filePath.length > 0)
                                                || (modelData.gdriveFileId && modelData.gdriveFileId.length > 0))
                                        )
                                        readonly property bool isUploading:
                                            modelData.status === "uploading" && appViewModel && appViewModel.gdrive.uploading

                                        function openRecording() {
                                            if (!appViewModel) return
                                            if (playable) {
                                                // Uploaded recordings: prefer Drive (local file likely deleted)
                                                if (modelData.status === "uploaded" && modelData.gdriveFileId && modelData.gdriveFileId.length > 0) {
                                                    appViewModel.playRecordingFromDrive(modelData.recordingId)
                                                } else if (modelData.filePath && modelData.filePath.length > 0) {
                                                    appViewModel.pendingPlayUrl = modelData.filePath
                                                    appViewModel.pendingPlayName = modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                        ? modelData.programmeTitle
                                                        : modelData.channelName
                                                    appViewModel.currentView = "player"
                                                } else if (modelData.gdriveFileId && modelData.gdriveFileId.length > 0) {
                                                    appViewModel.playRecordingFromDrive(modelData.recordingId)
                                                }
                                            } else if (modelData.status === "recording" && appViewModel.player.recording) {
                                                appViewModel.player.stopStreamRecord()
                                            }
                                        }

                                        function requestDelete() {
                                            if (!appViewModel) return
                                            if (modelData.status === "uploaded" && hasLocalRecordingFile(modelData.filePath)) {
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

                                        function focusCard() {
                                            recordingSection.currentCardIndex = cardIndex
                                            recordingCard.forceActiveFocus()
                                        }

                                        function openActionsPopup() {
                                            recordingActionsPopup.open()
                                        }

                                        function closeRecordingActionsPopup() {
                                            if (recordingActionsPopup && recordingActionsPopup.visible) {
                                                recordingActionsPopup.close()
                                            }
                                        }

                                        function focusNextCard() {
                                            if (cardIndex < rowItems.length - 1) {
                                                recordingSection.focusCardAt(cardIndex + 1)
                                                return true
                                            }
                                            return false
                                        }

                                        function focusPrevCard() {
                                            if (cardIndex > 0) {
                                                recordingSection.focusCardAt(cardIndex - 1)
                                                return true
                                            }
                                            return false
                                        }

                                        function focusSection(delta) {
                                            recordingsView.focusAdjacentSection(sectionRepeaterIndex, cardIndex, delta)
                                        }

                                        Keys.onPressed: function(event) {
                                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                                    || event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                                                openRecording()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                                                requestDelete()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Menu || event.key === Qt.Key_M) {
                                                recordingCard.openActionsPopup()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Left) {
                                                if (recordingActionsPopup.visible) {
                                                    recordingCard.closeRecordingActionsPopup()
                                                } else if (cardIndex > 0) {
                                                    focusPrevCard()
                                                } else {
                                                    if (Window.window && Window.window.focusSidebar) {
                                                        Window.window.focusSidebar()
                                                    }
                                                }
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Right) {
                                                if (recordingActionsPopup.visible) {
                                                    event.accepted = true
                                                    return
                                                } else if (cardIndex < rowItems.length - 1) {
                                                    focusNextCard()
                                                } else {
                                                    recordingCard.openActionsPopup()
                                                }
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Up) {
                                                if (recordingActionsPopup.visible) {
                                                    event.accepted = true
                                                    return
                                            } else if (sectionIdx === 0) {
                                                if (Window.window && Window.window.focusSidebar) {
                                                    Window.window.focusSidebar()
                                                } else {
                                                    recordingsView.focusFilterStrip()
                                                }
                                            } else {
                                                recordingsView.focusAdjacentSection(sectionRepeaterIndex, cardIndex, -1)
                                            }
                                            event.accepted = true
                                            } else if (event.key === Qt.Key_Down) {
                                                if (recordingActionsPopup.visible) {
                                                    event.accepted = true
                                                    return
                                                } else {
                                                    recordingsView.focusAdjacentSection(sectionRepeaterIndex, cardIndex, 1)
                                                }
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Y) {
                                                manualRecordDialog.open()
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_BracketLeft) {
                                                recordingsView.cycleFilter(-1)
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_BracketRight) {
                                                recordingsView.cycleFilter(1)
                                                event.accepted = true
                                            }
                                        }

                                        property int sectionRepeaterIndex: recordingSection.sectionIdx

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: recordingCard.playable ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onEntered: {
                                                recordingCard.cardHovered = true
                                                recordingSection.currentCardIndex = cardIndex
                                                recordingCard.forceActiveFocus()
                                            }
                                            onExited: recordingCard.cardHovered = false
                                            onClicked: {
                                                recordingSection.currentCardIndex = cardIndex
                                                openRecording()
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.borderRadiusLarge
                                            color: recordingCard.activeFocus
                                                ? Theme.surfaceHover : Theme.surfaceElevated
                                            border.width: 1
                                            border.color: {
                                                if (recordingCard.activeFocus) return Theme.accent
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
                                                    Layout.preferredHeight: 128
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

                                                    Image {
                                                        visible: !recThumb.visible
                                                        anchors.centerIn: parent
                                                        width: Math.min(parent.width, parent.height) - 48
                                                        height: width
                                                        source: "qrc:/images/iptvxs_tray.png"
                                                        fillMode: Image.PreserveAspectFit
                                                        asynchronous: false
                                                        cache: true
                                                        opacity: 0.15
                                                    }

                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.margins: 8
                                                        radius: 10
                                                        height: 20
                                                        width: statusRow.implicitWidth + 16
                                                        color: (modelData.status === "uploaded" || modelData.status === "completed")
                                                            ? Theme.success
                                                            : (modelData.status === "failed" ? Theme.error : Theme.accent)

                                                        Row {
                                                            id: statusRow
                                                            anchors.centerIn: parent
                                                            spacing: 4

                                                            Text {
                                                                visible: modelData.status === "uploaded"
                                                                text: "☁"
                                                                font.pixelSize: 11
                                                                font.family: "DejaVu Sans"
                                                                font.bold: true
                                                                color: (modelData.status === "uploaded" || modelData.status === "completed")
                                                                    ? "#000000"
                                                                    : Theme.textOnAccent
                                                            }

                                                            Text {
                                                                text: modelData.status
                                                                font.pixelSize: 10
                                                                font.bold: true
                                                                font.capitalization: Font.AllUppercase
                                                                color: (modelData.status === "uploaded" || modelData.status === "completed")
                                                                    ? "#000000"
                                                                    : Theme.textOnAccent
                                                            }
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
                                                        maximumLineCount: 2
                                                        wrapMode: Text.Wrap
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
                                            }

                                            Rectangle {
                                                id: recMoreBtn
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.margins: 8
                                                width: 26
                                                height: 26
                                                radius: 13
                                                visible: recordingCard.activeFocus || recordingCard.cardHovered || recordingActionsPopup.visible
                                                color: recMoreBtnHov ? Theme.surfaceHover : "transparent"
                                                border.width: 1
                                                border.color: recMoreBtnHov ? Theme.accent : Theme.surfaceBorder
                                                property bool recMoreBtnHov: false

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\u22EE"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    color: Theme.textSecondary
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onEntered: parent.recMoreBtnHov = true
                                                    onExited: parent.recMoreBtnHov = false
                                                    onClicked: recordingCard.openActionsPopup()
                                                }
                                            }
                                        }

                                            Popup {
                                                id: recordingActionsPopup
                                                    parent: recordingsView
                                                    modal: false
                                                    focus: true
                                                    z: 1000
                                                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                                                    x: {
                                                        var cardPos = recordingCard.mapToItem(recordingsView, 0, 0)
                                                        return Math.max(4, Math.min(recordingsView.width - width - 4, cardPos.x + recMoreBtn.x))
                                                    }
                                                    y: {
                                                        var popupH = popupColumn ? popupColumn.implicitHeight + (recordingActionsPopup.padding * 2) : 0
                                                        if (popupH <= 0) {
                                                            popupH = deleteFileAction.visible ? 156 : 108
                                                        }
                                                        var cardPos = recordingCard.mapToItem(recordingsView, 0, 0)
                                                        var below = cardPos.y + recMoreBtn.y + recMoreBtn.height + 4
                                                        var above = cardPos.y + recMoreBtn.y - popupH - 4
                                                        if (below + popupH <= recordingsView.height - 8) {
                                                            return below
                                                        }
                                                        return Math.max(4, above)
                                                    }
                                                    width: 190
                                                    padding: 10

                                                    background: Rectangle {
                                                        radius: 16
                                                        color: Theme.surfaceElevated
                                                        border.color: Theme.surfaceBorder
                                                        border.width: 1
                                                    }

                                                    function closeAndReturn() {
                                                        recordingCard.closeRecordingActionsPopup()
                                                    }

                                                    function handleCancelKey(event) {
                                                        if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                                            recordingCard.closeRecordingActionsPopup()
                                                            event.accepted = true
                                                            return true
                                                        }
                                                        return false
                                                    }

                                                    function firstActionItem() {
                                                        if (stopAction.visible) return stopAction
                                                        if (pinAction.visible) return pinAction
                                                        if (deleteAction.visible) return deleteAction
                                                        if (deleteFileAction.visible) return deleteFileAction
                                                        if (cancelAction.visible) return cancelAction
                                                        return null
                                                    }

                                                    property int popupActionIndex: 0

                                                    function maxActionIndex() {
                                                        var offset = actionOffset()
                                                        return offset + 2 + (deleteFileAction.visible ? 1 : 0)
                                                    }

                                                    function actionOffset() {
                                                        return stopAction.visible ? 1 : 0
                                                    }

                                                    function actionItemForIndex(idx) {
                                                        var offset = actionOffset()
                                                        if (stopAction.visible && idx === 0) return stopAction
                                                        if (idx === offset) return pinAction
                                                        if (idx === offset + 1) return deleteAction
                                                        if (idx === offset + 2 && deleteFileAction.visible) return deleteFileAction
                                                        if (idx === offset + 2 && !deleteFileAction.visible) return cancelAction
                                                        if (idx === offset + 3 && deleteFileAction.visible) return cancelAction
                                                        return null
                                                    }

                                                    function selectAction(idx) {
                                                        var maxIdx = maxActionIndex()
                                                        popupActionIndex = Math.max(0, Math.min(maxIdx, idx))
                                                        var item = actionItemForIndex(popupActionIndex)
                                                        if (item) item.forceActiveFocus()
                                                    }

                                                    onOpened: {
                                                        popupActionIndex = 0
                                                        selectAction(0)
                                                        if (popupFocusRoot) popupFocusRoot.forceActiveFocus()
                                                    }
                                                    onClosed: {
                                                        popupActionIndex = 0
                                                        Qt.callLater(function() {
                                                            if (!recordingCard || !recordingCard.visible) return
                                                            if (recMoreBtn && recMoreBtn.visible) recMoreBtn.forceActiveFocus()
                                                            else recordingCard.forceActiveFocus()
                                                        })
                                                    }

                                                    contentItem: FocusScope {
                                                        id: popupFocusRoot
                                                        implicitWidth: 170
                                                        implicitHeight: popupColumn.implicitHeight
                                                        focus: true

                                                        Keys.onUpPressed: {
                                                            if (popupActionIndex > 0) selectAction(popupActionIndex - 1)
                                                        }
                                                        Keys.onDownPressed: {
                                                            if (popupActionIndex < maxActionIndex()) selectAction(popupActionIndex + 1)
                                                        }
                                                        Keys.onLeftPressed: {
                                                            recordingCard.closeRecordingActionsPopup()
                                                        }
                                                        Keys.onRightPressed: {
                                                            recordingCard.closeRecordingActionsPopup()
                                                        }
                                                        Keys.onReturnPressed: {
                                                            var item = actionItemForIndex(popupActionIndex)
                                                            if (item && item.activateAction) item.activateAction()
                                                        }
                                                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                                                        Keys.onPressed: function(event) {
                                                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                                                var item = actionItemForIndex(popupActionIndex)
                                                                if (item && item.activateAction) item.activateAction()
                                                                event.accepted = true
                                                            } else if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Escape) {
                                                                recordingCard.closeRecordingActionsPopup()
                                                                event.accepted = true
                                                            }
                                                        }

                                                    Column {
                                                        id: popupColumn
                                                        width: parent.width
                                                        spacing: 8

                                                        Rectangle {
                                                                id: stopAction
                                                                visible: modelData.status === "recording"
                                                                width: parent.width
                                                                height: 40
                                                                radius: 12
                                                                activeFocusOnTab: true
                                                                property bool selected: recordingActionsPopup.popupActionIndex === 0
                                                                color: selected ? Theme.surfaceElevated : (stopActionHov ? Theme.error : "#3a1010")
                                                                border.width: selected ? 2 : 1
                                                                border.color: selected ? Theme.error : Theme.error
                                                                property bool stopActionHov: false
                                                                scale: selected ? 1.01 : 1.0

                                                                Text {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 14
                                                                    text: "Stop Recording"
                                                                    font.pixelSize: 11
                                                                    font.bold: true
                                                                    color: stopAction.selected ? Theme.textPrimary : "#ffffff"
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.stopActionHov = true
                                                                    onExited: parent.stopActionHov = false
                                                                    onClicked: {
                                                                        recordingActionsPopup.selectAction(0)
                                                                        if (appViewModel && appViewModel.recordingList) {
                                                                            appViewModel.recordingList.stopRecording(modelData.recordingId)
                                                                        }
                                                                        recordingCard.closeRecordingActionsPopup()
                                                                    }
                                                                }
                                                                function activateAction() {
                                                                    if (appViewModel && appViewModel.recordingList) {
                                                                        appViewModel.recordingList.stopRecording(modelData.recordingId)
                                                                    }
                                                                    recordingCard.closeRecordingActionsPopup()
                                                                }
                                                                Keys.onReturnPressed: {
                                                                    if (stopAction.activateAction) stopAction.activateAction()
                                                                }
                                                                Keys.onPressed: function(event) {
                                                                    recordingActionsPopup.handleCancelKey(event)
                                                                }
                                                            }

                                                        Rectangle {
                                                                id: pinAction
                                                                width: parent.width
                                                                height: 40
                                                                radius: 12
                                                                activeFocusOnTab: true
                                                                property bool selected: recordingActionsPopup.popupActionIndex === 0
                                                                color: selected ? Theme.surfaceElevated : (pinActionHov ? Theme.accent : Theme.surface)
                                                                border.width: selected ? 2 : 1
                                                                border.color: selected ? Theme.accent : (modelData.pinned ? Theme.accent : Theme.surfaceBorder)
                                                                property bool pinActionHov: false
                                                                scale: selected ? 1.01 : 1.0

                                                                Text {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 14
                                                                    text: modelData.pinned ? "Unpin" : "Pin"
                                                                    font.pixelSize: 11
                                                                    font.bold: true
                                                                    color: pinAction.selected ? Theme.textPrimary
                                                                        : (pinAction.pinActionHov ? "#000000" : "#ffffff")
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.pinActionHov = true
                                                                    onExited: parent.pinActionHov = false
                                                                    onClicked: {
                                                                        recordingActionsPopup.selectAction(recordingActionsPopup.actionOffset())
                                                                        recordingCard.togglePinned()
                                                                        recordingCard.closeRecordingActionsPopup()
                                                                    }
                                                                }
                                                                function activateAction() {
                                                                    recordingCard.togglePinned()
                                                                    recordingCard.closeRecordingActionsPopup()
                                                                }
                                                                Keys.onReturnPressed: {
                                                                    if (pinAction.activateAction) pinAction.activateAction()
                                                                }
                                                                Keys.onPressed: function(event) {
                                                                    recordingActionsPopup.handleCancelKey(event)
                                                                }
                                                            }

                                                        Rectangle {
                                                                id: deleteAction
                                                                width: parent.width
                                                                height: 40
                                                                radius: 12
                                                                activeFocusOnTab: true
                                                                property bool selected: recordingActionsPopup.popupActionIndex === 1
                                                                color: selected ? Theme.surfaceElevated : (deleteActionHov ? Theme.error : "#3a1010")
                                                                border.width: selected ? 2 : 1
                                                                border.color: selected ? Theme.error : Theme.error
                                                                property bool deleteActionHov: false
                                                                scale: selected ? 1.01 : 1.0

                                                                Text {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 14
                                                                    text: "Delete Recording"
                                                                    font.pixelSize: 11
                                                                    font.bold: true
                                                                    color: deleteAction.selected ? Theme.textPrimary : "#ffffff"
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.deleteActionHov = true
                                                                    onExited: parent.deleteActionHov = false
                                                                    onClicked: {
                                                                        recordingActionsPopup.selectAction(recordingActionsPopup.actionOffset() + 1)
                                                                        recordingCard.requestDelete()
                                                                        recordingCard.closeRecordingActionsPopup()
                                                                    }
                                                                }
                                                                function activateAction() {
                                                                    recordingCard.requestDelete()
                                                                    recordingCard.closeRecordingActionsPopup()
                                                                }
                                                                Keys.onReturnPressed: {
                                                                    if (deleteAction.activateAction) deleteAction.activateAction()
                                                                }
                                                                Keys.onPressed: function(event) {
                                                                    recordingActionsPopup.handleCancelKey(event)
                                                                }
                                                            }

                                                        Rectangle {
                                                                id: deleteFileAction
                                                                visible: modelData.status === "uploaded"
                                                                    && hasLocalRecordingFile(modelData.filePath)
                                                                width: parent.width
                                                                height: 40
                                                                radius: 12
                                                                activeFocusOnTab: true
                                                                property bool selected: recordingActionsPopup.popupActionIndex === 2
                                                                color: selected ? Theme.surfaceElevated : (deleteFileActionHov ? Theme.surfaceHover : Theme.surface)
                                                                border.width: selected ? 2 : 1
                                                                border.color: selected ? Theme.accent : Theme.surfaceBorder
                                                                property bool deleteFileActionHov: false
                                                                scale: selected ? 1.01 : 1.0

                                                                Text {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 14
                                                                    text: "Delete File"
                                                                    font.pixelSize: 11
                                                                    font.bold: true
                                                                    color: deleteFileAction.selected ? Theme.textPrimary : "#ffffff"
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.deleteFileActionHov = true
                                                                    onExited: parent.deleteFileActionHov = false
                                                                    onClicked: {
                                                                        recordingActionsPopup.selectAction(recordingActionsPopup.actionOffset() + 2)
                                                                        deleteLocalDialog.recordingId = modelData.recordingId
                                                                        deleteLocalDialog.recordingName = modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                                            ? modelData.programmeTitle
                                                                            : modelData.channelName
                                                                        deleteLocalDialog.visible = true
                                                                        recordingCard.closeRecordingActionsPopup()
                                                                    }
                                                                }
                                                                function activateAction() {
                                                                    deleteLocalDialog.recordingId = modelData.recordingId
                                                                    deleteLocalDialog.recordingName = modelData.programmeTitle && modelData.programmeTitle.length > 0
                                                                        ? modelData.programmeTitle
                                                                        : modelData.channelName
                                                                    deleteLocalDialog.visible = true
                                                                    recordingCard.closeRecordingActionsPopup()
                                                                }
                                                                Keys.onReturnPressed: {
                                                                    if (deleteFileAction.activateAction) deleteFileAction.activateAction()
                                                                }
                                                                Keys.onPressed: function(event) {
                                                                    recordingActionsPopup.handleCancelKey(event)
                                                                }
                                                            }

                                                        Rectangle {
                                                                id: cancelAction
                                                                width: parent.width
                                                                height: 40
                                                                radius: 12
                                                                activeFocusOnTab: true
                                                                property bool selected: recordingActionsPopup.popupActionIndex === (deleteFileAction.visible ? 3 : 2)
                                                                color: selected ? Theme.surfaceElevated : (cancelActionHov ? Theme.surfaceHover : Theme.surface)
                                                                border.width: selected ? 2 : 1
                                                                border.color: selected ? Theme.accent : Theme.surfaceBorder
                                                                property bool cancelActionHov: false
                                                                scale: selected ? 1.01 : 1.0

                                                                Text {
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 14
                                                                    text: "Cancel"
                                                                    font.pixelSize: 11
                                                                    font.bold: true
                                                                    color: cancelAction.selected ? Theme.textPrimary : Theme.textPrimary
                                                                }

                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    hoverEnabled: true
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onEntered: parent.cancelActionHov = true
                                                                    onExited: parent.cancelActionHov = false
                                                                    onClicked: recordingCard.closeRecordingActionsPopup()
                                                                }
                                                                function activateAction() {
                                                                    recordingCard.closeRecordingActionsPopup()
                                                                }
                                                                Keys.onReturnPressed: {
                                                                    if (cancelAction.activateAction) cancelAction.activateAction()
                                                                }
                                                                Keys.onPressed: function(event) {
                                                                    recordingActionsPopup.handleCancelKey(event)
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

    Item {
        width: parent.width
        height: 160
        visible: recordingsColumn.children.length <= 0 || (appViewModel && appViewModel.recordingList.count === 0)

                    Text {
                        anchors.centerIn: parent
                        text: "No recordings yet.\nUse the record button on any channel\nor click '+ Record' to schedule one."
                        font.pixelSize: Theme.fontSizeMd
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.5
                    }
                }
            }
    Timer {
        id: focusRestoreTimer
        interval: 75
        repeat: false
        onTriggered: recordingsView.tryRestoreFocus()
    }

    Connections {
        target: appViewModel ? appViewModel.recordingList : null
        function onCountChanged() {
            if (focusRestorePending) requestFocusRestore()
        }
    }

    Component.onCompleted: {
        requestFocusRestore()
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
            if (serverCombo.currentIndex < 0 || serverCombo.currentIndex >= serverCombo.count) {
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
                onCountChanged: {
                    if (count <= 0) {
                        currentIndex = -1
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0
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
                onCountChanged: {
                    if (count <= 0) {
                        currentIndex = -1
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0
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
                    id: startModeRepeater
                    model: [
                        { label: "Now", value: true },
                        { label: "Schedule", value: false }
                    ]

                Rectangle {
                    width: modeLabel.implicitWidth + Theme.spacingMd * 2
                    height: 32
                    radius: Theme.borderRadiusSmall
                    focus: false
                    activeFocusOnTab: true
                    color: manualRecordDialog.startNow === modelData.value
                        ? Theme.accent
                        : startModeHov ? Theme.surfaceHover : Theme.surface
                    border.width: activeFocus || manualRecordDialog.startNow === modelData.value ? 2 : 1
                    border.color: activeFocus || manualRecordDialog.startNow === modelData.value
                        ? Theme.accent
                        : Theme.surfaceBorder
                    property bool startModeHov: false
                    scale: activeFocus ? 1.03 : 1.0

                    onActiveFocusChanged: parent.startModeHov = activeFocus

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

                    Keys.onLeftPressed: {
                        if (index > 0) {
                            var prev = startModeRepeater.itemAt(index - 1)
                            if (prev) prev.forceActiveFocus()
                        }
                    }
                    Keys.onRightPressed: {
                        if (index < startModeRepeater.count - 1) {
                            var next = startModeRepeater.itemAt(index + 1)
                            if (next) next.forceActiveFocus()
                        }
                    }
                    Keys.onUpPressed: {
                        if (channelCombo) channelCombo.forceActiveFocus()
                    }
                    Keys.onDownPressed: {
                        if (manualRecordDialog.startNow) {
                            if (durationRepeater && durationRepeater.count > 0) {
                                var firstDuration = durationRepeater.itemAt(0)
                                if (firstDuration) firstDuration.forceActiveFocus()
                            }
                        } else if (dayCombo) {
                            dayCombo.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: {
                        manualRecordDialog.startNow = modelData.value
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            manualRecordDialog.startNow = modelData.value
                            event.accepted = true
                        }
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
                    Keys.onUpPressed: {
                        if (startModeRepeater && startModeRepeater.count > 0) {
                            var startModeItem = startModeRepeater.itemAt(0)
                            if (startModeItem) startModeItem.forceActiveFocus()
                        }
                    }
                    Keys.onDownPressed: {
                        if (hourSpin) hourSpin.forceActiveFocus()
                    }
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
                    Keys.onLeftPressed: if (dayCombo) dayCombo.forceActiveFocus()
                    Keys.onRightPressed: if (minuteSpin) minuteSpin.forceActiveFocus()
                    Keys.onUpPressed: {
                        if (startModeRepeater && startModeRepeater.count > 0) {
                            var startModeItem = startModeRepeater.itemAt(0)
                            if (startModeItem) startModeItem.forceActiveFocus()
                        }
                    }
                    Keys.onDownPressed: if (minuteSpin) minuteSpin.forceActiveFocus()
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
                    Keys.onLeftPressed: if (hourSpin) hourSpin.forceActiveFocus()
                    Keys.onRightPressed: {
                        if (durationRepeater && durationRepeater.count > 0) {
                            var firstDuration = durationRepeater.itemAt(0)
                            if (firstDuration) firstDuration.forceActiveFocus()
                        }
                    }
                    Keys.onUpPressed: if (hourSpin) hourSpin.forceActiveFocus()
                    Keys.onDownPressed: {
                        if (durationRepeater && durationRepeater.count > 0) {
                            var firstDuration = durationRepeater.itemAt(0)
                            if (firstDuration) firstDuration.forceActiveFocus()
                        }
                    }
                }
            }

            Text { text: "Duration"; font.pixelSize: Theme.fontSizeSm; color: Theme.textSecondary }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Repeater {
                    id: durationRepeater
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
                        focus: false
                        activeFocusOnTab: true
                        color: manualRecordDialog.durationMinutes === modelData.value
                            ? Theme.accent
                            : durationHov ? Theme.surfaceHover : Theme.surface
                        border.width: activeFocus || manualRecordDialog.durationMinutes === modelData.value ? 2 : 1
                        border.color: activeFocus || manualRecordDialog.durationMinutes === modelData.value ? Theme.accent : Theme.surfaceBorder
                        property bool durationHov: false
                        scale: activeFocus ? 1.03 : 1.0

                        onActiveFocusChanged: parent.durationHov = activeFocus

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

                        Keys.onLeftPressed: {
                            if (index > 0) {
                                var prev = durationRepeater.itemAt(index - 1)
                                if (prev) prev.forceActiveFocus()
                            } else if (minuteSpin) {
                                minuteSpin.forceActiveFocus()
                            }
                        }
                        Keys.onRightPressed: {
                            if (index < durationRepeater.count - 1) {
                                var next = durationRepeater.itemAt(index + 1)
                                if (next) next.forceActiveFocus()
                            } else if (cancelRecordButton) {
                                cancelRecordButton.forceActiveFocus()
                            }
                        }
                        Keys.onUpPressed: {
                            if (minuteSpin) {
                                minuteSpin.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: {
                            if (cancelRecordButton) cancelRecordButton.forceActiveFocus()
                        }
                        Keys.onReturnPressed: manualRecordDialog.durationMinutes = modelData.value
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                manualRecordDialog.durationMinutes = modelData.value
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Rectangle {
                    id: cancelRecordButton
                    width: cancelRecordLabel.implicitWidth + Theme.spacingLg * 2
                    height: 36
                    radius: Theme.borderRadius
                    color: cancelRecordHov ? Theme.surfaceHover : Theme.surface
                    property bool cancelRecordHov: false
                    focus: false
                    activeFocusOnTab: true
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Theme.accent : Theme.surfaceBorder
                    onActiveFocusChanged: parent.cancelRecordHov = activeFocus

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

                    Keys.onLeftPressed: {
                        if (durationRepeater && durationRepeater.count > 0) {
                            var lastDuration = durationRepeater.itemAt(durationRepeater.count - 1)
                            if (lastDuration) lastDuration.forceActiveFocus()
                        }
                    }
                    Keys.onRightPressed: if (startRecordButton) startRecordButton.forceActiveFocus()
                    Keys.onUpPressed: {
                        if (durationRepeater && durationRepeater.count > 0) {
                            var lastDuration = durationRepeater.itemAt(durationRepeater.count - 1)
                            if (lastDuration) lastDuration.forceActiveFocus()
                        }
                    }
                    Keys.onDownPressed: if (startRecordButton) startRecordButton.forceActiveFocus()
                    Keys.onReturnPressed: manualRecordDialog.close()
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            manualRecordDialog.close()
                            event.accepted = true
                        }
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
                    focus: false
                    activeFocusOnTab: true
                    border.width: activeFocus ? 2 : 1
                    border.color: activeFocus ? Theme.textOnAccent : Theme.surfaceBorder
                    onActiveFocusChanged: parent.startRecordHov = activeFocus

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

                    Keys.onLeftPressed: if (cancelRecordButton) cancelRecordButton.forceActiveFocus()
                    Keys.onReturnPressed: {
                        if (parent.enabled) {
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
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            Keys.onReturnPressed(event)
                            event.accepted = true
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
            Qt.callLater(function() {
                if (newRecButton) {
                    newRecButton.forceActiveFocus()
                } else {
                    recordingsView.focusPrimary()
                }
            })
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

        function closeDialog() {
            visible = false
            Qt.callLater(function() {
                recordingsView.focusPrimary()
            })
        }

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() {
                    if (cancelBtn) cancelBtn.forceActiveFocus()
                })
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: deleteConfirmDialog.closeDialog()
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
                        id: cancelBtn
                        width: cancelBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: cancelBtnHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        property bool cancelBtnHov: false
                        focus: false
                        activeFocusOnTab: true

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
                            onClicked: deleteConfirmDialog.closeDialog()
                        }

                        Keys.onRightPressed: deleteBtn.forceActiveFocus()
                        Keys.onReturnPressed: deleteConfirmDialog.closeDialog()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                deleteConfirmDialog.closeDialog()
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                    || event.key === Qt.Key_Back) {
                                deleteConfirmDialog.closeDialog()
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        id: deleteBtn
                        width: deleteBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: deleteBtnHov ? Qt.darker(Theme.error, 1.2) : Theme.error

                        property bool deleteBtnHov: false
                        focus: false
                        activeFocusOnTab: true

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
                                deleteConfirmDialog.closeDialog()
                            }
                        }

                        Keys.onLeftPressed: cancelBtn.forceActiveFocus()
                        Keys.onReturnPressed: {
                            if (appViewModel) {
                                appViewModel.recordingList.deleteRecordingWithFile(deleteConfirmDialog.recordingId)
                                appViewModel.recordingList.refresh()
                            }
                            deleteConfirmDialog.closeDialog()
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                if (appViewModel) {
                                    appViewModel.recordingList.deleteRecordingWithFile(deleteConfirmDialog.recordingId)
                                    appViewModel.recordingList.refresh()
                                }
                                deleteConfirmDialog.closeDialog()
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                    || event.key === Qt.Key_Back) {
                                deleteConfirmDialog.closeDialog()
                                event.accepted = true
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

        function closeDialog() {
            visible = false
            Qt.callLater(function() {
                recordingsView.focusPrimary()
            })
        }

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(function() {
                    if (cancelLocalBtn) cancelLocalBtn.forceActiveFocus()
                })
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: deleteLocalDialog.closeDialog()
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
                        id: cancelLocalBtn
                        width: cancelLocalBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: cancelLocalBtnHov ? Theme.surfaceHover : Theme.surface
                        border.color: Theme.surfaceBorder
                        border.width: 1
                        property bool cancelLocalBtnHov: false
                        focus: false
                        activeFocusOnTab: true

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
                            onClicked: deleteLocalDialog.closeDialog()
                        }

                        Keys.onRightPressed: deleteLocalBtn.forceActiveFocus()
                        Keys.onReturnPressed: deleteLocalDialog.closeDialog()
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                deleteLocalDialog.closeDialog()
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                    || event.key === Qt.Key_Back) {
                                deleteLocalDialog.closeDialog()
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        id: deleteLocalBtn
                        width: deleteLocalBtnText.implicitWidth + 24
                        height: 36
                        radius: Theme.borderRadius
                        color: deleteLocalBtnHov ? Qt.darker(Theme.error, 1.2) : Theme.error

                        property bool deleteLocalBtnHov: false
                        focus: false
                        activeFocusOnTab: true

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
                                deleteLocalDialog.closeDialog()
                            }
                        }

                        Keys.onLeftPressed: cancelLocalBtn.forceActiveFocus()
                        Keys.onReturnPressed: {
                            if (appViewModel) {
                                appViewModel.recordingList.deleteLocalFile(deleteLocalDialog.recordingId)
                            }
                            deleteLocalDialog.closeDialog()
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                if (appViewModel) {
                                    appViewModel.recordingList.deleteLocalFile(deleteLocalDialog.recordingId)
                                }
                                deleteLocalDialog.closeDialog()
                                event.accepted = true
                            } else if (event.key === Qt.Key_B || event.key === Qt.Key_Escape
                                    || event.key === Qt.Key_Back) {
                                deleteLocalDialog.closeDialog()
                                event.accepted = true
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
