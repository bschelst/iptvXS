// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Rectangle {
    id: topBar

    property var menuItems: []
    property string activeView: "home"
    property int focusedMenuIndex: -1

    signal menuActivated(string view)
    signal speedTestRequested()
    signal logRequested()
    signal searchRequested()
    signal settingsRequested()
    signal logoActivated()

    height: Theme.topBarHeight
    color: Theme.surface
    clip: true

    function indexForView(viewName) {
        for (var i = 0; i < menuItems.length; i++) {
            if (menuItems[i] && menuItems[i].view === viewName) {
                return i
            }
        }
        return 0
    }

    function focusMenuItem(index) {
        if (index < 0 || index >= menuRepeater.count) return false
        var item = menuRepeater.itemAt(index)
        if (!item) return false
        focusedMenuIndex = index
        item.forceActiveFocus()
        return true
    }

    function focusActiveMenuItem() {
        return focusMenuItem(indexForView(activeView))
    }

    function forceMenuFocus() {
        if (!focusActiveMenuItem()) {
            focusMenuItem(0)
        }
    }

    // Step the menu focus left (-1) or right (+1), wrapping at ends.
    // Used by L1/R1 controller shortcuts (mapped to PageUp/PageDown).
    // Always derive the current position from `activeView` (the view that
    // is actually loaded) rather than `focusedMenuIndex` (the menu button
    // that last had keyboard focus). Otherwise — when the user reaches a
    // view by mouse-click or any path that doesn't go through
    // focusMenuItem — focusedMenuIndex is stale and L1/R1 steps from the
    // wrong origin.
    function stepMenuFocus(delta) {
        if (menuItems.length === 0) return
        var current = indexForView(activeView)
        var next = (current + delta + menuItems.length) % menuItems.length
        focusMenuItem(next)
        if (menuItems[next] && menuItems[next].view) {
            topBar.menuActivated(menuItems[next].view)
        }
    }

    // Catch PageUp/PageDown anywhere within the TopBar's focus subtree so
    // the user can tab through nav items via L1/R1 even when focus is on
    // the search/log/speedtest buttons or the logo.
    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_PageUp) {
            stepMenuFocus(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            stepMenuFocus(+1)
            event.accepted = true
        }
    }

    function focusContentPrimary() {
        if (Window.window && Window.window.focusCurrentViewPrimary) {
            Window.window.focusCurrentViewPrimary()
        }
    }

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
        spacing: Theme.spacingSm

        Rectangle {
            id: logoButton
            Layout.preferredWidth: logoRow.implicitWidth + Theme.spacingSm * 2
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: 16
            color: logoButton.activeFocus || logoHover ? Theme.surfaceHover : "transparent"
            focus: false
            activeFocusOnTab: true

            property bool logoHover: false

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Row {
                id: logoRow
                anchors.centerIn: parent
                spacing: 0

                Image {
                    source: "qrc:/images/iptvxs_logo.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    width: 24
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.logoHover = true
                onExited: parent.logoHover = false
                onClicked: topBar.logoActivated()
            }

            Keys.onReturnPressed: topBar.logoActivated()
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onRightPressed: topBar.focusMenuItem(0)
            Keys.onDownPressed: topBar.focusContentPrimary()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    topBar.logoActivated()
                    event.accepted = true
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter

            Row {
                id: menuRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSm

                Repeater {
                    id: menuRepeater
                    model: topBar.menuItems

                    delegate: Rectangle {
                        id: navItem
                        property int navIndex: index
                        property string viewName: modelData.view
                        property string displayLabel: modelData.label
                        property bool hover: false

                        implicitWidth: navText.implicitWidth + Theme.spacingMd * 2
                        height: 30
                        radius: 15
                        focus: false
                        activeFocusOnTab: true
                        color: topBar.activeView === viewName
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                            : (activeFocus || hover ? Theme.surfaceHover : "transparent")
                        border.width: activeFocus || topBar.activeView === viewName ? 1 : 0
                        border.color: topBar.activeView === viewName ? Theme.accent : Theme.surfaceBorder

                        Behavior on color {
                            ColorAnimation { duration: Theme.animFast }
                        }

                        Text {
                            id: navText
                            anchors.centerIn: parent
                            text: displayLabel
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: topBar.activeView === viewName || activeFocus
                            color: topBar.activeView === viewName || activeFocus
                                ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: navItem.hover = true
                            onExited: navItem.hover = false
                            onClicked: {
                                topBar.focusedMenuIndex = navIndex
                                topBar.menuActivated(viewName)
                            }
                        }

                        Keys.onReturnPressed: {
                            topBar.focusedMenuIndex = navIndex
                            topBar.menuActivated(viewName)
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onLeftPressed: {
                            if (navIndex > 0) {
                                topBar.focusMenuItem(navIndex - 1)
                            } else {
                                logoButton.forceActiveFocus()
                            }
                        }
                        Keys.onRightPressed: {
                            if (navIndex < menuRepeater.count - 1) {
                                topBar.focusMenuItem(navIndex + 1)
                            } else {
                                searchButton.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: topBar.focusContentPrimary()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                topBar.focusedMenuIndex = navIndex
                                topBar.menuActivated(viewName)
                                event.accepted = true
                            }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                topBar.focusedMenuIndex = navIndex
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: searchButton
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: 15
            color: searchButton.activeFocus || searchHover ? Theme.surfaceHover : "transparent"
            focus: false
            activeFocusOnTab: true

            property bool searchHover: false

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Canvas {
                anchors.centerIn: parent
                width: 13
                height: 13
                antialiasing: true
                Component.onCompleted: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = Theme.textPrimary
                    ctx.lineWidth = 1.5
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(6.2, 6.3, 3.4, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(8.7, 8.8)
                    ctx.lineTo(11.6, 11.7)
                    ctx.stroke()
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.searchHover = true
                onExited: parent.searchHover = false
                onClicked: topBar.searchRequested()
            }

            Keys.onReturnPressed: topBar.searchRequested()
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onLeftPressed: {
                if (menuRepeater.count > 0) {
                    topBar.focusMenuItem(menuRepeater.count - 1)
                } else {
                    logoButton.forceActiveFocus()
                }
            }
            Keys.onRightPressed: logButton.forceActiveFocus()
            Keys.onDownPressed: topBar.focusContentPrimary()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    topBar.searchRequested()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: logButton
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: 15
            color: logButton.activeFocus || logHover ? Theme.surfaceHover : "transparent"
            focus: false
            activeFocusOnTab: true

            property bool logHover: false

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Canvas {
                anchors.centerIn: parent
                width: 13
                height: 13
                antialiasing: true
                Component.onCompleted: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = Theme.textPrimary
                    ctx.lineWidth = 1.4
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(3, 2)
                    ctx.lineTo(9.5, 2)
                    ctx.lineTo(11, 3.5)
                    ctx.lineTo(11, 11)
                    ctx.lineTo(3, 11)
                    ctx.closePath()
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(9.5, 2)
                    ctx.lineTo(9.5, 3.5)
                    ctx.lineTo(11, 3.5)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(4.2, 5)
                    ctx.lineTo(9.1, 5)
                    ctx.moveTo(4.2, 7)
                    ctx.lineTo(9.1, 7)
                    ctx.moveTo(4.2, 9)
                    ctx.lineTo(7.7, 9)
                    ctx.stroke()
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.logHover = true
                onExited: parent.logHover = false
                onClicked: topBar.logRequested()
            }

            Keys.onReturnPressed: topBar.logRequested()
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onLeftPressed: searchButton.forceActiveFocus()
            Keys.onRightPressed: speedTestButton.forceActiveFocus()
            Keys.onDownPressed: topBar.focusContentPrimary()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    topBar.logRequested()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: speedTestButton
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: 15
            color: speedTestButton.activeFocus || speedTestHover ? Theme.surfaceHover : "transparent"
            focus: false
            activeFocusOnTab: true

            property bool speedTestHover: false

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Canvas {
                anchors.centerIn: parent
                width: 13
                height: 13
                antialiasing: true
                Component.onCompleted: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = Theme.textPrimary
                    ctx.lineWidth = 1.4
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.arc(6.5, 6.5, 4.7, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(6.5, 6.5, 2.4, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(1.9, 6.5)
                    ctx.lineTo(11.1, 6.5)
                    ctx.moveTo(6.5, 1.8)
                    ctx.lineTo(6.5, 11.2)
                    ctx.stroke()
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.speedTestHover = true
                onExited: parent.speedTestHover = false
                onClicked: topBar.speedTestRequested()
            }

            Keys.onReturnPressed: topBar.speedTestRequested()
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onLeftPressed: logButton.forceActiveFocus()
            Keys.onRightPressed: settingsButton.forceActiveFocus()
            Keys.onDownPressed: topBar.focusContentPrimary()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    topBar.speedTestRequested()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: settingsButton
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: 15
            color: settingsButton.activeFocus || settingsHover ? Theme.surfaceHover : "transparent"
            focus: false
            activeFocusOnTab: true

            property bool settingsHover: false

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Canvas {
                anchors.centerIn: parent
                width: 13
                height: 13
                antialiasing: true
                Component.onCompleted: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = Theme.textPrimary
                    ctx.lineWidth = 1.4
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.arc(6.5, 6.6, 2.4, 0, Math.PI * 2)
                    ctx.stroke()
                    for (var i = 0; i < 8; ++i) {
                        var a = i * Math.PI / 4
                        var x1 = 6.5 + Math.cos(a) * 3.3
                        var y1 = 6.6 + Math.sin(a) * 3.3
                        var x2 = 6.5 + Math.cos(a) * 4.6
                        var y2 = 6.6 + Math.sin(a) * 4.6
                        ctx.beginPath()
                        ctx.moveTo(x1, y1)
                        ctx.lineTo(x2, y2)
                        ctx.stroke()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.settingsHover = true
                onExited: parent.settingsHover = false
                onClicked: topBar.settingsRequested()
            }

            Keys.onReturnPressed: topBar.settingsRequested()
            Keys.onEnterPressed: Keys.onReturnPressed(event)
            Keys.onLeftPressed: searchButton.forceActiveFocus()
            Keys.onRightPressed: {
                if (appViewModel && appViewModel.chromecast && appViewModel.chromecast.connected) {
                    castButton.forceActiveFocus()
                } else {
                    clockButton.forceActiveFocus()
                }
            }
            Keys.onDownPressed: topBar.focusContentPrimary()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    topBar.settingsRequested()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: castButton
            visible: appViewModel && appViewModel.chromecast && appViewModel.chromecast.connected
            Layout.preferredWidth: castRow.implicitWidth + Theme.spacingMd * 2
            Layout.preferredHeight: 28
            radius: 14
            color: castButton.activeFocus ? Theme.surfaceHover : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
            border.width: 1
            focus: false
            activeFocusOnTab: true

            Row {
                id: castRow
                anchors.centerIn: parent
                spacing: 6

                Canvas {
                    width: 14
                    height: 11
                    anchors.verticalCenter: parent.verticalCenter
                    antialiasing: true
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = Theme.accent
                        ctx.fillStyle = Theme.accent
                        ctx.lineWidth = 1.2
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.moveTo(1, 9)
                        ctx.lineTo(1, 2)
                        ctx.quadraticCurveTo(1, 0.5, 2, 0.5)
                        ctx.lineTo(12, 0.5)
                        ctx.quadraticCurveTo(13, 0.5, 13, 2)
                        ctx.lineTo(13, 9)
                        ctx.quadraticCurveTo(13, 10.5, 12, 10.5)
                        ctx.lineTo(8, 10.5)
                        ctx.stroke()
                        ctx.beginPath(); ctx.arc(1, 10, 1.2, -Math.PI/2, 0); ctx.stroke()
                        ctx.beginPath(); ctx.arc(1, 10, 3.5, -Math.PI/2, 0); ctx.stroke()
                        ctx.beginPath(); ctx.arc(1, 10, 5.8, -Math.PI/2, 0); ctx.stroke()
                    }
                }

                Text {
                    text: "Casting"
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Keys.onLeftPressed: settingsButton.forceActiveFocus()
            Keys.onRightPressed: clockButton.forceActiveFocus()
            Keys.onDownPressed: topBar.focusContentPrimary()
        }

        Rectangle {
            id: clockButton
            Layout.preferredWidth: clockRow.implicitWidth + Theme.spacingSm
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.borderRadiusLarge
            color: clockButton.activeFocus ? Theme.surfaceHover : "transparent"
            focus: false
            activeFocusOnTab: true

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 0

                Text {
                    text: Qt.formatTime(clockTimer.currentTime, "HH")
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: ":"
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: true
                        NumberAnimation { to: 0.0; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    text: Qt.formatTime(clockTimer.currentTime, "mm")
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Timer {
                id: clockTimer
                property date currentTime: new Date()
                interval: 10000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: currentTime = new Date()
            }

            Keys.onLeftPressed: {
                if (castButton.visible) {
                    castButton.forceActiveFocus()
                } else {
                    settingsButton.forceActiveFocus()
                }
            }
            Keys.onRightPressed: topBar.forceMenuFocus()
            Keys.onDownPressed: topBar.focusContentPrimary()
        }
    }
}
