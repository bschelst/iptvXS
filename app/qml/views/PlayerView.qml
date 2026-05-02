// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: playerView

    property string channelUrl: ""
    property string channelName: ""
    property string channelLogo: ""
    property bool videoFullscreen: appViewModel ? appViewModel.videoFullscreen : false
    property string pendingCastUrl: ""
    property string pendingCastName: ""
    property string pendingCastCt: ""

    function visibleControlButtons() {
        var buttons = [playPauseBtn, stopBtn, favBtn, recBtn, castBtn, ccBtn, audioBtn, episodeBtn, muteBtn, stretchBtn, fullscreenBtn]
        var visibleButtons = []
        for (var i = 0; i < buttons.length; i++) {
            if (buttons[i] && buttons[i].visible)
                visibleButtons.push(buttons[i])
        }
        return visibleButtons
    }

    function focusedControlIndex() {
        var buttons = visibleControlButtons()
        for (var i = 0; i < buttons.length; i++) {
            if (buttons[i].activeFocus) return i
        }
        return -1
    }

    function focusControlButton(index) {
        var buttons = visibleControlButtons()
        if (!buttons.length) return
        var idx = Math.max(0, Math.min(buttons.length - 1, index))
        buttons[idx].forceActiveFocus()
        showControls()
    }

    function langCodesFor(iso1) {
        var map = {
            "en": ["eng"], "nl": ["dut","nld"], "fr": ["fre","fra"],
            "de": ["ger","deu"], "es": ["spa"], "it": ["ita"],
            "pt": ["por"], "ru": ["rus"], "ar": ["ara"], "tr": ["tur"],
            "pl": ["pol"], "zh": ["chi","zho"], "ja": ["jpn"], "ko": ["kor"],
            "hi": ["hin"], "sv": ["swe"], "da": ["dan"], "no": ["nor"],
            "fi": ["fin"], "cs": ["cze","ces"], "hu": ["hun"],
            "ro": ["rum","ron"], "el": ["gre","ell"], "he": ["heb"],
            "th": ["tha"], "vi": ["vie"]
        }
        return map[iso1] || [iso1]
    }

    function langMatches(trackLang, settingLang) {
        if (!trackLang || !settingLang) return false
        var codes = langCodesFor(settingLang.toLowerCase())
        return codes.indexOf(trackLang.toLowerCase()) >= 0
    }

    function langName(code) {
        var map = {
            "eng": "English", "dut": "Dutch", "nld": "Dutch",
            "fre": "French", "fra": "French",
            "ger": "German", "deu": "German",
            "spa": "Spanish", "ita": "Italian",
            "por": "Portuguese", "rus": "Russian",
            "ara": "Arabic", "tur": "Turkish",
            "pol": "Polish", "chi": "Chinese", "zho": "Chinese",
            "jpn": "Japanese", "kor": "Korean",
            "hin": "Hindi", "swe": "Swedish",
            "dan": "Danish", "nor": "Norwegian",
            "fin": "Finnish", "cze": "Czech", "ces": "Czech",
            "hun": "Hungarian", "rum": "Romanian", "ron": "Romanian",
            "gre": "Greek", "ell": "Greek",
            "heb": "Hebrew", "tha": "Thai",
            "vie": "Vietnamese", "ind": "Indonesian",
            "may": "Malay", "msa": "Malay",
            "bul": "Bulgarian", "hrv": "Croatian",
            "srp": "Serbian", "slv": "Slovenian",
            "ukr": "Ukrainian", "cat": "Catalan",
            "per": "Persian", "fas": "Persian",
            "und": "Undetermined", "mul": "Multiple"
        }
        if (!code) return ""
        return map[code.toLowerCase()] || code.toUpperCase()
    }

    function formatBitrate(bytesPerSecond) {
        if (!bytesPerSecond || bytesPerSecond <= 0) return ""
        var mbps = bytesPerSecond * 8 / 1000000.0
        if (mbps >= 10) return mbps.toFixed(0) + " Mb/s"
        return mbps.toFixed(1) + " Mb/s"
    }

    function formatResolution(height) {
        if (!height || height <= 0) return ""
        return height + "p"
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: showControls()
            onClicked: {
                if (appViewModel) appViewModel.player.togglePause()
                showControls()
            }
            onDoubleClicked: toggleVideoFullscreen()
        }

        // Buffer bar is inside the top overlay (see topOverlay)

        // --- Bottom controls overlay ---
        Rectangle {
            id: controlsOverlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 130
            visible: opacity > 0
            opacity: controlsVisible ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation { duration: Theme.animNormal }
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.4; color: "#80000000" }
                GradientStop { position: 1.0; color: "#cc000000" }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Slider {
                    id: seekSlider
                    Layout.fillWidth: true
                    visible: {
                        if (!appViewModel) return false
                        if (appViewModel.player.duration > 0) return true
                        return appViewModel.player.paused && appViewModel.player.isLive
                    }
                    from: 0
                    to: {
                        if (!appViewModel) return 1
                        if (appViewModel.player.duration > 0) return appViewModel.player.duration
                        if (appViewModel.player.paused && appViewModel.player.isLive)
                            return Math.max(appViewModel.player.position + appViewModel.player.cacheDuration, 1)
                        return 1
                    }
                    value: appViewModel ? appViewModel.player.position : 0
                    enabled: visible

                    onMoved: {
                        if (appViewModel) appViewModel.player.seek(value)
                    }

                    background: Rectangle {
                        x: seekSlider.leftPadding
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - 3
                        width: seekSlider.availableWidth
                        height: 6
                        radius: 3
                        color: "#40ffffff"

                        Rectangle {
                            width: seekSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 3
                            color: Theme.accent
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.bottom
                            anchors.topMargin: 2
                            text: appViewModel ? appViewModel.player.formatTime(seekSlider.value) : ""
                            font.pixelSize: 10
                            color: "#aaffffff"
                            visible: !appViewModel || !appViewModel.player.isLive
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.bottom
                            anchors.topMargin: 2
                            text: appViewModel ? appViewModel.player.formatTime(appViewModel.player.duration) : ""
                            font.pixelSize: 10
                            color: "#60ffffff"
                            visible: !appViewModel || !appViewModel.player.isLive
                        }
                    }

                    handle: Rectangle {
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: seekSlider.pressed ? Theme.accentHover : Theme.accent
                        visible: seekSlider.hovered || seekSlider.pressed || seekSlider.activeFocus
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    PlayerButton {
                        id: playPauseBtn
                        text: appViewModel && appViewModel.player.paused ? "\u25B7" : "II"
                        btnSize: 36
                        iconSize: 16
                        onClicked: {
                            if (appViewModel) appViewModel.player.togglePause()
                        }
                    }

                    PlayerButton {
                        id: stopBtn
                        text: "\u25A0"
                        btnSize: 36
                        iconSize: 14
                        onClicked: goBack()
                    }

                    Text {
                        text: {
                            if (!appViewModel) return ""
                            var pos = appViewModel.player.position
                            var dur = appViewModel.player.duration
                            if (dur > 0) {
                                return appViewModel.player.formatTime(pos) + " / " + appViewModel.player.formatTime(dur)
                            }
                            if (appViewModel.player.paused && appViewModel.player.isLive && pos > 0) {
                                var cache = appViewModel.player.cacheDuration
                                return appViewModel.player.formatTime(pos) + " / " + appViewModel.player.formatTime(pos + cache) + "  \u2016 PAUSED"
                            }
                            if (pos > 0) return appViewModel.player.formatTime(pos)
                            return "● LIVE"
                        }
                        font.pixelSize: Theme.fontSizeSm
                        color: "#ffffff"
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: appViewModel ? appViewModel.player.channelName.length > 0 : false
                        text: appViewModel ? appViewModel.player.channelName : ""
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: "#ffffff"
                        elide: Text.ElideRight
                        Layout.maximumWidth: 300
                    }

                    Item { Layout.fillWidth: true }

                    // --- Favorite button (any content with a channelId) ---
                    PlayerButton {
                        id: favBtn
                        text: isFav ? "\u2605" : "\u2606"
                        btnSize: 36
                        iconSize: 16
                        property bool isFav: false
                        visible: appViewModel ? appViewModel.player.channelId > 0 : false
                        onClicked: {
                            if (appViewModel && appViewModel.player.channelId > 0) {
                                appViewModel.favoriteList.toggleFavorite(appViewModel.player.channelId)
                                isFav = !isFav
                            }
                        }
                        Component.onCompleted: updateFav()
                        function updateFav() {
                            if (appViewModel && appViewModel.player.channelId > 0)
                                isFav = appViewModel.favoriteList.isFavorite(appViewModel.player.channelId)
                        }
                        Connections {
                            target: appViewModel ? appViewModel.player : null
                            function onChannelIdChanged() { favBtn.updateFav() }
                        }
                    }

                    // --- Record button (live only) ---
                    PlayerButton {
                        id: recBtn
                        readonly property bool recActive: appViewModel ? appViewModel.player.recording : false
                        text: recActive ? "\u25A0" : "\u25CF"
                        btnSize: 36
                        iconSize: 14
                        btnColor: recActive ? Theme.error : "transparent"
                        visible: appViewModel ? appViewModel.player.isLive : false
                        onClicked: {
                            if (!appViewModel) return
                            showControls()
                            if (recActive) {
                                appViewModel.player.stopStreamRecord()
                            } else {
                                var now = new Date()
                                var ts = now.getFullYear() + "-" +
                                    String(now.getMonth()+1).padStart(2,'0') + "-" +
                                    String(now.getDate()).padStart(2,'0') + "_" +
                                    String(now.getHours()).padStart(2,'0') +
                                    String(now.getMinutes()).padStart(2,'0') +
                                    String(now.getSeconds()).padStart(2,'0')
                                var name = (appViewModel.player.channelName || "recording").replace(/[^a-zA-Z0-9_.-]/g, "_").replace(/_{2,}/g, "_").trim() || "recording"
                                var dir = appViewModel.recordingDirectory
                                var base = dir + "/" + ts + "_" + name
                                var outPath = base + ".mkv"
                                var counter = 1
                                while (appViewModel.fileExists(outPath)) {
                                    outPath = base + "_" + counter + ".mkv"
                                    counter++
                                }
                                appViewModel.recordingList.startStreamRecording(
                                    appViewModel.player.channelId, outPath)
                                appViewModel.player.startStreamRecord(outPath)
                            }
                        }
                    }

                    Rectangle {
                        id: castBtn
                        visible: appViewModel ? appViewModel.chromecastEnabled : true
                        width: 44
                        height: 44
                        radius: Theme.borderRadius
                        color: castBtnHov ? "#40ffffff" : "transparent"
                        property bool castBtnHov: false
                        property bool isCasting: appViewModel && appViewModel.chromecast.connected
                        activeFocusOnTab: true
                        border.width: activeFocus ? 2 : 0
                        border.color: Theme.accent
                        Keys.onReturnPressed: castBtnArea.clicked(null)
                        Keys.onEnterPressed: castBtnArea.clicked(null)

                        Canvas {
                            id: castCanvas
                            anchors.centerIn: parent
                            width: 24
                            height: 20
                            antialiasing: true
                            property bool casting: castBtn.isCasting
                            onCastingChanged: requestPaint()
                            Component.onCompleted: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.strokeStyle = casting ? Theme.accent : "#ffffff"
                                ctx.fillStyle = casting ? Theme.accent : "#ffffff"
                                ctx.lineWidth = 1.6
                                ctx.lineCap = "round"

                                // TV/monitor outline (rounded rect, open bottom-left)
                                ctx.beginPath()
                                ctx.moveTo(1, 16)
                                ctx.lineTo(1, 3)
                                ctx.quadraticCurveTo(1, 1, 3, 1)
                                ctx.lineTo(21, 1)
                                ctx.quadraticCurveTo(23, 1, 23, 3)
                                ctx.lineTo(23, 16)
                                ctx.quadraticCurveTo(23, 18, 21, 18)
                                ctx.lineTo(15, 18)
                                ctx.stroke()

                                // Cast waves (bottom-left corner)
                                ctx.beginPath()
                                ctx.arc(1, 18, 2, -Math.PI/2, 0)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(1, 18, 6, -Math.PI/2, 0)
                                ctx.stroke()

                                ctx.beginPath()
                                ctx.arc(1, 18, 10, -Math.PI/2, 0)
                                ctx.stroke()

                                // Filled dot at origin when casting
                                if (casting) {
                                    ctx.beginPath()
                                    ctx.arc(2, 17, 1.5, 0, 2 * Math.PI)
                                    ctx.fill()
                                }
                            }
                        }

                        MouseArea {
                            id: castBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: castBtn.castBtnHov = true
                            onExited: castBtn.castBtnHov = false
                            onClicked: {
                                castBtn.forceActiveFocus()
                                if (appViewModel && appViewModel.chromecast.connected) {
                                    castStopPopup.visible = !castStopPopup.visible
                                    castDevicePopup.visible = false
                                } else if (appViewModel) {
                                    appViewModel.chromecast.startDiscovery()
                                    castDevicePopup.visible = !castDevicePopup.visible
                                    castStopPopup.visible = false
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 1; height: 28; color: "#40ffffff"
                        visible: ccBtn.visible
                    }

                    PlayerButton {
                        id: ccBtn
                        visible: appViewModel && appViewModel.subtitlesEnabled && !appViewModel.player.isLive
                        text: "CC"
                        iconSize: 14
                        onClicked: subTrackPopup.visible = !subTrackPopup.visible
                    }

                    PlayerButton {
                        id: audioBtn
                        visible: appViewModel && appViewModel.player.audioTracks.length > 1
                        text: "AUD"
                        iconSize: 12
                        onClicked: audioTrackPopup.visible = !audioTrackPopup.visible
                    }

                    PlayerButton {
                        id: episodeBtn
                        visible: appViewModel && appViewModel.hasActiveSeriesDialog()
                                 && !appViewModel.player.isLive
                        text: "EP"
                        iconSize: 12
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.player.stop()
                                appViewModel.reopenSeriesEpisodes()
                                appViewModel.currentView = "vod_series"
                            }
                        }
                    }

                    Rectangle {
                        width: 1; height: 28; color: "#40ffffff"
                        visible: ccBtn.visible || audioBtn.visible || episodeBtn.visible
                    }

                    Rectangle {
                        id: muteBtn
                        width: 44
                        height: 44
                        radius: Theme.borderRadius
                        color: {
                            if (appViewModel && appViewModel.player.muted) return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.38)
                            return muteHov ? "#40ffffff" : "transparent"
                        }
                        property bool muteHov: false
                        readonly property bool isMuted: appViewModel ? appViewModel.player.muted : false
                        activeFocusOnTab: true
                        border.width: activeFocus ? 2 : 0
                        border.color: Theme.accent
                        Keys.onReturnPressed: muteBtnArea.clicked(null)
                        Keys.onEnterPressed: muteBtnArea.clicked(null)

                        Canvas {
                            id: speakerCanvas
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            antialiasing: true
                            property bool muted: parent.isMuted
                            onMutedChanged: requestPaint()
                            Component.onCompleted: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = "#ffffff"
                                ctx.strokeStyle = "#ffffff"
                                ctx.lineWidth = 1.8
                                ctx.lineCap = "round"

                                // Speaker body (trapezoid with rectangular base)
                                ctx.beginPath()
                                ctx.moveTo(3, 9)
                                ctx.lineTo(3, 15)
                                ctx.lineTo(8, 15)
                                ctx.lineTo(13, 20)
                                ctx.lineTo(13, 4)
                                ctx.lineTo(8, 9)
                                ctx.closePath()
                                ctx.fill()

                                if (muted) {
                                    // Cross mark to the right
                                    ctx.beginPath()
                                    ctx.moveTo(16, 8)
                                    ctx.lineTo(22, 16)
                                    ctx.moveTo(22, 8)
                                    ctx.lineTo(16, 16)
                                    ctx.stroke()
                                } else {
                                    // Two concentric sound-wave arcs
                                    ctx.beginPath()
                                    ctx.arc(14, 12, 3.5, -Math.PI / 3, Math.PI / 3)
                                    ctx.stroke()
                                    ctx.beginPath()
                                    ctx.arc(14, 12, 6.5, -Math.PI / 3, Math.PI / 3)
                                    ctx.stroke()
                                }
                            }
                        }

                        MouseArea {
                            id: muteBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: muteBtn.muteHov = true
                            onExited: muteBtn.muteHov = false
                            onClicked: {
                                muteBtn.forceActiveFocus()
                                if (appViewModel) {
                                    var newMuted = !appViewModel.player.muted
                                    appViewModel.player.muted = newMuted
                                }
                            }
                        }
                    }

                    Slider {
                        id: volumeSlider
                        Layout.preferredWidth: 100
                        from: 0
                        to: 100
                        stepSize: 5
                        value: appViewModel ? appViewModel.player.volume : 100
                        focusPolicy: Qt.NoFocus

                        onMoved: {
                            if (appViewModel) appViewModel.player.volume = value
                        }

                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - 2
                            width: volumeSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#40ffffff"

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: "#ffffff"
                            }
                        }

                        handle: Rectangle {
                            x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                            y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                            width: 12
                            height: 12
                            radius: 6
                            color: "#ffffff"
                        }
                    }

                    PlayerButton {
                        id: stretchBtn
                        text: appViewModel && appViewModel.player.stretched ? "⇤⇥" : "⇔"
                        iconSize: 16
                        ToolTip.visible: stretchBtn.btnHovered
                        ToolTip.text: appViewModel && appViewModel.player.stretched ? "Original aspect" : "Stretch 16:9"
                        ToolTip.delay: 500
                        onClicked: {
                            if (appViewModel) appViewModel.player.toggleStretch()
                        }
                    }

                    PlayerButton {
                        id: fullscreenBtn
                        text: videoFullscreen ? "⤢" : "⛶\uFE0E"
                        iconSize: 20
                        onClicked: toggleVideoFullscreen()
                    }
                }
            }
        }

        // --- Top overlay with back button, title, EPG info, and clock ---
        Rectangle {
            id: topOverlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56
            visible: controlsOverlay.visible
            opacity: controlsOverlay.opacity

            property bool epgInfoVisible: {
                if (!appViewModel) return false
                return appViewModel.player.isLive
                    && appViewModel.player.epgChannelId.length > 0
                    && epgNowText.length > 0
            }
            property string epgNowText: ""
            property string epgNextText: ""
            property string epgNextTime: ""
            property bool epgShowNext: false

            function refreshEpg() {
                if (!appViewModel || !appViewModel.player.isLive) return
                var epgId = appViewModel.player.epgChannelId
                if (!epgId) return
                epgNowText = appViewModel.currentProgrammeTitle(epgId)
                epgNextText = appViewModel.nextProgrammeTitle(epgId)
                epgNextTime = appViewModel.nextProgrammeTime(epgId)
            }

            Timer {
                id: epgRefreshTimer
                interval: 60000
                running: topOverlay.epgInfoVisible
                repeat: true
                onTriggered: topOverlay.refreshEpg()
            }

            Timer {
                id: epgRotateTimer
                interval: 5000
                running: topOverlay.epgInfoVisible && topOverlay.epgNextText.length > 0
                repeat: true
                onTriggered: topOverlay.epgShowNext = !topOverlay.epgShowNext
            }

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#cc000000" }
                GradientStop { position: 0.6; color: "#80000000" }
                GradientStop { position: 1.0; color: "transparent" }
            }

            Behavior on height {
                NumberAnimation { duration: Theme.animFast }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd

                PlayerButton {
                    text: "\u2190"
                    onClicked: goBack()
                }

                Text {
                    text: appViewModel ? appViewModel.player.channelName : ""
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width * 0.35
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 3
                    radius: 2
                    color: "#30ffffff"
                    visible: appViewModel ? (appViewModel.player.position <= 0 && !appViewModel.player.stopped) : false

                    Rectangle {
                        anchors.left: parent.left
                        height: parent.height
                        radius: 2
                        width: parent.width * bufferAnim.value
                        color: Theme.accent
                    }

                    SequentialAnimation {
                        id: bufferAnim
                        property real value: 0
                        running: parent.visible
                        loops: Animation.Infinite
                        NumberAnimation { target: bufferAnim; property: "value"; from: 0; to: 0.7; duration: 600 }
                        NumberAnimation { target: bufferAnim; property: "value"; from: 0.7; to: 1.0; duration: 300 }
                        NumberAnimation { target: bufferAnim; property: "value"; from: 1.0; to: 0; duration: 300 }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: topOverlay.epgInfoVisible

                    Text {
                        id: epgNowLabel
                        anchors.centerIn: parent
                        width: parent.width
                        text: "Now: " + topOverlay.epgNowText
                        font.pixelSize: Theme.fontSizeMd
                        color: "#ffffff"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        opacity: topOverlay.epgShowNext ? 0.0 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
                    }

                    Text {
                        id: epgNextLabel
                        anchors.centerIn: parent
                        width: parent.width
                        text: {
                            if (!topOverlay.epgNextText) return ""
                            var t = "Next: " + topOverlay.epgNextText
                            if (topOverlay.epgNextTime) t += " (" + topOverlay.epgNextTime + ")"
                            return t
                        }
                        font.pixelSize: Theme.fontSizeMd
                        color: "#ffffff"
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        opacity: topOverlay.epgShowNext ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    visible: !topOverlay.epgInfoVisible
                }

                Rectangle {
                    visible: appViewModel && (appViewModel.player.cacheSpeed > 0 || appViewModel.player.videoBitrate > 0 || appViewModel.player.videoHeight > 0)
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: metricsRow.implicitWidth + Theme.spacingSm * 2
                    radius: 11
                    color: Qt.rgba(255, 255, 255, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.18)

                    Row {
                        id: metricsRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXs

                        Text {
                            visible: appViewModel && appViewModel.player.cacheSpeed > 0
                            text: appViewModel ? playerView.formatBitrate(appViewModel.player.cacheSpeed) : ""
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }

                        Rectangle {
                            visible: appViewModel && appViewModel.player.cacheSpeed > 0
                                     && appViewModel.player.videoBitrate > 0
                            width: 1
                            height: 10
                            radius: 0.5
                            color: Qt.rgba(255, 255, 255, 0.30)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: appViewModel && appViewModel.player.videoBitrate > 0
                            text: appViewModel ? playerView.formatBitrate(appViewModel.player.videoBitrate) : ""
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }

                        Rectangle {
                            visible: appViewModel && ((appViewModel.player.cacheSpeed > 0 || appViewModel.player.videoBitrate > 0) && appViewModel.player.videoHeight > 0)
                            width: 1
                            height: 10
                            radius: 0.5
                            color: Qt.rgba(255, 255, 255, 0.30)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            visible: appViewModel && appViewModel.player.videoHeight > 0
                            text: appViewModel ? playerView.formatResolution(appViewModel.player.videoHeight) : ""
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }
                    }
                }

                Rectangle {
                    visible: appViewModel && (appViewModel.player.cacheSpeed > 0 || appViewModel.player.videoBitrate > 0)
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 12
                    radius: 0.5
                    color: Qt.rgba(255, 255, 255, 0.25)
                }

                Text {
                    id: clockText
                    text: Qt.formatTime(new Date(), "HH:mm")
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    color: "#ffffff"
                }
            }
        }

        // --- Persistent recording indicator (always visible, not part of auto-hiding OSD) ---
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.spacingMd
            width: recIndicatorRow.implicitWidth + Theme.spacingMd * 2
            height: 28
            radius: 14
            color: Theme.error
            visible: recBtn.recActive
            z: 20

            Row {
                id: recIndicatorRow
                anchors.centerIn: parent
                spacing: Theme.spacingSm

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: recBtn.recActive
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }

                Text {
                    text: "REC"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // --- Subtitle track picker popup ---
        Rectangle {
            id: subTrackPopup
            visible: false
            // controller focus handled in merged onVisibleChanged below
            anchors.right: parent.right
            anchors.bottom: controlsOverlay.top
            anchors.rightMargin: Theme.spacingLg
            anchors.bottomMargin: Theme.spacingSm
            width: 300
            height: subTrackCol.implicitHeight + Theme.spacingMd * 2
            radius: Theme.borderRadius
            color: "#e0202020"
            z: 15

            onVisibleChanged: {
                if (visible) {
                    if (appViewModel) appViewModel.player.refreshSubtitleTracks()
                    subTrackList.forceActiveFocus()
                    if (subTrackList.currentIndex < 0) subTrackList.currentIndex = 0
                }
            }

            ColumnLayout {
                id: subTrackCol
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Text {
                    text: "Subtitles"
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: "#ffffff"
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Show subtitles"
                        font.pixelSize: Theme.fontSizeXs
                        color: "#ccffffff"
                        Layout.fillWidth: true
                    }

                    Switch {
                        id: subVisSwitch
                        checked: true
                        onToggled: {
                            if (appViewModel) appViewModel.player.setSubtitleVisibility(checked)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#40ffffff" }

                Text {
                    text: "Subtitle tracks"
                    font.pixelSize: Theme.fontSizeXs
                    font.bold: true
                    color: "#ccffffff"
                    visible: subTrackList.count > 0
                }

                Rectangle {
                    visible: subTrackList.count > 0
                    Layout.fillWidth: true
                    height: Math.min(subTrackList.contentHeight, 150)
                    color: "transparent"

                    ListView {
                        id: subTrackList
                        anchors.fill: parent
                        clip: true
                        keyNavigationEnabled: true
                        highlightFollowsCurrentItem: true
                        Keys.onReturnPressed: if (currentIndex >= 0 && currentItem) { appViewModel.player.selectSubtitleTrack(model[currentIndex].id); subTrackPopup.visible = false }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onEscapePressed: subTrackPopup.visible = false
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select) { Keys.onReturnPressed(event); event.accepted = true }
                            else if (event.key === Qt.Key_Back) { subTrackPopup.visible = false; event.accepted = true }
                        }
                        model: {
                            if (!appViewModel) return []
                            var tracks = appViewModel.player.subtitleTracks
                            var primary = appViewModel.subtitleLanguage || ""
                            var secondary = appViewModel.subtitleLanguageSecondary || ""
                            var filtered = []
                            var externalCounts = {}
                            function labelTrack(item) {
                                var lang = playerView.langName(item.lang)
                                if (!lang) lang = "Unknown"
                                if (item.external) {
                                    var key = lang.toLowerCase()
                                    externalCounts[key] = (externalCounts[key] || 0) + 1
                                    item.displayLabel = lang + " - Ext - #" + externalCounts[key]
                                } else {
                                    item.displayLabel = lang + " - Builtin"
                                }
                                return item
                            }

                            for (var i = 0; i < tracks.length; i++) {
                                var t = tracks[i]
                                labelTrack(t)
                                if (t.selected
                                    || playerView.langMatches(t.lang, primary)
                                    || playerView.langMatches(t.lang, secondary)
                                    || !t.lang)
                                    filtered.push(t)
                            }
                            if (!primary && !secondary) {
                                return tracks
                            }
                            return filtered.length > 0 ? filtered : tracks
                        }
                        spacing: 2

                        delegate: Rectangle {
                            width: subTrackList.width
                            height: 36
                            radius: 6
                            color: modelData.selected ? Theme.accent
                                                     : stHov ? "#30ffffff"
                                                              : "#15ffffff"
                            border.width: 0
                            property bool stHov: false

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: modelData.selected ? "✓" : "○"
                                    font.pixelSize: 12
                                    color: modelData.selected ? Theme.textOnAccent : stHov ? "#bbffffff" : "#60ffffff"
                                }

                                Text {
                                    text: modelData.displayLabel || (playerView.langName(modelData.lang) || "Unknown")
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: modelData.selected
                                    color: modelData.selected ? Theme.textOnAccent : stHov ? "#eeffffff" : "#ccffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.stHov = true
                                onExited: parent.stHov = false
                                onClicked: {
                                    if (appViewModel) appViewModel.player.selectSubtitleTrack(modelData.id)
                                    subTrackPopup.visible = false
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: subTrackList.count === 0
                    text: "No subtitle tracks available"
                    font.pixelSize: Theme.fontSizeXs
                    color: "#80ffffff"
                    font.italic: true
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#40ffffff" }

                Text {
                    text: "Subtitle delay: " + subDelaySlider.value.toFixed(1) + "s"
                    font.pixelSize: Theme.fontSizeXs
                    color: "#ccffffff"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    PlayerButton {
                        text: "-"
                        btnSize: 28
                        iconSize: 16
                        onClicked: {
                            subDelaySlider.value -= 0.5
                            if (appViewModel) appViewModel.player.setSubtitleDelay(subDelaySlider.value)
                        }
                    }

                    Slider {
                        id: subDelaySlider
                        Layout.fillWidth: true
                        from: -10
                        to: 10
                        value: 0
                        stepSize: 0.1

                        onMoved: {
                            if (appViewModel) appViewModel.player.setSubtitleDelay(value)
                        }

                        background: Rectangle {
                            x: subDelaySlider.leftPadding
                            y: subDelaySlider.topPadding + subDelaySlider.availableHeight / 2 - 2
                            width: subDelaySlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#40ffffff"

                            Rectangle {
                                x: parent.width / 2
                                width: Math.abs(subDelaySlider.visualPosition - 0.5) * parent.width
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }
                        }

                        handle: Rectangle {
                            x: subDelaySlider.leftPadding + subDelaySlider.visualPosition * (subDelaySlider.availableWidth - width)
                            y: subDelaySlider.topPadding + subDelaySlider.availableHeight / 2 - height / 2
                            width: 12; height: 12; radius: 6
                            color: "#ffffff"
                        }
                    }

                    PlayerButton {
                        text: "+"
                        btnSize: 28
                        iconSize: 16
                        onClicked: {
                            subDelaySlider.value += 0.5
                            if (appViewModel) appViewModel.player.setSubtitleDelay(subDelaySlider.value)
                        }
                    }
                }

                PlayerButton {
                    text: "Reset"
                    btnSize: 28
                    iconSize: 11
                    onClicked: {
                        subDelaySlider.value = 0
                        if (appViewModel) appViewModel.player.setSubtitleDelay(0)
                    }
                }
            }
        }

        // --- Audio track popup ---
        Rectangle {
            id: audioTrackPopup
            visible: false
            focus: visible
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80
            anchors.rightMargin: Theme.spacingMd
            width: 280
            height: Math.min(audioTrackCol.implicitHeight + Theme.spacingMd * 2, 350)
            radius: Theme.borderRadiusLarge
            color: "#e0202020"
            property int audioTrackFocusIndex: 0

            onVisibleChanged: {
                if (visible) {
                    if (appViewModel) appViewModel.player.refreshAudioTracks()
                    Qt.callLater(function() {
                        if (audioTrackRepeater.count > 0) {
                            audioTrackFocusIndex = 0
                            var item = audioTrackRepeater.itemAt(0)
                            if (item) item.forceActiveFocus()
                        }
                    })
                }
            }
            border.color: "#40ffffff"
            border.width: 1
            z: 50

            Keys.onEscapePressed: audioTrackPopup.visible = false
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    audioTrackPopup.visible = false
                    event.accepted = true
                }
            }

            function focusAudioTrackAt(idx) {
                idx = Math.max(0, Math.min(audioTrackRepeater.count - 1, idx))
                audioTrackFocusIndex = idx
                var item = audioTrackRepeater.itemAt(idx)
                if (item) item.forceActiveFocus()
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                contentHeight: audioTrackCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: audioTrackCol
                    width: parent.width
                    spacing: Theme.spacingSm

                    Text {
                        text: "Audio tracks"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: "#ffffff"
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#40ffffff" }

                    Repeater {
                        id: audioTrackRepeater
                        model: appViewModel ? appViewModel.player.audioTracks : []

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 4
                            color: modelData.selected ? Theme.accent
                                                     : (atHov || activeFocus) ? "#30ffffff"
                                                              : "#15ffffff"
                            border.width: 0
                            property bool atHov: false
                            focus: false
                            activeFocusOnTab: true

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: modelData.selected ? "✓" : "○"
                                    font.pixelSize: 12
                                    color: modelData.selected ? Theme.textOnAccent : atHov ? "#bbffffff" : "#60ffffff"
                                }

                                Text {
                                    text: {
                                        var lang = playerView.langName(modelData.lang)
                                        var title = modelData.title || ""
                                        if (lang && title) return lang + " — " + title
                                        if (lang) return lang
                                        if (title) return title
                                        return "Track " + modelData.id
                                    }
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: modelData.selected
                                    color: modelData.selected ? Theme.textOnAccent : atHov ? "#eeffffff" : "#ccffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.atHov = true
                                onExited: parent.atHov = false
                                onClicked: {
                                    if (appViewModel) appViewModel.player.selectAudioTrack(modelData.id)
                                    audioTrackPopup.visible = false
                                }
                            }

                            onActiveFocusChanged: parent.atHov = activeFocus

                            Keys.onReturnPressed: {
                                if (appViewModel) appViewModel.player.selectAudioTrack(modelData.id)
                                audioTrackPopup.visible = false
                            }
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onUpPressed: audioTrackPopup.focusAudioTrackAt(index - 1)
                            Keys.onDownPressed: audioTrackPopup.focusAudioTrackAt(index + 1)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    Keys.onReturnPressed(event)
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Chromecast device picker popup ---
        Rectangle {
            id: castDevicePopup
            visible: false
            focus: visible
            anchors.right: parent.right
            anchors.bottom: controlsOverlay.top
            anchors.rightMargin: Theme.spacingLg
            anchors.bottomMargin: Theme.spacingSm
            width: 280
            height: castDeviceCol.implicitHeight + Theme.spacingMd * 2
            radius: Theme.borderRadiusLarge
            color: "#e0202020"
            border.color: "#40ffffff"
            border.width: 1
            z: 50
            property int castDeviceFocusIndex: 0

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(function() {
                        if (castDeviceRepeater.count > 0) {
                            castDeviceFocusIndex = 0
                            var item = castDeviceRepeater.itemAt(0)
                            if (item) item.forceActiveFocus()
                        }
                    })
                }
            }

            Keys.onEscapePressed: castDevicePopup.visible = false
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    castDevicePopup.visible = false
                    event.accepted = true
                }
            }

            function focusDeviceAt(idx) {
                idx = Math.max(0, Math.min(castDeviceRepeater.count - 1, idx))
                castDeviceFocusIndex = idx
                var item = castDeviceRepeater.itemAt(idx)
                if (item) item.forceActiveFocus()
            }

            ColumnLayout {
                id: castDeviceCol
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Text {
                    text: "Cast to device"
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: "#ffffff"
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#40ffffff" }

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    width: 24; height: 24
                    running: castDevicePopup.visible
                    visible: appViewModel ? appViewModel.chromecast.devices.length === 0 : true
                }

                Text {
                    visible: appViewModel ? appViewModel.chromecast.devices.length === 0 : true
                    text: "Searching for Chromecast devices..."
                    font.pixelSize: Theme.fontSizeXs
                    color: "#80ffffff"
                    font.italic: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Repeater {
                    id: castDeviceRepeater
                    model: appViewModel ? appViewModel.chromecast.devices : []

                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 6
                        color: (castDevHov || activeFocus) ? "#30ffffff" : "#15ffffff"
                        property bool castDevHov: false
                        focus: false
                        activeFocusOnTab: true

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "▭"
                                font.family: "DejaVu Sans"
                                font.pixelSize: 16
                                color: Theme.textPrimary
                            }

                            Text {
                                text: modelData.name || "Chromecast"
                                font.pixelSize: Theme.fontSizeSm
                                color: "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.castDevHov = true
                            onExited: parent.castDevHov = false
                            onClicked: {
                                if (appViewModel) {
                                    // Capture URL before stopping player
                                    playerView.pendingCastUrl = appViewModel.player.currentUrl()
                                    playerView.pendingCastName = appViewModel.player.channelName
                                    playerView.pendingCastCt = appViewModel.player.isLive ? "video/mp2t" : "video/mp4"
                                    appViewModel.chromecast.connectToDevice(index)
                                    castDevicePopup.visible = false
                                    castConnectTimer.start()
                                }
                            }
                        }

                        onActiveFocusChanged: parent.castDevHov = activeFocus

                        Keys.onReturnPressed: {
                            if (appViewModel) {
                                playerView.pendingCastUrl = appViewModel.player.currentUrl()
                                playerView.pendingCastName = appViewModel.player.channelName
                                playerView.pendingCastCt = appViewModel.player.isLive ? "video/mp2t" : "video/mp4"
                                appViewModel.chromecast.connectToDevice(index)
                                castDevicePopup.visible = false
                                castConnectTimer.start()
                            }
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onUpPressed: castDevicePopup.focusDeviceAt(index - 1)
                        Keys.onDownPressed: castDevicePopup.focusDeviceAt(index + 1)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                Keys.onReturnPressed(event)
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }

        // --- Simple stop casting popup ---
        Rectangle {
            id: castStopPopup
            visible: false
            focus: visible
            anchors.right: parent.right
            anchors.bottom: controlsOverlay.top
            anchors.rightMargin: Theme.spacingLg
            anchors.bottomMargin: Theme.spacingSm
            width: 220
            height: castStopCol.implicitHeight + Theme.spacingMd * 2
            radius: Theme.borderRadiusLarge
            color: "#e0202020"
            border.color: "#40ffffff"
            border.width: 1
            z: 50
            Keys.onEscapePressed: castStopPopup.visible = false
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    castStopPopup.visible = false
                    event.accepted = true
                }
            }

            ColumnLayout {
                id: castStopCol
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                spacing: Theme.spacingSm

                Text {
                    text: "Casting to " + (appViewModel ? appViewModel.chromecast.connectedDeviceName : "")
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#40ffffff" }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 6
                    color: (castStopBtnHov || activeFocus) ? Theme.error : "#20ffffff"
                    property bool castStopBtnHov: false

                    Text {
                        anchors.centerIn: parent
                        text: "Stop casting"
                        font.pixelSize: Theme.fontSizeSm
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.castStopBtnHov = true
                        onExited: parent.castStopBtnHov = false
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.chromecast.stopMedia()
                                appViewModel.chromecast.disconnect()
                                castStopPopup.visible = false
                            }
                        }
                    }

                    onActiveFocusChanged: parent.castStopBtnHov = activeFocus

                    Keys.onReturnPressed: {
                        if (appViewModel) {
                            appViewModel.chromecast.stopMedia()
                            appViewModel.chromecast.disconnect()
                            castStopPopup.visible = false
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

        Timer {
            id: castConnectTimer
            interval: 2000
            onTriggered: {
                if (appViewModel && appViewModel.chromecast.connected && playerView.pendingCastUrl) {
                    appViewModel.player.stop()
                    appViewModel.chromecast.castMedia(playerView.pendingCastUrl, playerView.pendingCastName, playerView.pendingCastCt)
                    playerView.pendingCastUrl = ""
                }
            }
        }

        // --- Logo placeholder (stopped + loading) ---
        Image {
            id: logoPlaceholder
            anchors.centerIn: parent
            property bool isLoading: appViewModel ? (appViewModel.player.position <= 0 && !appViewModel.player.stopped) : false
            visible: (appViewModel ? appViewModel.player.stopped : true) || isLoading
            width: 128; height: 128
            source: "qrc:/images/iptvxs_tray.png"
            fillMode: Image.PreserveAspectFit
            opacity: 0.15

            SequentialAnimation on opacity {
                id: pulseAnim
                running: logoPlaceholder.isLoading
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.08; duration: 1000; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) logoPlaceholder.opacity = 0.15
            }
        }

        // --- Auto-next episode OSD ---
        Rectangle {
            id: autoNextOsd
            visible: appViewModel ? appViewModel.player.autoNextEnabled : false
            focus: visible
            onVisibleChanged: if (visible) forceActiveFocus()
            Keys.onReturnPressed: if (appViewModel) appViewModel.player.cancelAutoNext()
            Keys.onEnterPressed: if (appViewModel) appViewModel.player.cancelAutoNext()
            Keys.onEscapePressed: if (appViewModel) appViewModel.player.cancelAutoNext()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Select || event.key === Qt.Key_Back
                        || event.key === Qt.Key_B || event.key === Qt.Key_Space) {
                    if (appViewModel) appViewModel.player.cancelAutoNext()
                    event.accepted = true
                }
            }
            anchors.bottom: controlsOverlay.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: Theme.spacingMd
            width: autoNextContent.implicitWidth + Theme.spacingLg * 2
            height: autoNextContent.implicitHeight + Theme.spacingMd * 2
            radius: Theme.borderRadiusLarge
            color: "#dd1a1a2e"
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.38)
            border.width: 1
            z: 30

            ColumnLayout {
                id: autoNextContent
                anchors.centerIn: parent
                spacing: Theme.spacingSm

                Text {
                    text: "Up Next"
                    font.pixelSize: Theme.fontSizeXs
                    font.bold: true
                    font.letterSpacing: 1.5
                    color: Theme.accent
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: appViewModel ? appViewModel.player.nextEpisodeName : ""
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 400
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 4
                    radius: 2
                    color: "#30ffffff"
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        width: {
                            var cd = appViewModel ? appViewModel.player.autoNextCountdown : 15
                            return Math.max(0, (1.0 - cd / 15.0)) * parent.width
                        }
                        height: parent.height
                        radius: 2
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation { duration: 900 }
                        }
                    }
                }

                Text {
                    text: {
                        var cd = appViewModel ? appViewModel.player.autoNextCountdown : 0
                        return "Playing in " + cd + "..."
                    }
                    font.pixelSize: Theme.fontSizeXs
                    color: "#ccffffff"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.preferredWidth: cancelAutoNextText.implicitWidth + Theme.spacingLg
                    Layout.preferredHeight: 28
                    radius: 14
                    color: cancelAutoNextHov ? "#40ffffff" : "#20ffffff"
                    Layout.alignment: Qt.AlignHCenter
                    property bool cancelAutoNextHov: false

                    Text {
                        id: cancelAutoNextText
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: Theme.fontSizeXs
                        font.bold: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.cancelAutoNextHov = true
                        onExited: parent.cancelAutoNextHov = false
                        onClicked: {
                            if (appViewModel) appViewModel.player.cancelAutoNext()
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
    }

    Timer {
        id: pendingTimer
        interval: 500
        onTriggered: {
            if (appViewModel && appViewModel.pendingPlayUrl) {
                var url = appViewModel.pendingPlayUrl
                var name = appViewModel.pendingPlayName
                appViewModel.pendingPlayUrl = ""
                appViewModel.pendingPlayName = ""
                appViewModel.player.play(url, name, "", 0)
            }
        }
    }

    Timer {
        id: subSearchTimer
        interval: 2000
        onTriggered: {
            if (appViewModel && !appViewModel.player.isLive) {
                appViewModel.player.refreshSubtitleTracks()
                appViewModel.player.refreshAudioTracks()
                if (appViewModel.subtitlesEnabled) {
                    var name = appViewModel.player.channelName
                    if (name) appViewModel.searchSubtitles(name)
                }
            }
        }
    }

    property bool controlsVisible: true

    Timer {
        id: controlsTimer
        interval: 3000
        running: appViewModel ? (!appViewModel.player.stopped) : false
        onTriggered: controlsVisible = false
    }

    function showControls() {
        controlsVisible = true
        controlsTimer.restart()
    }

    Component.onCompleted: {
        if (appViewModel) {
            appViewModel.videoFullscreen = false
            var win = playerView.Window.window
            if (win && win.visibility === Window.FullScreen) win.showNormal()
        }
        if (appViewModel && appViewModel.pendingPlayUrl) {
            pendingTimer.start()
        } else if (channelUrl && appViewModel) {
            appViewModel.player.play(channelUrl, channelName, channelLogo)
        }

        if (appViewModel && !appViewModel.player.isLive) {
            subSearchTimer.start()
        }

        // Refresh EPG info for live channels
        if (appViewModel && appViewModel.player.isLive) {
            topOverlay.refreshEpg()
        }
    }

    Connections {
        target: appViewModel ? appViewModel.chromecast : null
        function onCastError(message) {
            console.warn("Cast error:", message)
        }
        function onCastStarted() {
            console.log("Cast started successfully")
        }
    }

    Connections {
        target: appViewModel ? appViewModel.player : null
        function onEpgChannelIdChanged() {
            topOverlay.refreshEpg()
        }
        function onIsLiveChanged() {
            if (appViewModel && appViewModel.player.isLive) {
                topOverlay.refreshEpg()
            }
        }
        function onLiveReconnectFailed(message) {
            reconnectToast.show(message)
        }
    }

    function toggleVideoFullscreen() {
        if (!appViewModel) return
        var win = playerView.Window.window
        if (!win) return

        if (appViewModel.videoFullscreen) {
            appViewModel.videoFullscreen = false
            win.showNormal()
        } else {
            appViewModel.videoFullscreen = true
            win.showFullScreen()
        }
    }

    function goBack() {
        if (appViewModel && appViewModel.videoFullscreen) {
            appViewModel.videoFullscreen = false
            var win = playerView.Window.window
            if (win) win.showNormal()
            return
        }
        if (appViewModel) {
            appViewModel.player.stop()
            var prev = appViewModel.previousView()
            appViewModel.currentView = prev
            Qt.callLater(function() {
                var w = playerView.Window.window
                if (w && w.requestViewFocusRestore) {
                    w.requestViewFocusRestore()
                } else if (w && w.focusCurrentViewPrimary) {
                    w.focusCurrentViewPrimary()
                }
            })
        }
    }

    Rectangle {
        id: reconnectToast
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingXl * 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Theme.spacingXl * 4, reconnectToastText.implicitWidth + 48)
        height: 42
        radius: 21
        color: Theme.surfaceElevated
        border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.6)
        border.width: 1
        opacity: 0
        z: 5000

        function show(message) {
            reconnectToastText.text = message && message.length > 0
                ? message
                : "Live stream reconnect failed"
            opacity = 1
            reconnectToastTimer.restart()
        }

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Timer {
            id: reconnectToastTimer
            interval: 3500
            onTriggered: reconnectToast.opacity = 0
        }

        Text {
            id: reconnectToastText
            anchors.centerIn: parent
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSm
            font.bold: true
            color: Theme.error
        }
    }

    Keys.onSpacePressed: { if (appViewModel) appViewModel.player.togglePause(); showControls() }
    Keys.onLeftPressed: {
        var focusedIdx = focusedControlIndex()
        if (focusedIdx > 0) {
            focusControlButton(focusedIdx - 1)
        } else if (focusedIdx === 0 && !videoFullscreen) {
            var win = playerView.Window.window
            if (win && win.focusSidebar) win.focusSidebar()
        } else if (appViewModel) {
            appViewModel.player.seek(Math.max(0, appViewModel.player.position - 10))
            showControls()
        }
    }
    Keys.onRightPressed: {
        var focusedIdx = focusedControlIndex()
        if (focusedIdx >= 0) {
            focusControlButton(focusedIdx + 1)
        } else if (appViewModel) {
            appViewModel.player.seek(appViewModel.player.position + 10)
            showControls()
        }
    }
    Keys.onUpPressed: {
        if (focusedControlIndex() >= 0) {
            playerView.forceActiveFocus()
            showControls()
        } else if (appViewModel) {
            appViewModel.player.volumeUp()
            showControls()
        }
    }
    Keys.onDownPressed: {
        if (focusedControlIndex() < 0 && controlsVisible) {
            focusControlButton(0)
        } else if (appViewModel && focusedControlIndex() < 0) {
            appViewModel.player.volumeDown()
            showControls()
        }
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_M) {
            if (appViewModel) appViewModel.player.toggleMute()
            showControls()
        } else if (event.key === Qt.Key_F) {
            toggleVideoFullscreen()
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            goBack()
            event.accepted = true
        } else if (event.key === Qt.Key_B && focusedControlIndex() < 0) {
            goBack()
            event.accepted = true
        }
    }

    focus: true

    component PlayerButton: Rectangle {
        id: playerBtn
        property alias text: btnText.text
        property color btnColor: "transparent"
        property int btnSize: 44
        property int iconSize: 18
        signal clicked()

        width: btnSize
        height: btnSize
        radius: Theme.borderRadius
        color: btnColor

        property bool btnHovered: false
        activeFocusOnTab: true
        border.width: activeFocus ? 2 : 0
        border.color: Theme.accent

        // Hover overlay layered ON TOP of btnColor so the recording-state color
        // (e.g. Theme.error) remains visible while the mouse is over the button.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#40ffffff"
            visible: playerBtn.btnHovered
        }

        Text {
            id: btnText
            anchors.centerIn: parent
            font.pixelSize: iconSize
            color: "#ffffff"
            z: 1
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: playerBtn.btnHovered = true
            onExited: playerBtn.btnHovered = false
            onClicked: {
                playerBtn.forceActiveFocus()
                playerBtn.clicked()
            }
        }

        Keys.onReturnPressed: playerBtn.clicked()
        Keys.onEnterPressed: playerBtn.clicked()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                playerBtn.clicked()
                event.accepted = true
            }
        }
    }
}
