// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Rectangle {
    id: root

    property bool open: false
    property string query: ""
    property var results: []

    signal closed()
    signal resultActivated(var result)

    visible: open
    anchors.fill: parent
    z: 9000
    color: Qt.rgba(0, 0, 0, 0.70)

    function openOverlay() {
        open = true
        query = ""
        results = []
        currentIndex = -1
        searchField.text = ""
        Qt.callLater(function() { searchField.forceActiveFocus() })
    }

    function closeOverlay() {
        if (!open) return
        open = false
        query = ""
        results = []
        currentIndex = -1
        closed()
    }

    function refreshResults() {
        query = searchField.text
        if (appViewModel && query.trim().length >= 2) {
            results = appViewModel.globalSearch(query.trim(), 60)
        } else {
            results = []
        }
        currentIndex = results.length > 0 ? 0 : -1
    }

    function currentResult() {
        if (currentIndex < 0 || currentIndex >= results.length) return null
        return results[currentIndex]
    }

    function activateCurrentResult() {
        var item = currentResult()
        if (!item) return
        resultActivated(item)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeOverlay()
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.topBarHeight + Theme.spacingLg
        width: Math.min(parent.width - Theme.spacingLg * 2, 1080)
        height: Math.min(parent.height - Theme.topBarHeight - Theme.spacingLg * 2, 680)
        radius: Theme.borderRadiusLarge
        color: Theme.surfaceElevated
        border.color: Theme.surfaceBorder
        border.width: 1
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingLg
            spacing: Theme.spacingMd

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMd

                Text {
                    text: "Search everything"
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: Theme.surfaceHover

                    Text {
                        anchors.centerIn: parent
                        text: "Esc"
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 21
                color: Theme.surfaceElevated
                border.color: searchField.activeFocus ? Theme.accentHover : Theme.surfaceBorder
                border.width: 1

                TextField {
                    id: searchField
                    anchors.fill: parent
                    leftPadding: Theme.spacingMd + 6
                    rightPadding: Theme.spacingMd
                    topPadding: 9
                    bottomPadding: 9
                    verticalAlignment: TextInput.AlignVCenter
                    background: null
                    placeholderText: ""
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: "#ffffff"
                    font.pixelSize: Theme.fontSizeSm
                    onTextChanged: searchTimer.restart()

                    Keys.onDownPressed: {
                        if (resultList.count > 0) {
                            if (resultList.currentIndex < 0) resultList.currentIndex = 0
                            resultList.forceActiveFocus()
                        }
                    }
                    Keys.onReturnPressed: root.activateCurrentResult()
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back
                                || (event.key === Qt.Key_B && (!event.text || event.text.length === 0))) {
                            root.closeOverlay()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            root.activateCurrentResult()
                            event.accepted = true
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingMd + 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search channels, recordings, history..."
                    color: Theme.textMuted
                    opacity: searchField.activeFocus ? 0.85 : 1.0
                    font.pixelSize: Theme.fontSizeSm
                    visible: searchField.text.length === 0
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                Text {
                    text: query.length >= 2
                        ? (results.length + " result" + (results.length === 1 ? "" : "s"))
                        : "Type at least 2 characters"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeXs
                    Layout.fillWidth: true
                }
            }

            ListView {
                id: resultList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.results
                currentIndex: root.currentIndex
                onCurrentIndexChanged: root.currentIndex = currentIndex
                onCountChanged: {
                    if (count === 0) {
                        currentIndex = -1
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    width: resultList.width
                    height: 84
                    radius: Theme.borderRadiusLarge
                    color: resultList.currentIndex === index ? Theme.surfaceHover : "transparent"
                    border.width: resultList.currentIndex === index ? 1 : 0
                    border.color: Theme.accent

                    property bool hover: false

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMd
                        spacing: Theme.spacingMd

                        Rectangle {
                            width: 44
                            height: 44
                            radius: 12
                            color: Theme.surfaceElevated
                            border.color: Theme.surfaceBorder
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                anchors.margins: 4
                                source: modelData.logoUrl ? modelData.logoUrl : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: modelData.logoUrl && modelData.logoUrl.length > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !modelData.logoUrl || modelData.logoUrl.length === 0
                                text: modelData.kind === "history" ? "H" : (modelData.kind === "recording" ? "R" : "C")
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                                color: Theme.textSecondary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: modelData.title || ""
                                font.pixelSize: Theme.fontSizeMd
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.subtitle || ""
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                                Rectangle {
                                    visible: true
                                    radius: 10
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                border.width: 1
                                implicitWidth: badgeText.implicitWidth + Theme.spacingSm * 2
                                implicitHeight: 20

                                Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: {
                                        if (modelData.kind === "channel") {
                                            if (modelData.type === "live") return "Live TV"
                                            if (modelData.type === "vod" || modelData.type === "movie") return "Movie"
                                            if (modelData.type === "series") return "Series"
                                            return "Channel"
                                        }
                                        if (modelData.kind === "history") {
                                            return modelData.type === "live" ? "Live TV"
                                                : (modelData.type === "vod" || modelData.type === "movie") ? "Movie"
                                                : (modelData.type === "series") ? "Series"
                                                : "History"
                                        }
                                        return "Recording"
                                    }
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textPrimary
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.hover = true
                        onExited: parent.hover = false
                        onClicked: {
                            resultList.currentIndex = index
                            root.activateCurrentResult()
                        }
                    }
                }

                Keys.onUpPressed: {
                    if (currentIndex > 0) {
                        currentIndex--
                    } else {
                        searchField.forceActiveFocus()
                    }
                }
                Keys.onDownPressed: {
                    if (currentIndex < count - 1) currentIndex++
                }
                Keys.onReturnPressed: root.activateCurrentResult()
                Keys.onEnterPressed: Keys.onReturnPressed(event)
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                        root.activateCurrentResult()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Back || (event.key === Qt.Key_B
                               && (!event.text || event.text.length === 0))
                               || event.key === Qt.Key_Escape) {
                        root.closeOverlay()
                        event.accepted = true
                    }
                }
            }
        }
    }

    Timer {
        id: searchTimer
        interval: 180
        repeat: false
        onTriggered: root.refreshResults()
    }

    property int currentIndex: -1
}
