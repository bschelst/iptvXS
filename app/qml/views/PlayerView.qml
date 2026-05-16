// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import app.iptvxs

Item {
    id: playerView

    // Called by Main.qml when this view becomes active. Without this,
    // no element grabs focus on entry → existing Keys.onDownPressed
    // handler at the bottom of the file never fires, so D-pad Down
    // does nothing until the user clicks first.
    function focusPrimary() {
        playerView.forceActiveFocus()
        showControls()
    }

    property string channelUrl: ""
    property string channelName: ""
    property string channelLogo: ""
    property bool videoFullscreen: appViewModel ? appViewModel.videoFullscreen : false
    property string pendingCastUrl: ""
    property string pendingCastName: ""
    property string pendingCastCt: ""
    property bool seriesDialogVisible: false
    property string seriesDialogTitle: ""
    property var seriesDialogSeasons: []
    property int seriesDialogSelectedSeason: 0
    property int seriesDialogChannelId: 0
    property bool zapDialogVisible: false
    property bool catchupDialogVisible: false
    property var audioTrackPopupRef: null
    property date hudNow: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: playerView.hudNow = new Date()
    }

    // Server-side timeshift availability for the currently-playing channel.
    // Re-evaluates only when the active channelId changes.
    readonly property int currentChannelTvArchive: {
        if (!appViewModel || !appViewModel.player.channelId) return 0
        var info = appViewModel.channelInfo(appViewModel.player.channelId)
        return info && info.tvArchive ? info.tvArchive : 0
    }
    readonly property int currentChannelArchiveDays: {
        if (!appViewModel || !appViewModel.player.channelId) return 0
        var info = appViewModel.channelInfo(appViewModel.player.channelId)
        return info && info.tvArchiveDuration ? info.tvArchiveDuration : 0
    }

    function visibleControlButtons() {
        var buttons = [playPauseBtn, stopBtn, favBtn, recBtn, castBtn, zapPrevBtn, zapNextBtn, zapBtn, ccBtn, audioBtn, episodeBtn, catchupBtn, muteBtn, stretchBtn, fullscreenBtn]
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

    function stepControlFocus(delta) {
        var buttons = visibleControlButtons()
        if (!buttons.length) return
        var current = focusedControlIndex()
        if (current < 0) {
            current = delta > 0 ? -1 : buttons.length
        }
        var idx = Math.max(0, Math.min(buttons.length - 1, current + delta))
        buttons[idx].forceActiveFocus()
        showControls()
    }

    function focusSeekSlider() {
        showControls()
        Qt.callLater(function() {
            if (seekSlider && seekSlider.visible) {
                seekSlider.forceActiveFocus()
            } else if (topBackBtn && topBackBtn.visible) {
                topBackBtn.forceActiveFocus()
            } else {
                focusControlButton(0)
            }
        })
    }

    function focusControlsEntry() {
        showControls()
        Qt.callLater(function() {
            if (seekSlider && seekSlider.visible) {
                seekSlider.forceActiveFocus()
            } else {
                focusControlButton(0)
            }
        })
    }

    function focusTopBackButton() {
        showControls()
        Qt.callLater(function() {
            if (topBackBtn && topBackBtn.visible) {
                topBackBtn.forceActiveFocus()
            } else {
                focusControlsEntry()
            }
        })
    }

    function clampListIndex(listView) {
        if (!listView) return
        if (listView.count <= 0) {
            listView.currentIndex = -1
        } else if (listView.currentIndex < 0 || listView.currentIndex >= listView.count) {
            listView.currentIndex = 0
        }
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

    function formatAudioPreset(preset) {
        if (!preset || preset === "none") return ""
        if (preset === "extra_bass") return "Extra Bass"
        if (preset === "flat") return "Flat"
        if (preset === "dance") return "Dance"
        if (preset === "rock") return "Rock"
        if (preset === "voice") return "Voice"
        if (preset === "cinema") return "Cinema"
        return preset.charAt(0).toUpperCase() + preset.slice(1)
    }

    function logoSource(url) {
        if (!url || url.length === 0) return ""
        if (!appViewModel || !appViewModel.logoCache || url.indexOf("http") !== 0) {
            return url
        }
        var _ = appViewModel.logoCache.revision
        var __ = appViewModel.logoCache.failedRevision
        return appViewModel.logoCache.resolve(url)
    }

    function hudLogoSource() {
        var url = appViewModel ? appViewModel.player.channelLogo : ""
        if (!url || url.length === 0) return "qrc:/images/iptvxs_logo.png"
        var resolved = logoSource(url)
        return resolved && resolved.length > 0 ? resolved : "qrc:/images/iptvxs_logo.png"
    }

    function playbackInfoText() {
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

    function showSeriesDialog(seriesName, seasons) {
        seriesDialogTitle = seriesName
        seriesDialogSeasons = seasons || []
        seriesDialogSelectedSeason = 0
        seriesDialogChannelId = appViewModel ? appViewModel.activeSeriesChannelId() : 0
        seriesDialogVisible = seriesDialogSeasons.length > 0
        if (seriesDialogVisible && seriesEpisodeList) {
            seriesEpisodeList.currentIndex = 0
            seriesEpisodeList.forceActiveFocus()
        }
        if (appViewModel) appViewModel.clearPendingSeriesEpisodes()
    }

    function showZapDialog() {
        if (!appViewModel || !appViewModel.hasZapContext) return
        zapDialogVisible = appViewModel.hasZapContext
        if (zapDialogVisible && zapList) {
            var idx = appViewModel.zapContextIndex
            zapList.currentIndex = idx >= 0 ? idx : 0
            zapList.forceActiveFocus()
            zapList.positionViewAtIndex(zapList.currentIndex, ListView.Contain)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            // Filter out sub-pixel pointer jitter so the auto-hide timer can
            // actually fire. On the Steam Deck the touchpad reports tiny
            // positional updates even when the user isn't intentionally
            // moving — without this threshold the HUD never hides.
            property real lastShownX: -1000
            property real lastShownY: -1000
            onPositionChanged: function(mouse) {
                var dx = mouse.x - lastShownX
                var dy = mouse.y - lastShownY
                if (dx * dx + dy * dy >= 16) {  // 4-pixel deadzone
                    lastShownX = mouse.x
                    lastShownY = mouse.y
                    showControls()
                }
            }
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
            height: 212
            visible: opacity > 0
            opacity: controlsVisible ? 1.0 : 0.0
            color: "transparent"

            Behavior on opacity {
                NumberAnimation { duration: Theme.animNormal }
            }

            Rectangle {
                id: controlsShell
                anchors.fill: parent
                anchors.margins: Theme.spacingMd
                radius: Theme.borderRadiusLarge
                clip: true
                color: Qt.rgba(0, 0, 0, 0.44)
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.10)

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
                    GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.50) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingMd
                    spacing: Theme.spacingSm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 50
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.12)

                            FallbackLogo {
                                anchors.fill: parent
                                logoSource: playerView.hudLogoSource()
                                logoSize: 32
                                logoWidth: 32
                                logoHeight: 32
                                logoOpacity: 1.0
                                logoAreaHeight: 50
                                liveTvGeometry: false
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: appViewModel ? appViewModel.player.channelName : ""
                                font.pixelSize: Theme.fontSizeLg
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: playerView.playbackInfoText()
                                font.pixelSize: Theme.fontSizeSm
                                color: "#d8ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Qt.formatTime(playerView.hudNow, "HH:mm")
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 12
                        visible: topOverlay.epgInfoVisible
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.10)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingMd
                            anchors.rightMargin: Theme.spacingMd
                            spacing: Theme.spacingMd

                            Text {
                                Layout.fillWidth: true
                                text: topOverlay.epgNowText && topOverlay.epgNowText.length > 0
                                    ? ("Now playing: " + topOverlay.epgNowText)
                                    : ""
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (!topOverlay.epgNextText) return ""
                                    var t = "Next: " + topOverlay.epgNextText
                                    if (topOverlay.epgNextTime) t += " (" + topOverlay.epgNextTime + ")"
                                    return t
                                }
                                font.pixelSize: Theme.fontSizeSm
                                color: "#d8ffffff"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignRight
                                visible: text.length > 0
                            }
                        }
                    }

                    Slider {
                        id: seekSlider
                        Layout.fillWidth: true
                        activeFocusOnTab: true
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

                        Keys.onLeftPressed: {
                            if (appViewModel) {
                                appViewModel.player.seek(Math.max(0, appViewModel.player.position - 10))
                                showControls()
                            }
                        }
                        Keys.onRightPressed: {
                            if (appViewModel) {
                                appViewModel.player.seek(appViewModel.player.position + 10)
                                showControls()
                            }
                        }
                        Keys.onDownPressed: {
                            focusControlButton(0)
                        }
                        Keys.onUpPressed: {
                            playerView.forceActiveFocus()
                            showControls()
                        }
                        onActiveFocusChanged: if (activeFocus) showControls()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Item { Layout.fillWidth: true }

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
                            onActiveFocusChanged: if (activeFocus) showControls()
                            Keys.onReturnPressed: castBtnArea.clicked(null)
                            Keys.onEnterPressed: castBtnArea.clicked(null)
                            Keys.onLeftPressed: function(event) { stepControlFocus(-1); event.accepted = true }
                            Keys.onRightPressed: function(event) { stepControlFocus(1); event.accepted = true }
                            Keys.onUpPressed: function(event) { focusSeekSlider(); event.accepted = true }
                            Keys.onDownPressed: function(event) { focusSeekSlider(); event.accepted = true }

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
                                        if (castStopPopup.visible && castDevicePopup.visible) castDevicePopup.closeDialog()
                                    } else if (appViewModel) {
                                        appViewModel.chromecast.startDiscovery()
                                        castDevicePopup.visible = !castDevicePopup.visible
                                        if (castDevicePopup.visible && castStopPopup.visible) castStopPopup.closeDialog()
                                    }
                                }
                            }
                        }

                        PlayerButton {
                            id: zapPrevBtn
                            visible: appViewModel && appViewModel.hasZapContext && appViewModel.player.isLive
                            text: "CH-"
                            iconSize: 11
                            onClicked: {
                                if (appViewModel) appViewModel.zapPrevious()
                                zapDialogVisible = false
                            }
                        }

                        PlayerButton {
                            id: zapNextBtn
                            visible: appViewModel && appViewModel.hasZapContext && appViewModel.player.isLive
                            text: "CH+"
                            iconSize: 11
                            onClicked: {
                                if (appViewModel) appViewModel.zapNext()
                                zapDialogVisible = false
                            }
                        }

                        PlayerButton {
                            id: zapBtn
                            visible: appViewModel && appViewModel.hasZapContext && appViewModel.player.isLive
                            text: "ZAP"
                            iconSize: 11
                            onClicked: showZapDialog()
                        }

                        Rectangle {
                            width: 1; height: 28; color: "#40ffffff"
                            visible: zapPrevBtn.visible || zapNextBtn.visible || zapBtn.visible || ccBtn.visible || audioBtn.visible || episodeBtn.visible || catchupBtn.visible
                        }

                        PlayerButton {
                            id: ccBtn
                            visible: appViewModel && !appViewModel.player.isLive
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
                                    if (appViewModel.hasPendingSeriesEpisodes()) {
                                        showSeriesDialog(appViewModel.pendingSeriesName(), appViewModel.pendingSeriesEpisodes())
                                    } else {
                                        appViewModel.reopenSeriesEpisodes()
                                    }
                                }
                            }
                        }

                        PlayerButton {
                            id: catchupBtn
                            visible: appViewModel
                                     && (appViewModel.player.isLive || appViewModel.player.isCatchup)
                                     && playerView.currentChannelTvArchive > 0
                            text: "↻"
                            iconSize: 16
                            onClicked: catchupDialogVisible = !catchupDialogVisible
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
                            onActiveFocusChanged: if (activeFocus) showControls()
                            Keys.onReturnPressed: muteBtnArea.clicked(null)
                            Keys.onEnterPressed: muteBtnArea.clicked(null)
                            Keys.onLeftPressed: function(event) { stepControlFocus(-1); event.accepted = true }
                            Keys.onRightPressed: function(event) { stepControlFocus(1); event.accepted = true }
                            Keys.onUpPressed: function(event) { focusSeekSlider(); event.accepted = true }
                            Keys.onDownPressed: function(event) { focusSeekSlider(); event.accepted = true }

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

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        // --- Top overlay with back button, title, and clock ---
        Rectangle {
            id: topOverlay
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56
            visible: controlsOverlay.visible || liveInfoVisible
            opacity: controlsOverlay.opacity > 0.0 ? controlsOverlay.opacity
                                                   : (liveInfoVisible ? 1.0 : 0.0)

            property bool liveInfoVisible: {
                if (!appViewModel) return false
                return appViewModel.player.isLive
            }
            property bool epgInfoVisible: {
                if (!appViewModel) return false
                return appViewModel.player.isLive
                    && (epgNowText.length > 0 || epgNextText.length > 0)
            }
            property string epgNowText: ""
            property string epgNextText: ""
            property string epgNextTime: ""

            function refreshEpg() {
                if (!appViewModel || !appViewModel.player.isLive) return
                var epgId = appViewModel.player.epgChannelId || ""
                if (!epgId && appViewModel.player.channelId > 0) {
                    var info = appViewModel.channelInfo(appViewModel.player.channelId)
                    if (info && info.epgChannelId) {
                        epgId = info.epgChannelId
                    }
                }
                epgNowText = epgId ? appViewModel.currentProgrammeTitle(epgId) : ""
                epgNextText = epgId ? appViewModel.nextProgrammeTitle(epgId) : ""
                epgNextTime = epgId ? appViewModel.nextProgrammeTime(epgId) : ""
            }

            Timer {
                id: epgRefreshTimer
                interval: 60000
                running: topOverlay.epgInfoVisible
                repeat: true
                onTriggered: topOverlay.refreshEpg()
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
                    id: topBackBtn
                    text: "\u2190"
                    onClicked: goBack()
                    onActiveFocusChanged: if (activeFocus) showControls()
                    Keys.onDownPressed: focusControlsEntry()
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
                    visible: appViewModel && appViewModel.audioPreset && appViewModel.audioPreset !== "none"
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: audioPresetRow.implicitWidth + Theme.spacingSm * 2
                    radius: 11
                    color: Qt.rgba(255, 255, 255, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.18)

                    Row {
                        id: audioPresetRow
                        anchors.centerIn: parent
                        spacing: Theme.spacingXs

                        Text {
                            text: "Audio"
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }

                        Rectangle {
                            width: 1
                            height: 10
                            radius: 0.5
                            color: Qt.rgba(255, 255, 255, 0.30)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: appViewModel ? playerView.formatAudioPreset(appViewModel.audioPreset) : ""
                            font.pixelSize: 10
                            font.bold: true
                            color: "#ffffff"
                        }
                    }
                }

                Rectangle {
                    visible: appViewModel && ((appViewModel.player.cacheSpeed > 0 || appViewModel.player.videoBitrate > 0)
                             || (appViewModel.audioPreset && appViewModel.audioPreset !== "none"))
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 12
                    radius: 0.5
                    color: Qt.rgba(255, 255, 255, 0.25)
                }

                Text {
                    id: clockText
                    text: Qt.formatTime(playerView.hudNow, "HH:mm")
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

        // --- Series episode picker popup ---
        Rectangle {
            id: seriesDialog
            visible: seriesDialogVisible
            anchors.fill: parent
            color: "#C0000000"
            z: 220

            function playEpisode(idx) {
                if (idx < 0 || !appViewModel) return
                if (!seriesDialogSeasons.length || !seriesDialogSeasons[seriesDialogSelectedSeason]) return
                var episodes = seriesDialogSeasons[seriesDialogSelectedSeason].episodes
                if (!episodes || idx >= episodes.length) return
                var ep = episodes[idx]
                var seasonNum = seriesDialogSeasons[seriesDialogSelectedSeason].season
                var displayTitle = seriesDialogTitle + " - S" + seasonNum + "E" + (ep.episodeNum || (idx + 1))
                if (ep.title) displayTitle += " - " + ep.title
                appViewModel.playSeriesEpisode(ep.id, ep.ext, displayTitle, ep.logoUrl, seriesDialogChannelId)

                if (idx + 1 < episodes.length) {
                    var nextEp = episodes[idx + 1]
                    var nextNum = nextEp.episodeNum || (idx + 2)
                    var nextTitle = seriesDialogTitle + " - S" + seasonNum + "E" + nextNum
                    if (nextEp.title) nextTitle += " - " + nextEp.title
                    var nextUrl = appViewModel.buildSeriesEpisodeUrl(nextEp.id, nextEp.ext)
                    appViewModel.player.setNextEpisode(nextUrl, nextTitle, nextEp.logoUrl || "", seriesDialogChannelId)
                    if (appViewModel.chromecast.connected)
                        appViewModel.chromecast.setNextEpisode(nextUrl, nextTitle)
                }

                seriesDialog.closeDialog()
            }

            function closeDialog() {
                seriesDialogVisible = false
                seriesDialogChannelId = 0
                if (appViewModel) appViewModel.clearPendingSeriesEpisodes()
                if (appViewModel && appViewModel.currentView === "player" && appViewModel.player.stopped) {
                    appViewModel.currentView = "home"
                }
            }

            function pokeAutoHide() {
                seriesAutoHideTimer.restart()
            }

            Timer {
                id: seriesAutoHideTimer
                interval: 5000
                repeat: false
                onTriggered: seriesDialog.closeDialog()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: seriesDialog.closeDialog()
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back
                        || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    seriesDialog.closeDialog()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                           || event.key === Qt.Key_Left || event.key === Qt.Key_Right
                           || event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    seriesDialog.pokeAutoHide()
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 600)
                height: Math.min(parent.height - 80, 500)
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: seriesDialogTitle
                            font.pixelSize: Theme.fontSizeLg
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: seriesCloseHov ? Theme.surfaceHover : "transparent"
                            property bool seriesCloseHov: false
                            activeFocusOnTab: true
                            border.width: activeFocus ? 2 : 0
                            border.color: Theme.surfaceBorder
                            onActiveFocusChanged: { parent.seriesCloseHov = activeFocus; seriesDialog.pokeAutoHide() }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 16
                                font.bold: true
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: { parent.seriesCloseHov = true; seriesDialog.pokeAutoHide() }
                                onExited: { parent.seriesCloseHov = false; seriesDialog.pokeAutoHide() }
                                onClicked: seriesDialog.closeDialog()
                            }

                            Keys.onReturnPressed: seriesDialog.closeDialog()
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    Keys.onReturnPressed(event)
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Row {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: seriesDialogSeasons

                            Rectangle {
                                width: seasonLabel.implicitWidth + 20
                                height: 32
                                radius: 16
                                color: seriesDialogSelectedSeason === index
                                    ? Theme.accent : seasonTabHov ? Theme.surfaceHover : Theme.surface
                                border.color: seriesDialogSelectedSeason === index
                                    ? Theme.accent : Theme.surfaceBorder
                                border.width: 1
                                focus: false
                                activeFocusOnTab: true
                                property bool seasonTabHov: false

                                Text {
                                    id: seasonLabel
                                    anchors.centerIn: parent
                                    text: "S" + modelData.season
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: seriesDialogSelectedSeason === index
                                    color: seriesDialogSelectedSeason === index
                                        ? Theme.textOnAccent : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: { parent.seasonTabHov = true; seriesDialog.pokeAutoHide() }
                                    onExited: { parent.seasonTabHov = false; seriesDialog.pokeAutoHide() }
                                    onClicked: {
                                        seriesDialogSelectedSeason = index
                                        seriesDialog.pokeAutoHide()
                                    }
                                }

                                Keys.onReturnPressed: {
                                    seriesDialogSelectedSeason = index
                                    seriesDialog.pokeAutoHide()
                                }
                                Keys.onEnterPressed: Keys.onReturnPressed(event)
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                        seriesDialogSelectedSeason = index
                                        event.accepted = true
                                        seriesDialog.pokeAutoHide()
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: seriesEpisodeList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        focus: true
                        keyNavigationEnabled: true
                        highlight: Rectangle { color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.13); radius: Theme.borderRadiusSmall }
                        highlightFollowsCurrentItem: true
                        model: seriesDialogSeasons.length > 0
                            ? seriesDialogSeasons[seriesDialogSelectedSeason].episodes
                            : []
                        onCountChanged: playerView.clampListIndex(seriesEpisodeList)

                        Keys.onReturnPressed: playEpisode(currentIndex)
                        Keys.onEnterPressed: playEpisode(currentIndex)
                        Keys.onEscapePressed: seriesDialog.closeDialog()
                        Keys.onLeftPressed: {
                            if (seriesDialogSelectedSeason > 0) seriesDialogSelectedSeason--
                            seriesDialog.pokeAutoHide()
                        }
                        Keys.onRightPressed: {
                            if (seriesDialogSelectedSeason < seriesDialogSeasons.length - 1) seriesDialogSelectedSeason++
                            seriesDialog.pokeAutoHide()
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: Theme.accent
                                opacity: parent.active ? 0.8 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                            }
                            background: Rectangle {
                                implicitWidth: 6
                                color: "transparent"
                            }
                        }

                        delegate: Rectangle {
                            width: seriesEpisodeList.width
                            height: 44
                            radius: Theme.borderRadiusSmall
                            color: epHov ? Theme.surfaceHover : "transparent"
                            property bool epHov: false

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingMd
                                anchors.rightMargin: Theme.spacingMd
                                spacing: Theme.spacingSm

                                Text {
                                    text: "E" + (modelData.episodeNum || (index + 1))
                                    font.pixelSize: Theme.fontSizeSm
                                    font.bold: true
                                    color: Theme.accent
                                    Layout.preferredWidth: 36
                                }

                                Text {
                                    text: {
                                        var t = modelData.title || ("Episode " + (index + 1))
                                        var series = seriesDialogTitle
                                        if (series && t.indexOf(series) === 0) {
                                            t = t.substring(series.length).replace(/^\s*-\s*/, "")
                                        }
                                        t = t.replace(/^S\d+E\d+\s*-?\s*/i, "")
                                        return t || ("Episode " + (index + 1))
                                    }
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: {
                                        if (!appViewModel) return false
                                        var url = appViewModel.buildSeriesEpisodeUrl(modelData.id, modelData.ext)
                                        return appViewModel.hasWatchedUrl(url)
                                    }
                                    text: "\u2713"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Theme.success
                                }

                                Text {
                                    text: "\u203A"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.epHov = true
                                onExited: parent.epHov = false
                                onClicked: seriesDialog.playEpisode(index)
                            }
                        }
                    }
                }
            }
        }

        // --- Live TV zap popup ---
        Rectangle {
            id: zapDialog
            visible: zapDialogVisible
            focus: visible
            anchors.fill: parent
            color: "#C0000000"
            z: 221

            onVisibleChanged: {
                if (visible && zapList) {
                    var idx = appViewModel ? appViewModel.zapContextIndex : -1
                    zapList.currentIndex = idx >= 0 ? idx : 0
                    playerView.clampListIndex(zapList)
                    zapList.forceActiveFocus()
                    zapList.positionViewAtIndex(zapList.currentIndex, ListView.Contain)
                }
            }

            function playItem(idx) {
                if (!appViewModel || idx < 0) return
                var items = appViewModel.zapContext
                if (!items || idx >= items.length) return
                var item = items[idx]
                if (!item || !item.channelId || !item.streamUrl) return
                if (item.type && item.type !== "live") return
                appViewModel.zapPlayIndex(idx)
                zapDialogVisible = false
            }

            function closeDialog() {
                zapDialogVisible = false
            }

            MouseArea {
                anchors.fill: parent
                onClicked: zapDialog.closeDialog()
            }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back
                        || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    zapDialog.closeDialog()
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 520)
                height: Math.min(parent.height - 80, 560)
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: (appViewModel ? appViewModel.zapContextTitle : "") + "  •  " + (appViewModel ? (appViewModel.zapContextIndex + 1) : 0) + "/" + (appViewModel ? appViewModel.zapContext.length : 0)
                            font.pixelSize: Theme.fontSizeLg
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: zapCloseHov ? Theme.surfaceHover : "transparent"
                            property bool zapCloseHov: false
                            activeFocusOnTab: true
                            border.width: activeFocus ? 2 : 0
                            border.color: Theme.surfaceBorder
                            onActiveFocusChanged: parent.zapCloseHov = activeFocus

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 16
                                font.bold: true
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.zapCloseHov = true
                                onExited: parent.zapCloseHov = false
                                onClicked: zapDialog.closeDialog()
                            }

                            Keys.onReturnPressed: zapDialog.closeDialog()
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    Keys.onReturnPressed(event)
                                    event.accepted = true
                                }
                            }
                        }
                    }

            ListView {
                        id: zapList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        focus: true
                        keyNavigationEnabled: true
                        highlightFollowsCurrentItem: true
                        currentIndex: appViewModel ? appViewModel.zapContextIndex : -1
                        model: appViewModel ? appViewModel.zapContext : []
                        onCountChanged: playerView.clampListIndex(zapList)

                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: 3
                                color: Theme.accent
                                opacity: parent.active ? 0.8 : 0.0
                                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                            }
                            background: Rectangle {
                                implicitWidth: 6
                                color: "transparent"
                            }
                        }

                        Keys.onReturnPressed: zapDialog.playItem(currentIndex)
                        Keys.onEnterPressed: zapDialog.playItem(currentIndex)
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Space || event.key === Qt.Key_Select) {
                                zapDialog.playItem(currentIndex)
                                event.accepted = true
                            }
                        }
                        Keys.onEscapePressed: zapDialog.closeDialog()
                        Keys.onLeftPressed: zapDialog.closeDialog()

                        delegate: Rectangle {
                            width: zapList.width
                            height: 60
                            radius: Theme.borderRadiusSmall
                            color: zapHov ? Theme.surfaceHover : "transparent"
                            property bool zapHov: false

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingMd
                                anchors.rightMargin: Theme.spacingMd
                                spacing: Theme.spacingMd

                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 6
                                    color: Theme.surface
                                    clip: true
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 44

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        source: modelData.logoUrl || ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "▭"
                                        font.pixelSize: 16
                                        visible: !modelData.logoUrl
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: modelData.name || ""
                                        font.pixelSize: Theme.fontSizeSm
                                        font.bold: true
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                }

                                Text {
                                    text: "\u203A"
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: Theme.textSecondary
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.color: (zapList.activeFocus && zapList.currentIndex === index) ? Theme.accent : "transparent"
                                border.width: (zapList.activeFocus && zapList.currentIndex === index) ? 2 : 0
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.zapHov = true
                                onExited: parent.zapHov = false
                                onClicked: zapDialog.playItem(index)
                            }
                        }

                        onCurrentIndexChanged: {
                            if (count <= 0) {
                                currentIndex = -1
                            } else if (currentIndex < 0 || currentIndex >= count) {
                                currentIndex = 0
                            }
                        }
                    }
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

            function closeDialog() {
                visible = false
            }

            function pokeAutoHide() {
                subTrackAutoHideTimer.restart()
            }

            onVisibleChanged: {
                if (visible) {
                    if (appViewModel) appViewModel.player.refreshSubtitleTracks()
                    playerView.clampListIndex(subTrackList)
                    Qt.callLater(function() {
                        if (subTrackList.count > 0 && subTrackList.visible) {
                            subTrackList.forceActiveFocus()
                        } else if (subVisSwitch) {
                            subVisSwitch.forceActiveFocus()
                        }
                    })
                    pokeAutoHide()
                }
            }

            Timer {
                id: subTrackAutoHideTimer
                interval: 5000
                repeat: false
                onTriggered: subTrackPopup.closeDialog()
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

                    ThemeSwitch {
                        id: subVisSwitch
                        checked: true
                        onToggled: {
                            if (appViewModel) appViewModel.player.setSubtitleVisibility(checked)
                        }
                        Keys.onDownPressed: {
                            if (subTrackList.count > 0) {
                                subTrackList.forceActiveFocus()
                            } else {
                                subDelayMinusBtn.forceActiveFocus()
                            }
                            subTrackPopup.pokeAutoHide()
                        }
                        Keys.onUpPressed: subTrackPopup.closeDialog()
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
                        onCountChanged: playerView.clampListIndex(subTrackList)
                        Keys.onUpPressed: subVisSwitch.forceActiveFocus()
                        Keys.onDownPressed: subDelayMinusBtn.forceActiveFocus()
                        Keys.onReturnPressed: if (currentIndex >= 0 && currentItem) { appViewModel.player.selectSubtitleTrack(model[currentIndex].id); subTrackPopup.closeDialog() }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                        Keys.onEscapePressed: subTrackPopup.closeDialog()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) { Keys.onReturnPressed(event); event.accepted = true }
                            else if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Delete) { subTrackPopup.closeDialog(); event.accepted = true }
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) { subTrackPopup.pokeAutoHide() }
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
                                var labeled = {}
                                for (var k in item) labeled[k] = item[k]
                                if (item.external) {
                                    var key = lang.toLowerCase()
                                    externalCounts[key] = (externalCounts[key] || 0) + 1
                                    labeled.displayLabel = lang + " - Ext #" + externalCounts[key]
                                } else {
                                    labeled.displayLabel = lang + " - Builtin"
                                }
                                return labeled
                            }

                            for (var i = 0; i < tracks.length; i++) {
                                var t = tracks[i]
                                t = labelTrack(t)
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
                                onEntered: { parent.stHov = true; subTrackPopup.pokeAutoHide() }
                                onExited: { parent.stHov = false; subTrackPopup.pokeAutoHide() }
                                onClicked: {
                                    if (appViewModel) appViewModel.player.selectSubtitleTrack(modelData.id)
                                    subTrackPopup.closeDialog()
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
                        id: subDelayMinusBtn
                        text: "-"
                        btnSize: 28
                        iconSize: 16
                        onActiveFocusChanged: if (activeFocus) subTrackPopup.pokeAutoHide()
                        onClicked: {
                            subDelaySlider.value -= 0.5
                            if (appViewModel) appViewModel.player.setSubtitleDelay(subDelaySlider.value)
                        }
                        Keys.onUpPressed: {
                            if (subTrackList.count > 0) {
                                subTrackList.forceActiveFocus()
                            } else {
                                subVisSwitch.forceActiveFocus()
                            }
                        }
                        Keys.onRightPressed: subDelaySlider.forceActiveFocus()
                    }

                    Slider {
                        id: subDelaySlider
                        Layout.fillWidth: true
                        from: -10
                        to: 10
                        value: 0
                        stepSize: 0.1
                        activeFocusOnTab: true
                        focus: false
                        focusPolicy: Qt.StrongFocus
                        onActiveFocusChanged: if (activeFocus) subTrackPopup.pokeAutoHide()

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

                        Keys.onLeftPressed: {
                            value = Math.max(from, value - stepSize)
                            if (appViewModel) appViewModel.player.setSubtitleDelay(value)
                        }
                        Keys.onRightPressed: {
                            value = Math.min(to, value + stepSize)
                            if (appViewModel) appViewModel.player.setSubtitleDelay(value)
                        }
                        Keys.onUpPressed: {
                            if (subTrackList.count > 0) {
                                subTrackList.forceActiveFocus()
                            } else {
                                subVisSwitch.forceActiveFocus()
                            }
                        }
                        Keys.onDownPressed: subDelayPlusBtn.forceActiveFocus()
                    }

                    PlayerButton {
                        id: subDelayPlusBtn
                        text: "+"
                        btnSize: 28
                        iconSize: 16
                        onActiveFocusChanged: if (activeFocus) subTrackPopup.pokeAutoHide()
                        onClicked: {
                            subDelaySlider.value += 0.5
                            if (appViewModel) appViewModel.player.setSubtitleDelay(subDelaySlider.value)
                        }
                        Keys.onUpPressed: {
                            if (subTrackList.count > 0) {
                                subTrackList.forceActiveFocus()
                            } else {
                                subVisSwitch.forceActiveFocus()
                            }
                        }
                        Keys.onLeftPressed: subDelaySlider.forceActiveFocus()
                        Keys.onRightPressed: subDelayResetBtn.forceActiveFocus()
                    }
                }

                PlayerButton {
                    id: subDelayResetBtn
                    text: "Reset"
                    btnSize: 28
                    iconSize: 11
                    onActiveFocusChanged: if (activeFocus) subTrackPopup.pokeAutoHide()
                    onClicked: {
                        subDelaySlider.value = 0
                        if (appViewModel) appViewModel.player.setSubtitleDelay(0)
                    }
                    Keys.onUpPressed: subDelayPlusBtn.forceActiveFocus()
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
                    pokeAutoHide()
                }
            }
            border.color: "#40ffffff"
            border.width: 1
            z: 50
            Component.onCompleted: playerView.audioTrackPopupRef = audioTrackPopup

            function closeDialog() {
                visible = false
            }

            function pokeAutoHide() {
                audioTrackAutoHideTimer.restart()
            }

            Timer {
                id: audioTrackAutoHideTimer
                interval: 5000
                repeat: false
                onTriggered: audioTrackPopup.closeDialog()
            }

            Keys.onEscapePressed: audioTrackPopup.closeDialog()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    audioTrackPopup.closeDialog()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    audioTrackPopup.pokeAutoHide()
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
                                onEntered: { parent.atHov = true; playerView.audioTrackPopupRef.pokeAutoHide() }
                                onExited: { parent.atHov = false; playerView.audioTrackPopupRef.pokeAutoHide() }
                                onClicked: {
                                    if (appViewModel) appViewModel.player.selectAudioTrack(modelData.id)
                                    playerView.audioTrackPopupRef.closeDialog()
                                }
                            }

                            onActiveFocusChanged: { atHov = activeFocus; playerView.audioTrackPopupRef.pokeAutoHide() }

                            Keys.onReturnPressed: {
                                if (appViewModel) appViewModel.player.selectAudioTrack(modelData.id)
                                playerView.audioTrackPopupRef.closeDialog()
                            }
                            Keys.onEnterPressed: Keys.onReturnPressed(event)
                            Keys.onUpPressed: playerView.audioTrackPopupRef.focusAudioTrackAt(index - 1)
                            Keys.onDownPressed: playerView.audioTrackPopupRef.focusAudioTrackAt(index + 1)
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                                    Keys.onReturnPressed(event)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                    playerView.audioTrackPopupRef.pokeAutoHide()
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

            function closeDialog() {
                visible = false
            }

            function pokeAutoHide() {
                castDeviceAutoHideTimer.restart()
            }

            Timer {
                id: castDeviceAutoHideTimer
                interval: 5000
                repeat: false
                onTriggered: castDevicePopup.closeDialog()
            }

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(function() {
                        if (castDeviceRepeater.count > 0) {
                            castDeviceFocusIndex = 0
                                var item = castDeviceRepeater.itemAt(0)
                                if (item) item.forceActiveFocus()
                            }
                        })
                    pokeAutoHide()
                }
            }

            Keys.onEscapePressed: castDevicePopup.closeDialog()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    castDevicePopup.closeDialog()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                           || event.key === Qt.Key_Left || event.key === Qt.Key_Right
                           || event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    castDevicePopup.pokeAutoHide()
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
                            onEntered: { parent.castDevHov = true; castDevicePopup.pokeAutoHide() }
                            onExited: { parent.castDevHov = false; castDevicePopup.pokeAutoHide() }
                            onClicked: {
                                if (appViewModel) {
                                    // Capture URL before stopping player
                                    playerView.pendingCastUrl = appViewModel.player.currentUrl()
                                    playerView.pendingCastName = appViewModel.player.channelName
                                    playerView.pendingCastCt = appViewModel.player.isLive ? "video/mp2t" : "video/mp4"
                                    appViewModel.chromecast.connectToDevice(index)
                                    castDevicePopup.closeDialog()
                                    castConnectTimer.start()
                                }
                            }
                        }

                        onActiveFocusChanged: { parent.castDevHov = activeFocus; castDevicePopup.pokeAutoHide() }

                        Keys.onReturnPressed: {
                            if (appViewModel) {
                                playerView.pendingCastUrl = appViewModel.player.currentUrl()
                                playerView.pendingCastName = appViewModel.player.channelName
                                playerView.pendingCastCt = appViewModel.player.isLive ? "video/mp2t" : "video/mp4"
                                appViewModel.chromecast.connectToDevice(index)
                                castDevicePopup.closeDialog()
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
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                                       || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                castDevicePopup.pokeAutoHide()
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
            function closeDialog() {
                visible = false
            }

            function pokeAutoHide() {
                castStopAutoHideTimer.restart()
            }

            Timer {
                id: castStopAutoHideTimer
                interval: 5000
                repeat: false
                onTriggered: castStopPopup.closeDialog()
            }

            Keys.onEscapePressed: castStopPopup.closeDialog()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Back || event.key === Qt.Key_B || event.key === Qt.Key_Delete) {
                    castStopPopup.closeDialog()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                           || event.key === Qt.Key_Left || event.key === Qt.Key_Right
                           || event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                    castStopPopup.pokeAutoHide()
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
                    activeFocusOnTab: true
                    border.width: activeFocus ? 2 : 0
                    border.color: Theme.error
                    onActiveFocusChanged: {
                        parent.castStopBtnHov = activeFocus
                        castStopPopup.pokeAutoHide()
                    }

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
                        onEntered: { parent.castStopBtnHov = true; castStopPopup.pokeAutoHide() }
                        onExited: { parent.castStopBtnHov = false; castStopPopup.pokeAutoHide() }
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.chromecast.stopMedia()
                                appViewModel.chromecast.disconnect()
                                castStopPopup.closeDialog()
                            }
                        }
                    }

                    Keys.onReturnPressed: {
                        if (appViewModel) {
                            appViewModel.chromecast.stopMedia()
                            appViewModel.chromecast.disconnect()
                            castStopPopup.closeDialog()
                        }
                    }
                    Keys.onEnterPressed: Keys.onReturnPressed(event)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Select || event.key === Qt.Key_Space) {
                            Keys.onReturnPressed(event)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down
                                   || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                            castStopPopup.pokeAutoHide()
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
        FallbackLogo {
            id: logoPlaceholder
            property bool isLoading: appViewModel ? (appViewModel.player.position <= 0 && (!appViewModel.player.stopped || appViewModel.player.reconnecting)) : false
            visible: (appViewModel ? appViewModel.player.stopped : true) || isLoading
            logoSize: 96
            logoOpacity: 0.26
            logoAreaHeight: 160
            liveTvGeometry: true

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
                    activeFocusOnTab: true
                    border.width: activeFocus ? 2 : 0
                    border.color: Theme.accent
                    onActiveFocusChanged: if (activeFocus) showControls()

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

                    Keys.onReturnPressed: {
                        if (appViewModel) appViewModel.player.cancelAutoNext()
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
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: playerView.hudNow = new Date()
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
        interval: appViewModel ? appViewModel.hudVisibilitySeconds * 1000 : 5000
        running: appViewModel ? (!appViewModel.player.stopped) : false
        onTriggered: {
            // Hide unconditionally after the interval. Any real user input
            // (key press, mouse movement past the deadzone, focus change)
            // calls showControls() which restarts the timer — that's the
            // correct path. Keeping controls visible just because a button
            // happens to have focus made the HUD stick forever during
            // playback.
            controlsVisible = false
        }
    }

    Connections {
        target: appViewModel
        function onHudVisibilitySecondsChanged() {
            if (controlsVisible) controlsTimer.restart()
        }
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

        if (appViewModel && appViewModel.hasPendingSeriesEpisodes()) {
            showSeriesDialog(appViewModel.pendingSeriesName(), appViewModel.pendingSeriesEpisodes())
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
        function onChannelIdChanged() {
            topOverlay.refreshEpg()
        }
        function onChannelNameChanged() {
            topOverlay.refreshEpg()
        }
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

    Connections {
        target: appViewModel
        function onHudVisibilitySecondsChanged() {
            if (controlsVisible) {
                controlsTimer.restart()
            }
        }
    }

    Connections {
        target: appViewModel && appViewModel.player ? appViewModel.player.mpvPlayer : null
        function onMediaLoaded() {
            if (!appViewModel || appViewModel.player.isLive) return
            appViewModel.player.refreshSubtitleTracks()
            appViewModel.player.refreshAudioTracks()
            if (appViewModel.subtitlesEnabled) {
                var name = appViewModel.player.channelName
                if (name) appViewModel.searchSubtitles(name)
            }
            if (subSearchTimer.running) {
                subSearchTimer.restart()
            } else {
                subSearchTimer.start()
            }
        }
    }

    Connections {
        target: appViewModel
        function onSeriesEpisodesReady(seriesName, seasons) {
            showSeriesDialog(seriesName, seasons)
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
        }
        if (appViewModel) {
            appViewModel.player.stop()
            appViewModel.currentView = "home"
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
            focusTopBackButton()
        } else if (appViewModel) {
            focusControlsEntry()
        }
    }
    Keys.onDownPressed: {
        if (focusedControlIndex() < 0) {
            focusControlsEntry()
        } else if (seekSlider && seekSlider.visible && !seekSlider.activeFocus) {
            focusSeekSlider()
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
        onActiveFocusChanged: if (activeFocus) showControls()

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
        Keys.onLeftPressed: function(event) { stepControlFocus(-1); event.accepted = true }
        Keys.onRightPressed: function(event) { stepControlFocus(1); event.accepted = true }
        Keys.onUpPressed: function(event) { focusSeekSlider(); event.accepted = true }
        Keys.onDownPressed: function(event) { focusSeekSlider(); event.accepted = true }
    }

    // ----- Catchup / rewind popup ------------------------------------------------
    Rectangle {
        id: catchupPopup
        visible: catchupDialogVisible
        anchors.fill: parent
        color: "#C0000000"
        z: 350

        property var rewindOptions: {
            // Filter rewind options to those within the channel's archive window.
            // First entry is "Live (now)" when currently in catchup mode, so the
            // user has a one-tap escape back to the live edge.
            var allOpts = [
                { label: "5 minutes",  mins: 5 },
                { label: "15 minutes", mins: 15 },
                { label: "30 minutes", mins: 30 },
                { label: "1 hour",     mins: 60 },
                { label: "2 hours",    mins: 120 },
                { label: "4 hours",    mins: 240 },
                { label: "12 hours",   mins: 720 },
                { label: "1 day",      mins: 1440 },
                { label: "2 days",     mins: 2880 },
                { label: "3 days",     mins: 4320 },
                { label: "5 days",     mins: 7200 },
                { label: "7 days",     mins: 10080 }
            ]
            var maxMins = playerView.currentChannelArchiveDays * 1440
            if (maxMins <= 0) return []
            var result = []
            if (appViewModel && appViewModel.player.isCatchup) {
                result.push({ label: "Live (now)", mins: 0, isLive: true })
            }
            for (var i = 0; i < allOpts.length; i++) {
                if (allOpts[i].mins <= maxMins) result.push(allOpts[i])
            }
            return result
        }

        MouseArea {
            anchors.fill: parent
            onClicked: catchupDialogVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(360, parent.width - 80)
            height: catchupCol.implicitHeight + Theme.spacingLg * 2
            radius: Theme.borderRadiusLarge
            color: Theme.surfaceElevated
            border.color: Theme.surfaceBorder
            border.width: 1

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: catchupCol
                anchors.fill: parent
                anchors.margins: Theme.spacingLg
                spacing: Theme.spacingSm

                Text {
                    text: "Rewind to..."
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                Text {
                    text: playerView.currentChannelArchiveDays + " day" +
                        (playerView.currentChannelArchiveDays === 1 ? "" : "s") +
                        " of catchup available"
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textMuted
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.surfaceBorder
                }

                ListView {
                    id: catchupList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(360, contentHeight)
                    model: catchupPopup.rewindOptions
                    spacing: 4
                    clip: true
                    focus: catchupDialogVisible
                    keyNavigationWraps: true

                    Keys.onReturnPressed: if (currentIndex >= 0) activateAt(currentIndex)
                    Keys.onEnterPressed: if (currentIndex >= 0) activateAt(currentIndex)
                    Keys.onEscapePressed: catchupDialogVisible = false

                    function activateAt(idx) {
                        if (!appViewModel || !appViewModel.player.channelId) return
                        var opt = catchupPopup.rewindOptions[idx]
                        if (!opt) return
                        catchupDialogVisible = false
                        if (opt.isLive) {
                            appViewModel.playChannelById(appViewModel.player.channelId)
                            return
                        }
                        var nowSecs = Math.floor(Date.now() / 1000)
                        var startSecs = nowSecs - opt.mins * 60
                        // Stream forward for the rewind amount + 2h cushion so the user
                        // can keep watching past the requested point.
                        var durationMins = opt.mins + 120
                        appViewModel.playCatchup(appViewModel.player.channelId, startSecs, durationMins)
                    }

                    delegate: Rectangle {
                        width: catchupList.width
                        height: 36
                        radius: Theme.borderRadiusSmall
                        color: catchupList.activeFocus && catchupList.currentIndex === index
                            ? Theme.surfaceHover
                            : (rewindHovered ? Theme.surfaceHover : "transparent")
                        property bool rewindHovered: false

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingMd
                            anchors.verticalCenter: parent.verticalCenter
                            // ▷ (U+25B7 WHITE) instead of ▶ (U+25B6 BLACK) so the
                            // glyph stays monochrome — the BLACK variant renders as
                            // a colored emoji via the OS font fallback chain.
                            text: (modelData.isLive ? "▷  " : "↻  ") + modelData.label
                            font.pixelSize: Theme.fontSizeSm
                            font.family: "DejaVu Sans"
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.rewindHovered = true
                            onExited: parent.rewindHovered = false
                            onClicked: catchupList.activateAt(index)
                        }
                    }
                }
            }
        }
    }
}
