// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: root
    focus: true

    function focusPrimary() {
        root.forceActiveFocus()
    }

    Keys.onLeftPressed: {
        if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
    }
    Keys.onReturnPressed: {
        if (speedTest && !speedTest.running) {
            sparklineData = []
            sparklineCanvas.requestPaint()
            speedTest.startInternetTest()
        }
    }
    Keys.onEnterPressed: Keys.onReturnPressed(event)
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
            Keys.onReturnPressed(event)
            event.accepted = true
        }
    }

    property var speedTest: appViewModel ? appViewModel.speedTest : null
    property var channelList: appViewModel ? appViewModel.channelList : null
    property var sparklineData: []
    property int samplesPerSecond: 4
    property int sparklineSampleCount: speedTest
        ? Math.max(2, Math.ceil((speedTest.duration * samplesPerSecond) + 1))
        : 61

    Component.onCompleted: {
        if (channelList && channelList.rowCount() === 0
                && appViewModel && appViewModel.serverList.count > 0) {
            var firstEnabledIdx = appViewModel.serverList.firstEnabledServerIndex()
            if (firstEnabledIdx >= 0) {
                var firstServerId = appViewModel.serverList.serverIdAt(firstEnabledIdx)
                if (firstServerId > 0) {
                    channelList.serverId = firstServerId
                }
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
            var maxDataPoints = root.sparklineSampleCount
            var d = root.sparklineData.slice()
            d.push(speedTest.currentMbps)
            if (d.length > maxDataPoints) {
                d = d.slice(d.length - maxDataPoints)
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
                            text: "Internet Test"
                            enabled: speedTest !== null && !speedTest.running
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: Theme.textOnAccent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitWidth: 130
                                implicitHeight: 40
                                radius: Theme.borderRadius
                                color: parent.hovered ? Theme.accentHover : Theme.accent
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                            onClicked: {
                                if (!speedTest) return
                                root.sparklineData = []
                                sparklineCanvas.requestPaint()
                                speedTest.startInternetTest()
                            }
                        }

                        Button {
                            text: "Stop"
                            visible: speedTest ? speedTest.running : false
                            enabled: speedTest !== null && speedTest.running
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: Theme.textOnAccent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitWidth: 100
                                implicitHeight: 40
                                radius: Theme.borderRadius
                                color: parent.hovered
                                    ? Qt.darker(Theme.error, 1.2) : Theme.error

                                Behavior on color {
                                    ColorAnimation { duration: Theme.animFast }
                                }
                            }
                            onClicked: {
                                if (speedTest) speedTest.stopTest()
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Text {
                            text: "Throughput"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.textSecondary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            id: chartMaxLabel
                            text: {
                                var data = root.sparklineData
                                if (data.length < 2) return ""
                                var maxVal = 0
                                for (var i = 0; i < data.length; i++) {
                                    if (data[i] > maxVal) maxVal = data[i]
                                }
                                if (maxVal < 1) return "0 Mbps"
                                if (maxVal >= 1) return maxVal.toFixed(1) + " Mbps"
                                return (maxVal * 1000).toFixed(0) + " Kbps"
                            }
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
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

                            var leftMargin = 48
                            var padding = 4
                            var w = width - leftMargin - padding
                            var h = height - padding * 2
                            var durationPoints = Math.max(2, root.sparklineSampleCount)
                            var stepX = w / (durationPoints - 1)

                            var accentColor = Theme.accent
                            var gradient = ctx.createLinearGradient(0, padding, 0, height - padding)
                            gradient.addColorStop(0, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3))
                            gradient.addColorStop(1, Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.02))

                            ctx.font = "10px sans-serif"
                            ctx.fillStyle = Theme.textMuted
                            ctx.textAlign = "right"

                            var gridLines = 4
                            for (var g = 0; g <= gridLines; g++) {
                                var gridY = padding + h - (g / gridLines) * h
                                var gridVal = (g / gridLines) * maxVal
                                var label
                                if (maxVal >= 1) {
                                    label = gridVal.toFixed(1)
                                } else {
                                    label = (gridVal * 1000).toFixed(0) + "K"
                                }
                                ctx.fillText(label, leftMargin - 6, gridY + 3)

                                ctx.beginPath()
                                ctx.moveTo(leftMargin, gridY)
                                ctx.lineTo(width - padding, gridY)
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
                                ctx.lineWidth = 1
                                ctx.stroke()
                            }

                            ctx.beginPath()
                            ctx.moveTo(leftMargin, height - padding)

                            for (var j = 0; j < data.length; j++) {
                                var x = leftMargin + j * stepX
                                var y = padding + h - (data[j] / maxVal) * h
                                ctx.lineTo(x, y)
                            }

                            ctx.lineTo(leftMargin + Math.max(0, data.length - 1) * stepX, height - padding)
                            ctx.closePath()
                            ctx.fillStyle = gradient
                            ctx.fill()

                            ctx.beginPath()
                            for (var k = 0; k < data.length; k++) {
                                var lx = leftMargin + k * stepX
                                var ly = padding + h - (data[k] / maxVal) * h
                                if (k === 0) ctx.moveTo(lx, ly)
                                else ctx.lineTo(lx, ly)
                            }
                            ctx.strokeStyle = accentColor
                            ctx.lineWidth = 2
                            ctx.stroke()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "0s"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: {
                                var dur = speedTest ? speedTest.duration : 10
                                return Math.round(dur / 2) + "s"
                            }
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: speedTest ? speedTest.duration + "s" : "10s"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        Text {
                            text: "Duration:"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }

                        Repeater {
                            model: [10, 30, 60, 120]

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
                                        ? Theme.textOnAccent : Theme.textSecondary
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
