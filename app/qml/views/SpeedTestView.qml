import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: root

    property var speedTest: appViewModel ? appViewModel.speedTest : null
    property var channelList: appViewModel ? appViewModel.channelList : null
    property var sparklineData: []
    property int maxDataPoints: 60

    Component.onCompleted: {
        if (channelList && channelList.rowCount() === 0
                && appViewModel && appViewModel.serverList.count > 0) {
            var firstServerId = appViewModel.serverList.serverIdAt(0)
            if (firstServerId > 0) {
                channelList.serverId = firstServerId
            }
        }
    }

    Timer {
        id: sparklineTimer
        interval: 250
        repeat: true
        running: speedTest ? speedTest.running : false
        onTriggered: {
            if (!speedTest) return
            var d = root.sparklineData.slice()
            d.push(speedTest.currentMbps)
            if (d.length > root.maxDataPoints) {
                d = d.slice(d.length - root.maxDataPoints)
            }
            root.sparklineData = d
            sparklineCanvas.requestPaint()
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: Theme.spacingLg
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: Theme.spacingLg

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.width: 1
                border.color: Theme.surfaceBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            id: mbpsLabel
                            anchors.centerIn: parent
                            text: {
                                if (!speedTest) return "0.0"
                                if (speedTest.hasResult) return speedTest.resultMbps.toFixed(1)
                                return speedTest.currentMbps.toFixed(1)
                            }
                            font.pixelSize: 72
                            font.bold: true
                            color: Theme.textPrimary

                            Behavior on text {
                                enabled: false
                            }
                        }

                        Text {
                            anchors.top: mbpsLabel.bottom
                            anchors.topMargin: Theme.spacingXs
                            anchors.horizontalCenter: mbpsLabel.horizontalCenter
                            text: "Mbps"
                            font.pixelSize: Theme.fontSizeLg
                            color: Theme.textSecondary
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 4
                            radius: 2
                            color: Theme.surfaceBorder
                            visible: speedTest ? speedTest.running : false

                            Rectangle {
                                id: progressBar
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                                width: {
                                    if (!speedTest || !speedTest.running) return 0
                                    var parts = speedTest.elapsed.replace("s", "")
                                    var secs = parseFloat(parts) || 0
                                    return parent.width * Math.min(secs / speedTest.duration, 1.0)
                                }

                                Behavior on width {
                                    NumberAnimation { duration: 200 }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg

                        Column {
                            spacing: 2
                            Text {
                                text: "Downloaded"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                            Text {
                                text: speedTest ? speedTest.bytesReceived : "0 B"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                            }
                        }

                        Column {
                            spacing: 2
                            Text {
                                text: "Elapsed"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                            Text {
                                text: speedTest ? speedTest.elapsed : "0.0s"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                            }
                        }

                        Column {
                            spacing: 2
                            Text {
                                text: "Duration"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                            Text {
                                text: speedTest ? speedTest.duration + "s" : "10s"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: speedTest && speedTest.running ? "Stop" : "Start Test"
                            enabled: speedTest !== null && streamUrlField.text.length > 0
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: Theme.textPrimary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitWidth: 120
                                implicitHeight: 40
                                radius: Theme.borderRadius
                                color: speedTest && speedTest.running
                                    ? Theme.error : parent.hovered
                                        ? Theme.accentHover : Theme.accent

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animFast }
                                }
                            }
                            onClicked: {
                                if (!speedTest) return
                                if (speedTest.running) {
                                    speedTest.stopTest()
                                } else {
                                    root.sparklineData = []
                                    sparklineCanvas.requestPaint()
                                    speedTest.startTest(streamUrlField.text)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.width: 1
                border.color: Theme.surfaceBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    Text {
                        text: "Throughput"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    Canvas {
                        id: sparklineCanvas
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var data = root.sparklineData
                            if (data.length < 2) return

                            var maxVal = 0
                            for (var i = 0; i < data.length; i++) {
                                if (data[i] > maxVal) maxVal = data[i]
                            }
                            if (maxVal < 1) maxVal = 1

                            var padding = 4
                            var w = width - padding * 2
                            var h = height - padding * 2
                            var stepX = w / (root.maxDataPoints - 1)

                            var gradient = ctx.createLinearGradient(0, padding, 0, height - padding)
                            gradient.addColorStop(0, Qt.rgba(
                                Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3))
                            gradient.addColorStop(1, Qt.rgba(
                                Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.02))

                            ctx.beginPath()
                            ctx.moveTo(padding, height - padding)

                            for (var j = 0; j < data.length; j++) {
                                var x = padding + j * stepX
                                var y = padding + h - (data[j] / maxVal) * h
                                ctx.lineTo(x, y)
                            }

                            ctx.lineTo(padding + (data.length - 1) * stepX, height - padding)
                            ctx.closePath()
                            ctx.fillStyle = gradient
                            ctx.fill()

                            ctx.beginPath()
                            for (var k = 0; k < data.length; k++) {
                                var lx = padding + k * stepX
                                var ly = padding + h - (data[k] / maxVal) * h
                                if (k === 0) ctx.moveTo(lx, ly)
                                else ctx.lineTo(lx, ly)
                            }
                            ctx.strokeStyle = Theme.accent
                            ctx.lineWidth = 2
                            ctx.stroke()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: urlColumn.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.width: 1
                border.color: Theme.surfaceBorder

                ColumnLayout {
                    id: urlColumn
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Stream URL"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    TextField {
                        id: streamUrlField
                        Layout.fillWidth: true
                        placeholderText: "Enter stream URL or select a channel below"
                        color: Theme.textPrimary
                        placeholderTextColor: Theme.textMuted
                        font.pixelSize: Theme.fontSizeSm

                        background: Rectangle {
                            radius: Theme.borderRadius
                            color: Theme.surface
                            border.width: 1
                            border.color: streamUrlField.activeFocus
                                ? Theme.accent : Theme.surfaceBorder
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        Text {
                            text: "Duration:"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: [5, 10, 20, 30]

                            delegate: Rectangle {
                                width: 48
                                height: 32
                                radius: Theme.borderRadiusSmall
                                color: speedTest && speedTest.duration === modelData
                                    ? Theme.accent : hovered
                                        ? Theme.surfaceHover : Theme.surface
                                border.width: 1
                                border.color: Theme.surfaceBorder

                                property bool hovered: false

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "s"
                                    font.pixelSize: Theme.fontSizeXs
                                    color: speedTest && speedTest.duration === modelData
                                        ? Theme.textPrimary : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.hovered = true
                                    onExited: parent.hovered = false
                                    onClicked: {
                                        if (speedTest) speedTest.duration = modelData
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "Quick Test from Channels"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: Theme.textSecondary
                        Layout.topMargin: Theme.spacingSm
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Repeater {
                            model: channelList ? Math.min(channelList.rowCount(), 8) : 0

                            delegate: Rectangle {
                                width: channelLabel.implicitWidth + Theme.spacingMd * 2
                                height: 36
                                radius: Theme.borderRadius
                                color: channelHover.containsMouse
                                    ? Theme.surfaceHover : Theme.surface
                                border.width: 1
                                border.color: Theme.surfaceBorder

                                Text {
                                    id: channelLabel
                                    anchors.centerIn: parent
                                    text: {
                                        var name = channelList
                                            ? channelList.data(channelList.index(index, 0), 258)
                                            : ""
                                        return name || "Channel"
                                    }
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: channelHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!speedTest || !channelList) return
                                        var chId = channelList.data(
                                            channelList.index(index, 0), 257)
                                        var url = channelList.data(
                                            channelList.index(index, 0), 259)
                                        if (url) {
                                            streamUrlField.text = url
                                            root.sparklineData = []
                                            sparklineCanvas.requestPaint()
                                            speedTest.startTest(url)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: !channelList || channelList.rowCount() === 0
                            text: "No channels loaded — add a server first"
                            font.pixelSize: Theme.fontSizeXs
                            font.italic: true
                            color: Theme.textMuted
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: errorText.implicitHeight + Theme.spacingMd * 2
                radius: Theme.borderRadius
                color: "#2a1010"
                border.width: 1
                border.color: Theme.error
                visible: speedTest ? speedTest.errorMessage.length > 0 : false

                Text {
                    id: errorText
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    text: speedTest ? speedTest.errorMessage : ""
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.error
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.spacingLg
            }
        }
    }
}
