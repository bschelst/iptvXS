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
                    from: 0
                    to: appViewModel ? Math.max(appViewModel.player.duration, 1) : 1
                    value: appViewModel ? appViewModel.player.position : 0
                    enabled: appViewModel ? appViewModel.player.duration > 0 : false

                    onMoved: {
                        if (appViewModel) appViewModel.player.seek(value)
                    }

                    background: Rectangle {
                        x: seekSlider.leftPadding
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - 2
                        width: seekSlider.availableWidth
                        height: 4
                        radius: 2
                        color: "#40ffffff"

                        Rectangle {
                            width: seekSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: Theme.accent
                        }
                    }

                    handle: Rectangle {
                        x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: seekSlider.pressed ? Theme.accentHover : Theme.accent
                        visible: seekSlider.hovered || seekSlider.pressed
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSm

                    PlayerButton {
                        text: appViewModel && appViewModel.player.paused ? "▶" : "⏸"
                        btnSize: 48
                        iconSize: 22
                        onClicked: {
                            if (appViewModel) appViewModel.player.togglePause()
                        }
                    }

                    PlayerButton {
                        text: "⏹"
                        btnSize: 48
                        iconSize: 22
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

                    // --- Favorite button (live channels only) ---
                    PlayerButton {
                        id: favBtn
                        text: isFav ? "⭐" : "☆"
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
                        text: recActive ? "⏹" : "⏺"
                        btnColor: recActive ? Theme.error : "transparent"
                        visible: appViewModel ? appViewModel.player.isLive : false
                        property bool recActive: false
                        property string recPath: ""
                        property var recStartTime: 0
                        onClicked: {
                            if (!appViewModel) return
                            showControls()
                            if (recActive) {
                                appViewModel.player.stopStreamRecord()
                                if (appViewModel.player.channelId > 0) {
                                    var endTime = Math.floor(Date.now() / 1000)
                                    appViewModel.recordingList.addCompletedRecording(
                                        appViewModel.player.channelId, recStartTime, endTime, recPath)
                                }
                                recActive = false
                            } else {
                                var now = new Date()
                                recStartTime = Math.floor(now.getTime() / 1000)
                                var ts = now.getFullYear() + "-" +
                                    String(now.getMonth()+1).padStart(2,'0') + "-" +
                                    String(now.getDate()).padStart(2,'0') + "_" +
                                    String(now.getHours()).padStart(2,'0') +
                                    String(now.getMinutes()).padStart(2,'0') +
                                    String(now.getSeconds()).padStart(2,'0')
                                var name = (appViewModel.player.channelName || "recording").replace(/[^a-zA-Z0-9_-]/g, "_")
                                var dir = appViewModel.recordingDirectory
                                recPath = dir + "/" + ts + "_" + name + ".mkv"
                                appViewModel.player.startStreamRecord(recPath)
                                recActive = true
                            }
                        }
                        Connections {
                            target: appViewModel ? appViewModel.player : null
                            function onChannelIdChanged() {
                                if (recBtn.recActive) {
                                    appViewModel.player.stopStreamRecord()
                                }
                                recBtn.recActive = false
                            }
                        }
                    }

                    Rectangle {
                        width: 1; height: 28; color: "#40ffffff"
                        visible: ccBtn.visible
                    }

                    PlayerButton {
                        id: ccBtn
                        visible: appViewModel && !appViewModel.player.isLive && appViewModel.subtitlesEnabled
                        text: "CC"
                        iconSize: 14
                        onClicked: subTrackPopup.visible = !subTrackPopup.visible
                    }

                    Rectangle {
                        width: 1; height: 28; color: "#40ffffff"
                        visible: ccBtn.visible || audioBtn.visible
                    }

                    PlayerButton {
                        id: audioBtn
                        visible: appViewModel && appViewModel.player.audioTracks.length > 1
                        text: "AUD"
                        iconSize: 12
                        onClicked: audioTrackPopup.visible = !audioTrackPopup.visible
                    }

                    Rectangle {
                        width: 1; height: 28; color: "#40ffffff"
                        visible: audioBtn.visible
                    }

                    Rectangle {
                        width: 44
                        height: 44
                        radius: Theme.borderRadius
                        color: {
                            if (appViewModel && appViewModel.player.muted) return Theme.error + "60"
                            return muteHov ? "#40ffffff" : "transparent"
                        }
                        property bool muteHov: false

                        Text {
                            anchors.centerIn: parent
                            text: appViewModel && appViewModel.player.muted ? "MUTED" : "🔊"
                            font.pixelSize: appViewModel && appViewModel.player.muted ? 10 : 18
                            font.bold: true
                            color: appViewModel && appViewModel.player.muted ? "#ffffff" : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.muteHov = true
                            onExited: parent.muteHov = false
                            onClicked: {
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
                        value: appViewModel ? appViewModel.player.volume : 100

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
                        text: videoFullscreen ? "⊡" : "⛶"
                        onClicked: toggleVideoFullscreen()
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
            visible: controlsOverlay.visible
            opacity: controlsOverlay.opacity

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#cc000000" }
                GradientStop { position: 0.6; color: "#80000000" }
                GradientStop { position: 1.0; color: "transparent" }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd

                PlayerButton {
                    text: "←"
                    onClicked: goBack()
                }

                Text {
                    text: appViewModel ? appViewModel.player.channelName : ""
                    font.pixelSize: Theme.fontSizeMd
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
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

                Text {
                    id: clockText
                    text: Qt.formatTime(new Date(), "HH:mm")
                    font.pixelSize: Theme.fontSizeMd
                    color: "#ccffffff"
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
                if (visible && appViewModel) {
                    appViewModel.player.refreshSubtitleTracks()
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
                        model: {
                            if (!appViewModel) return []
                            var tracks = appViewModel.player.subtitleTracks
                            var primary = appViewModel.subtitleLanguage || ""
                            var secondary = appViewModel.subtitleLanguageSecondary || ""
                            if (!primary && !secondary) return tracks
                            var filtered = []
                            for (var i = 0; i < tracks.length; i++) {
                                var t = tracks[i]
                                if (t.selected || t.external
                                    || playerView.langMatches(t.lang, primary)
                                    || playerView.langMatches(t.lang, secondary)
                                    || !t.lang)
                                    filtered.push(t)
                            }
                            return filtered.length > 0 ? filtered : tracks
                        }
                        spacing: 2

                        delegate: Rectangle {
                            width: subTrackList.width
                            height: 36
                            radius: 6
                            color: modelData.selected ? Theme.accent + "50" : stHov ? Theme.accent + "25" : "#15ffffff"
                            border.width: modelData.selected ? 1 : 0
                            border.color: Theme.accent
                            property bool stHov: false

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: modelData.selected ? "●" : "○"
                                    font.pixelSize: 12
                                    color: modelData.selected ? Theme.accent : stHov ? "#bbffffff" : "#60ffffff"
                                }

                                Text {
                                    text: {
                                        var lang = playerView.langName(modelData.lang)
                                        var title = modelData.title || ""
                                        if (modelData.external) title = title ? title + " (ext)" : "(external)"
                                        if (lang && title) return lang + " — " + title
                                        if (lang) return lang
                                        if (title) return title
                                        return "Track " + modelData.id
                                    }
                                    font.pixelSize: Theme.fontSizeXs
                                    font.bold: modelData.selected
                                    color: modelData.selected ? "#ffffff" : stHov ? "#eeffffff" : "#ccffffff"
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
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 80
            anchors.rightMargin: Theme.spacingMd
            width: 280
            height: Math.min(audioTrackCol.implicitHeight + Theme.spacingMd * 2, 350)
            radius: Theme.borderRadiusLarge
            color: "#e0202020"

            onVisibleChanged: {
                if (visible && appViewModel)
                    appViewModel.player.refreshAudioTracks()
            }
            border.color: "#40ffffff"
            border.width: 1
            z: 50

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
                        model: appViewModel ? appViewModel.player.audioTracks : []

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 4
                            color: modelData.selected ? Theme.accent + "50" : atHov ? Theme.accent + "25" : "#15ffffff"
                            border.width: modelData.selected ? 1 : 0
                            border.color: Theme.accent
                            property bool atHov: false

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    text: modelData.selected ? "●" : "○"
                                    font.pixelSize: 12
                                    color: modelData.selected ? Theme.accent : atHov ? "#bbffffff" : "#60ffffff"
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
                                    color: modelData.selected ? "#ffffff" : atHov ? "#eeffffff" : "#ccffffff"
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
                        }
                    }
                }
            }
        }

        // --- Stopped placeholder ---
        Text {
            anchors.centerIn: parent
            visible: appViewModel ? appViewModel.player.stopped : true
            text: "Select a channel to start playing"
            font.pixelSize: Theme.fontSizeLg
            color: Theme.textMuted
        }

        // --- Loading spinner (hidden once position starts updating) ---
        BusyIndicator {
            anchors.centerIn: parent
            visible: appViewModel ? (appViewModel.player.position <= 0 && !appViewModel.player.stopped) : false
            running: visible
            width: 48
            height: 48
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
            appViewModel.currentView = appViewModel.previousView()
        }
    }

    Keys.onSpacePressed: { if (appViewModel) appViewModel.player.togglePause(); showControls() }
    Keys.onLeftPressed: { if (appViewModel) appViewModel.player.seek(Math.max(0, appViewModel.player.position - 10)); showControls() }
    Keys.onRightPressed: { if (appViewModel) appViewModel.player.seek(appViewModel.player.position + 10); showControls() }
    Keys.onUpPressed: { if (appViewModel) appViewModel.player.volumeUp(); showControls() }
    Keys.onDownPressed: { if (appViewModel) appViewModel.player.volumeDown(); showControls() }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_M) {
            if (appViewModel) appViewModel.player.toggleMute()
            showControls()
        } else if (event.key === Qt.Key_F) {
            toggleVideoFullscreen()
        } else if (event.key === Qt.Key_Escape && videoFullscreen) {
            toggleVideoFullscreen()
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
            onClicked: playerBtn.clicked()
        }
    }
}
