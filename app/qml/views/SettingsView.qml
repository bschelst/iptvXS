// iptvXS Project - Schelstraete Bart - https://iptvxs.schelstraete.org
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import app.iptvxs

Item {
    id: settingsView

    property var langOptions: [
        { value: "en", label: "English" },
        { value: "nl", label: "Dutch" },
        { value: "fr", label: "French" },
        { value: "de", label: "German" },
        { value: "es", label: "Spanish" },
        { value: "pt", label: "Portuguese" },
        { value: "it", label: "Italian" },
        { value: "pl", label: "Polish" },
        { value: "ru", label: "Russian" },
        { value: "ar", label: "Arabic" },
        { value: "tr", label: "Turkish" },
        { value: "sv", label: "Swedish" },
        { value: "da", label: "Danish" },
        { value: "no", label: "Norwegian" },
        { value: "fi", label: "Finnish" },
        { value: "cs", label: "Czech" },
        { value: "hu", label: "Hungarian" },
        { value: "ro", label: "Romanian" },
        { value: "el", label: "Greek" },
        { value: "he", label: "Hebrew" },
        { value: "hi", label: "Hindi" },
        { value: "zh", label: "Chinese" },
        { value: "ja", label: "Japanese" },
        { value: "ko", label: "Korean" }
    ]

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width - Theme.spacingXl * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Theme.spacingXl

            Item { Layout.preferredHeight: Theme.spacingLg }

            Text {
                text: "Settings"
                font.pixelSize: Theme.fontSizeXl
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.preferredHeight: Theme.spacingSm }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: themeCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: themeCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Theme"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Repeater {
                            model: Theme.themeNames

                            Rectangle {
                                width: 120
                                height: 72
                                radius: Theme.borderRadius
                                color: Theme.themes[modelData].background
                                border.color: Theme.currentTheme === modelData
                                    ? Theme.accent : themeCardHovered ? Theme.surfaceBorder : "transparent"
                                border.width: 2

                                property bool themeCardHovered: false

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingSm
                                    spacing: 4

                                    Text {
                                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                        font.pixelSize: Theme.fontSizeXs
                                        font.bold: Theme.currentTheme === modelData
                                        color: Theme.themes[modelData].textPrimary
                                    }

                                    Row {
                                        spacing: 4
                                        Repeater {
                                            model: [
                                                Theme.themes[modelData].accent,
                                                Theme.themes[modelData].success,
                                                Theme.themes[modelData].warning,
                                                Theme.themes[modelData].error
                                            ]

                                            Rectangle {
                                                width: 14
                                                height: 14
                                                radius: 7
                                                color: modelData
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 8
                                        radius: 4
                                        color: Theme.themes[modelData].surface

                                        Rectangle {
                                            width: parent.width * 0.6
                                            height: parent.height
                                            radius: 4
                                            color: Theme.themes[modelData].accent
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.themeCardHovered = true
                                    onExited: parent.themeCardHovered = false
                                    onClicked: {
                                        Theme.applyTheme(modelData)
                                        if (appViewModel) appViewModel.theme = modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: generalCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: generalCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "General"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXs

                            Text {
                                text: "Start minimized to tray"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "Launch the application minimized in the system tray"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }

                        Switch {
                            checked: false
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: playerCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: playerCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Player"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Buffer time"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Amount of stream data to buffer before playback"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: 0, label: "Default" },
                                    { value: 5, label: "5s" },
                                    { value: 10, label: "10s" },
                                    { value: 15, label: "15s" }
                                ]

                                Rectangle {
                                    width: 64
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.bufferSeconds === modelData.value
                                        ? Theme.accent : bufHovered
                                            ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder

                                    property bool bufHovered: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.bufferSeconds === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.bufHovered = true
                                        onExited: parent.bufHovered = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.bufferSeconds = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Hardware decoding"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "GPU-accelerated video decoding for lower CPU usage"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: "auto-safe", label: "Auto Safe" },
                                    { value: "auto", label: "Auto" },
                                    { value: "no", label: "Software" }
                                ]

                                Rectangle {
                                    width: 80
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.hwdecMode === modelData.value
                                        ? Theme.accent : hwdecHov
                                            ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder

                                    property bool hwdecHov: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.hwdecMode === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.hwdecHov = true
                                        onExited: parent.hwdecHov = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.hwdecMode = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Grid Detail Columns"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Number of columns in TV Channels and VOD grids"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: 1, label: "1 column" },
                                    { value: 2, label: "2 columns" },
                                    { value: 3, label: "3 columns" }
                                ]

                                Rectangle {
                                    width: 80
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.gridColumns === modelData.value
                                        ? Theme.accent : colHovered
                                            ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder

                                    property bool colHovered: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.gridColumns === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.colHovered = true
                                        onExited: parent.colHovered = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.gridColumns = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: appBehaviorCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: appBehaviorCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Application"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Minimize to tray on close"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "Keep app running in background when closing the window"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }

                        Switch {
                            checked: appViewModel ? appViewModel.closeToTray : false
                            onToggled: {
                                if (appViewModel) appViewModel.closeToTray = checked
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Video enhancement"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Improve video quality with debanding, scaling, and denoising (uses more GPU)"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: "off", label: "Off" },
                                    { value: "light", label: "Light" },
                                    { value: "medium", label: "Medium" },
                                    { value: "strong", label: "Strong" }
                                ]

                                Rectangle {
                                    width: 80
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.videoEnhancement === modelData.value
                                        ? Theme.accent : veHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder
                                    property bool veHov: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.videoEnhancement === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.veHov = true
                                        onExited: parent.veHov = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.videoEnhancement = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXs

                            Text {
                                text: "Deinterlace"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "Enable deinterlacing for interlaced video streams"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }

                        Switch {
                            checked: appViewModel ? appViewModel.deinterlace : false
                            onToggled: {
                                if (appViewModel) appViewModel.deinterlace = checked
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: subCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: subCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Subtitles"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXs

                            Text {
                                text: "Enable subtitles"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "Automatically search and load subtitles for VOD content"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }

                        Switch {
                            checked: appViewModel ? appViewModel.subtitlesEnabled : false
                            onToggled: {
                                if (appViewModel) appViewModel.subtitlesEnabled = checked
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Primary subtitle language"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Repeater {
                                model: settingsView.langOptions

                                Rectangle {
                                    width: subLangLabel.implicitWidth + Theme.spacingMd * 2
                                    height: 28
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.subtitleLanguage === modelData.value
                                        ? Theme.accent : subLangHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder
                                    property bool subLangHov: false

                                    Text {
                                        id: subLangLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 11
                                        color: appViewModel && appViewModel.subtitleLanguage === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.subLangHov = true
                                        onExited: parent.subLangHov = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.subtitleLanguage = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Secondary subtitle language"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Shown as fallback when primary is not available"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Rectangle {
                                width: noneLbl.implicitWidth + Theme.spacingMd * 2
                                height: 28
                                radius: Theme.borderRadiusSmall
                                color: appViewModel && !appViewModel.subtitleLanguageSecondary
                                    ? Theme.accent : noneHov ? Theme.surfaceHover : Theme.surface
                                border.width: 1; border.color: Theme.surfaceBorder
                                property bool noneHov: false

                                Text { id: noneLbl; anchors.centerIn: parent; text: "None"; font.pixelSize: 11; color: appViewModel && !appViewModel.subtitleLanguageSecondary ? Theme.textOnAccent : Theme.textSecondary }
                                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.noneHov = true; onExited: parent.noneHov = false; onClicked: { if (appViewModel) appViewModel.subtitleLanguageSecondary = "" } }
                            }

                            Repeater {
                                model: settingsView.langOptions

                                Rectangle {
                                    width: secLangLabel.implicitWidth + Theme.spacingMd * 2
                                    height: 28
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.subtitleLanguageSecondary === modelData.value
                                        ? Theme.accent : secLangHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1; border.color: Theme.surfaceBorder
                                    property bool secLangHov: false

                                    Text { id: secLangLabel; anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11; color: appViewModel && appViewModel.subtitleLanguageSecondary === modelData.value ? Theme.textOnAccent : Theme.textSecondary }
                                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: parent.secLangHov = true; onExited: parent.secLangHov = false; onClicked: { if (appViewModel) appViewModel.subtitleLanguageSecondary = modelData.value } }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.surfaceBorder
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Subtitle size"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        RowLayout {
                            spacing: Theme.spacingSm

                            Slider {
                                id: subSizeSlider
                                Layout.fillWidth: true
                                from: 20
                                to: 80
                                stepSize: 2
                                value: appViewModel ? appViewModel.subtitleSize : 48

                                onMoved: {
                                    if (appViewModel) appViewModel.subtitleSize = value
                                }
                            }

                            Text {
                                text: Math.round(subSizeSlider.value) + "px"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                Layout.preferredWidth: 40
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Text color"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Repeater {
                                model: [
                                    { value: "#FFFFFF", label: "White" },
                                    { value: "#FFFF00", label: "Yellow" },
                                    { value: "#00FF00", label: "Green" },
                                    { value: "#00FFFF", label: "Cyan" }
                                ]

                                Rectangle {
                                    width: 60; height: 28; radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.subtitleColor === modelData.value
                                        ? Theme.accent : subColHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1; border.color: Theme.surfaceBorder
                                    property bool subColHov: false

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Rectangle {
                                            width: 10; height: 10; radius: 5; color: modelData.value
                                            border.width: 1; border.color: Theme.surfaceBorder
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.label; font.pixelSize: 9
                                            color: appViewModel && appViewModel.subtitleColor === modelData.value ? Theme.textOnAccent : Theme.textPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.subColHov = true; onExited: parent.subColHov = false
                                        onClicked: { if (appViewModel) appViewModel.subtitleColor = modelData.value }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Background"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Repeater {
                                model: [
                                    { value: "#00000000", label: "None" },
                                    { value: "#80000000", label: "Dark" },
                                    { value: "#CC000000", label: "Darker" },
                                    { value: "#FF000000", label: "Black" }
                                ]

                                Rectangle {
                                    width: 60; height: 28; radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.subtitleBgColor === modelData.value
                                        ? Theme.accent : subBgHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1; border.color: Theme.surfaceBorder
                                    property bool subBgHov: false

                                    Text {
                                        anchors.centerIn: parent; text: modelData.label; font.pixelSize: 9
                                        color: appViewModel && appViewModel.subtitleBgColor === modelData.value ? Theme.textOnAccent : Theme.textPrimary
                                    }

                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.subBgHov = true; onExited: parent.subBgHov = false
                                        onClicked: { if (appViewModel) appViewModel.subtitleBgColor = modelData.value }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "Powered by OpenSubtitles.org — no account needed"
                        font.pixelSize: Theme.fontSizeXs
                        font.italic: true
                        color: Theme.textMuted
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: syncCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: syncCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Auto-Sync"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Channel sync interval"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Automatically sync server channels in the background"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: 0, label: "Off" },
                                    { value: 1, label: "1h" },
                                    { value: 6, label: "6h" },
                                    { value: 12, label: "12h" },
                                    { value: 24, label: "24h" },
                                    { value: 48, label: "48h" }
                                ]

                                Rectangle {
                                    width: 52
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.autoSyncInterval === modelData.value
                                        ? Theme.accent : syncChHovered
                                            ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder

                                    property bool syncChHovered: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.autoSyncInterval === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.syncChHovered = true
                                        onExited: parent.syncChHovered = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.autoSyncInterval = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.surfaceBorder
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "EPG sync interval"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Automatically refresh the electronic programme guide"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm
                            Layout.topMargin: Theme.spacingXs

                            Repeater {
                                model: [
                                    { value: 0, label: "Off" },
                                    { value: 1, label: "1h" },
                                    { value: 6, label: "6h" },
                                    { value: 12, label: "12h" },
                                    { value: 24, label: "24h" },
                                    { value: 48, label: "48h" }
                                ]

                                Rectangle {
                                    width: 52
                                    height: 32
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.autoSyncEpgInterval === modelData.value
                                        ? Theme.accent : syncEpgHovered
                                            ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: Theme.surfaceBorder

                                    property bool syncEpgHovered: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeXs
                                        color: appViewModel && appViewModel.autoSyncEpgInterval === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.syncEpgHovered = true
                                        onExited: parent.syncEpgHovered = false
                                        onClicked: {
                                            if (appViewModel)
                                                appViewModel.autoSyncEpgInterval = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: gdriveCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: gdriveCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Google Drive"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXs

                            Text {
                                text: "Connection Status"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                            }

                            RowLayout {
                                spacing: Theme.spacingSm

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: appViewModel && appViewModel.gdrive.authenticated
                                        ? Theme.success : Theme.textMuted
                                }

                                Text {
                                    text: appViewModel && appViewModel.gdrive.authenticated
                                        ? "Connected" : "Not connected"
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textPrimary
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: gdriveBtn.implicitWidth + Theme.spacingLg
                            Layout.preferredHeight: 36
                            radius: Theme.borderRadius
                            color: gdriveBtnHovered
                                ? (appViewModel && appViewModel.gdrive.authenticated ? Theme.error + "30" : Theme.accent)
                                : (appViewModel && appViewModel.gdrive.authenticated ? Theme.error + "20" : Theme.accentHover)
                            border.color: appViewModel && appViewModel.gdrive.authenticated
                                ? Theme.error : Theme.accent
                            border.width: 1

                            property bool gdriveBtnHovered: false

                            Text {
                                id: gdriveBtn
                                anchors.centerIn: parent
                                text: appViewModel && appViewModel.gdrive.authenticated
                                    ? "Disconnect" : "Connect"
                                font.pixelSize: Theme.fontSizeSm
                                color: appViewModel && appViewModel.gdrive.authenticated
                                    ? Theme.error : Theme.textOnAccent
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.gdriveBtnHovered = true
                                onExited: parent.gdriveBtnHovered = false
                                onClicked: {
                                    if (appViewModel) {
                                        if (appViewModel.gdrive.authenticated) {
                                            appViewModel.gdrive.logout()
                                        } else {
                                            appViewModel.gdrive.login()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Authenticates with Google using OAuth 2.0 + PKCE. Click Login to open your browser and grant iptvXS access to the Google Drive folder it uploads recordings to."
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                        wrapMode: Text.WordWrap
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs
                        visible: appViewModel && appViewModel.gdrive.authenticated

                        Text {
                            text: "Upload folder"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: Theme.borderRadiusSmall
                                color: Theme.surface
                                border.color: gdriveFolderInput.activeFocus ? Theme.accent : Theme.surfaceBorder
                                border.width: 1

                                TextInput {
                                    id: gdriveFolderInput
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingSm
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.textPrimary
                                    clip: true
                                    selectByMouse: true
                                    text: appViewModel ? appViewModel.gdrive.folderName : "iptvxs-recordings"

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "e.g. iptvxs-recordings"
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.textMuted
                                        visible: !gdriveFolderInput.text && !gdriveFolderInput.activeFocus
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: saveFolderBtn.implicitWidth + Theme.spacingLg
                                Layout.preferredHeight: 36
                                radius: Theme.borderRadiusSmall
                                color: saveFolderHov ? Theme.accent : Theme.accentHover

                                property bool saveFolderHov: false

                                Text {
                                    id: saveFolderBtn
                                    anchors.centerIn: parent
                                    text: "Save & create"
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textOnAccent
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.saveFolderHov = true
                                    onExited: parent.saveFolderHov = false
                                    onClicked: {
                                        if (!appViewModel) return
                                        appViewModel.gdrive.folderName = gdriveFolderInput.text
                                        appViewModel.gdrive.resolveFolderNow()
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "The folder is created on your Google Drive if it doesn't exist. Only folders created by iptvXS are visible to the app (drive.file scope)."
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
                        }
                    }

                    Text {
                        visible: appViewModel && appViewModel.gdrive.uploadStatus
                        text: appViewModel ? appViewModel.gdrive.uploadStatus : ""
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: recCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: recCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Recordings"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Destination"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: appViewModel && appViewModel.recordingDestination === "gdrive"
                                ? "Recordings are saved locally first, then uploaded to Google Drive"
                                : "Where new recordings are stored when they finish"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Repeater {
                                model: [
                                    { value: "local", label: "Local folder" },
                                    { value: "gdrive", label: "Google Drive" }
                                ]

                                Rectangle {
                                    readonly property bool selected:
                                        appViewModel && appViewModel.recordingDestination === modelData.value
                                    readonly property bool gdriveLocked:
                                        modelData.value === "gdrive" &&
                                        appViewModel && !appViewModel.gdrive.authenticated

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: Theme.borderRadiusSmall
                                    color: selected ? Theme.accent
                                        : destHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: selected ? Theme.accent : Theme.surfaceBorder
                                    opacity: gdriveLocked ? 0.5 : 1.0

                                    property bool destHov: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label +
                                            (gdriveLocked ? "  (connect Google Drive first)" : "")
                                        font.pixelSize: Theme.fontSizeSm
                                        color: selected ? Theme.textOnAccent : Theme.textSecondary
                                        font.bold: selected
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: gdriveLocked
                                            ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                                        enabled: !gdriveLocked
                                        onEntered: parent.destHov = true
                                        onExited: parent.destHov = false
                                        onClicked: {
                                            if (appViewModel && !gdriveLocked) {
                                                appViewModel.recordingDestination = modelData.value
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd
                        visible: appViewModel && appViewModel.recordingDestination === "gdrive"

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXs

                            Text {
                                text: "Keep local copy after upload"
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "Keep the local recording file after uploading to Google Drive"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textMuted
                            }
                        }

                        Switch {
                            checked: appViewModel ? appViewModel.keepLocalCopy : false
                            onToggled: {
                                if (appViewModel) appViewModel.keepLocalCopy = checked
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: appViewModel && appViewModel.recordingDestination === "gdrive"
                                ? "Local staging folder"
                                : "Save recordings to"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: appViewModel && appViewModel.recordingDestination === "gdrive"
                                ? "Recordings are written here during capture, then uploaded to Google Drive"
                                : "Choose where recorded streams are saved on disk"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: Theme.borderRadiusSmall
                                color: Theme.surface
                                border.color: Theme.surfaceBorder
                                border.width: 1

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Theme.spacingSm
                                    text: appViewModel ? appViewModel.recordingDirectory : ""
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                    elide: Text.ElideMiddle
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: browseBtnText.implicitWidth + Theme.spacingLg
                                Layout.preferredHeight: 36
                                radius: Theme.borderRadiusSmall
                                color: browseBtnHov ? Theme.accentHover : Theme.accent

                                property bool browseBtnHov: false

                                Text {
                                    id: browseBtnText
                                    anchors.centerIn: parent
                                    text: "Browse..."
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textOnAccent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: parent.browseBtnHov = true
                                    onExited: parent.browseBtnHov = false
                                    onClicked: recordingFolderDialog.open()
                                }
                            }
                        }
                    }

                    Text {
                        text: "Filename format: date_time_channel_programme.mkv"
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                        font.italic: true
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.surfaceBorder; opacity: 0.5 }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Maximum recording storage"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Oldest recordings are automatically deleted when the limit is reached"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Repeater {
                                model: [
                                    { value: 0, label: "Unlimited" },
                                    { value: 2, label: "2 GB" },
                                    { value: 10, label: "10 GB" },
                                    { value: 20, label: "20 GB" },
                                    { value: 40, label: "40 GB" },
                                    { value: 100, label: "100 GB" }
                                ]

                                Rectangle {
                                    width: maxSzLabel.implicitWidth + 20
                                    height: 28
                                    radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.maxRecordingSizeGb === modelData.value
                                        ? Theme.accent : maxSzHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1
                                    border.color: appViewModel && appViewModel.maxRecordingSizeGb === modelData.value
                                        ? Theme.accent : Theme.surfaceBorder
                                    property bool maxSzHov: false

                                    Text {
                                        id: maxSzLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 9
                                        color: appViewModel && appViewModel.maxRecordingSizeGb === modelData.value
                                            ? Theme.textOnAccent : Theme.textPrimary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.maxSzHov = true
                                        onExited: parent.maxSzHov = false
                                        onClicked: {
                                            if (appViewModel) appViewModel.maxRecordingSizeGb = modelData.value
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "EPG Recording Padding"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "Start recording early and extend past the scheduled end time"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        RowLayout {
                            spacing: Theme.spacingLg

                            RowLayout {
                                spacing: Theme.spacingSm

                                Text { text: "Start early:"; font.pixelSize: Theme.fontSizeXs; color: Theme.textSecondary }

                                Repeater {
                                    model: [0, 1, 2, 3, 5]

                                    Rectangle {
                                        width: 44; height: 28; radius: Theme.borderRadiusSmall
                                        color: appViewModel && appViewModel.epgRecordingLeadTime === modelData
                                            ? Theme.accent : leadHov ? Theme.surfaceHover : Theme.surface
                                        border.width: 1; border.color: Theme.surfaceBorder
                                        property bool leadHov: false

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData + " min"
                                            font.pixelSize: 9
                                            color: appViewModel && appViewModel.epgRecordingLeadTime === modelData
                                                ? Theme.textOnAccent : Theme.textSecondary
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.leadHov = true; onExited: parent.leadHov = false
                                            onClicked: { if (appViewModel) appViewModel.epgRecordingLeadTime = modelData }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                spacing: Theme.spacingSm

                                Text { text: "End late:"; font.pixelSize: Theme.fontSizeXs; color: Theme.textSecondary }

                                Repeater {
                                    model: [0, 1, 2, 3, 5]

                                    Rectangle {
                                        width: 44; height: 28; radius: Theme.borderRadiusSmall
                                        color: appViewModel && appViewModel.epgRecordingOverrun === modelData
                                            ? Theme.accent : overHov ? Theme.surfaceHover : Theme.surface
                                        border.width: 1; border.color: Theme.surfaceBorder
                                        property bool overHov: false

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData + " min"
                                            font.pixelSize: 9
                                            color: appViewModel && appViewModel.epgRecordingOverrun === modelData
                                                ? Theme.textOnAccent : Theme.textSecondary
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onEntered: parent.overHov = true; onExited: parent.overHov = false
                                            onClicked: { if (appViewModel) appViewModel.epgRecordingOverrun = modelData }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: cacheCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: cacheCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Logo Cache"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingLg

                        Text {
                            text: "Cache size:"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }

                        Text {
                            text: {
                                var _ = appViewModel ? appViewModel.logoCache.revision : 0
                                return appViewModel && appViewModel.logoCache ? appViewModel.logoCache.cacheSizeFormatted() : "0 B"
                            }
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.accent
                        }

                        Item { Layout.fillWidth: true }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXs

                        Text {
                            text: "Maximum cache size"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSm

                            Repeater {
                                model: [
                                    { value: 100, label: "100 MB" },
                                    { value: 250, label: "250 MB" },
                                    { value: 500, label: "500 MB" },
                                    { value: 1000, label: "1 GB" },
                                    { value: 2000, label: "2 GB" }
                                ]

                                Rectangle {
                                    width: 64; height: 28; radius: Theme.borderRadiusSmall
                                    color: appViewModel && appViewModel.logoCacheMaxMb === modelData.value
                                        ? Theme.accent : cacheSzHov ? Theme.surfaceHover : Theme.surface
                                    border.width: 1; border.color: Theme.surfaceBorder
                                    property bool cacheSzHov: false

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: 9
                                        color: appViewModel && appViewModel.logoCacheMaxMb === modelData.value
                                            ? Theme.textOnAccent : Theme.textSecondary
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onEntered: parent.cacheSzHov = true; onExited: parent.cacheSzHov = false
                                        onClicked: { if (appViewModel) appViewModel.logoCacheMaxMb = modelData.value }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "Logos older than 30 days are automatically removed on startup."
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        Text {
                            text: "Clearing the cache will cause all logos to be re-downloaded.\nThis may temporarily impact performance."
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.warning
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignRight
                            width: clearCacheLabel.implicitWidth + Theme.spacingLg * 2
                            height: 36
                            radius: Theme.borderRadius
                            color: clearCacheHov ? Theme.error : Theme.error + "30"
                            border.color: Theme.error
                            border.width: 1
                            property bool clearCacheHov: false

                            Text {
                                id: clearCacheLabel
                                anchors.centerIn: parent
                                text: "Clear Logo Cache"
                                font.pixelSize: Theme.fontSizeSm
                                font.bold: true
                                color: clearCacheLabel.parent.clearCacheHov ? Theme.textOnAccent : Theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: parent.clearCacheHov = true; onExited: parent.clearCacheHov = false
                                onClicked: {
                                    if (appViewModel && appViewModel.logoCache) {
                                        appViewModel.logoCache.clear()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: dbCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                ColumnLayout {
                    id: dbCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingMd

                    Text {
                        text: "Database"
                        font.pixelSize: Theme.fontSizeMd
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "Status"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: appViewModel && appViewModel.databaseReady
                                ? Theme.success : Theme.error
                        }

                        Text {
                            text: appViewModel && appViewModel.databaseReady
                                ? "Connected" : "Disconnected"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: appViewModel ? appViewModel.databaseSize : ""
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: Theme.accent
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm

                        Text {
                            text: "Path"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }

                        Text {
                            text: appViewModel ? appViewModel.databasePath : ""
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.surfaceBorder
                    }

                    // Database statistics
                    GridLayout {
                        id: dbStatsGrid
                        Layout.fillWidth: true
                        columns: 5
                        columnSpacing: Theme.spacingMd
                        rowSpacing: Theme.spacingSm

                        property var stats: appViewModel ? appViewModel.databaseStats() : ({})

                        Repeater {
                            model: [
                                { label: "Servers", key: "servers" },
                                { label: "TV Channels", key: "channels" },
                                { label: "Movies", key: "movies" },
                                { label: "Series", key: "series" },
                                { label: "Recordings", key: "recordings" },
                                { label: "Favourites", key: "favourites" },
                                { label: "Groups", key: "groups" },
                                { label: "EPG Programmes", key: "programmes" },
                                { label: "History", key: "history" }
                            ]

                            delegate: Column {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: {
                                        var val = dbStatsGrid.stats[modelData.key];
                                        return val !== undefined ? Number(val).toLocaleString() : "0";
                                    }
                                    font.pixelSize: Theme.fontSizeMd
                                    font.bold: true
                                    color: Theme.textPrimary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textMuted
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.surfaceBorder
                    }

                    Text {
                        text: "Reset will delete all servers, channels, recordings, favorites, and settings."
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textMuted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: resetBtnText.implicitWidth + Theme.spacingLg * 2
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignRight
                        radius: Theme.borderRadius
                        color: resetBtnHovered ? Qt.darker(Theme.error, 1.2) : Theme.error

                        property bool resetBtnHovered: false

                        Text {
                            id: resetBtnText
                            anchors.centerIn: parent
                            text: "Reset Database"
                            font.pixelSize: Theme.fontSizeSm
                            font.bold: true
                            color: "#000000"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.resetBtnHovered = true
                            onExited: parent.resetBtnHovered = false
                            onClicked: resetConfirmDialog.open()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: aboutCol.implicitHeight + Theme.spacingLg * 2
                radius: Theme.borderRadiusLarge
                color: Theme.surfaceElevated
                border.color: Theme.surfaceBorder
                border.width: 1

                RowLayout {
                    id: aboutCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLg
                    spacing: Theme.spacingLg

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingMd

                        Text {
                            text: "About"
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            color: Theme.textPrimary
                        }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "iptvXS"
                            font.pixelSize: Theme.fontSizeLg
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Rectangle {
                            visible: appViewModel && appViewModel.updateAvailable
                            width: updateLabel.implicitWidth + 12
                            height: 20
                            radius: 10
                            color: Theme.accent
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: updateLabel
                                anchors.centerIn: parent
                                text: "Update available"
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.textOnAccent
                            }
                        }
                    }

                    Text {
                        text: "Cross-platform IPTV viewer built with Qt6 and libmpv"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textMuted
                    }

                    Text {
                        text: "Author: Schelstraete Bart"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "Current version:"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
                        Text {
                            text: "v" + (appViewModel ? appViewModel.appVersion : "?")
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textPrimary
                            font.bold: true
                        }
                    }

                    RowLayout {
                        spacing: Theme.spacingMd

                        Text {
                            text: "Latest version:"
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textMuted
                        }
                        Text {
                            text: appViewModel && appViewModel.latestVersion ? appViewModel.latestVersion : "checking..."
                            font.pixelSize: Theme.fontSizeXs
                            color: appViewModel && appViewModel.updateAvailable ? Theme.accent : Theme.textPrimary
                            font.bold: true
                        }
                    }

                    RowLayout {
                        spacing: Theme.spacingSm

                        Rectangle {
                            width: githubLabel.implicitWidth + Theme.spacingLg
                            height: 32
                            radius: Theme.borderRadius
                            color: githubHov ? Theme.surfaceHover : Theme.surface
                            border.color: Theme.surfaceBorder
                            border.width: 1
                            property bool githubHov: false

                            Text {
                                id: githubLabel
                                anchors.centerIn: parent
                                text: "View on GitHub"
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.githubHov = true
                                onExited: parent.githubHov = false
                                onClicked: { if (appViewModel) appViewModel.openGitHub() }
                            }
                        }

                        Rectangle {
                            width: checkLabel.implicitWidth + Theme.spacingLg
                            height: 32
                            radius: Theme.borderRadius
                            color: checkHov ? Theme.accentHover : Theme.accent
                            property bool checkHov: false

                            Text {
                                id: checkLabel
                                anchors.centerIn: parent
                                text: "Check for Updates"
                                font.pixelSize: Theme.fontSizeXs
                                font.bold: true
                                color: Theme.textOnAccent
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.checkHov = true
                                onExited: parent.checkHov = false
                                onClicked: { if (appViewModel) appViewModel.checkForUpdates() }
                            }
                        }
                    }
                    }

                    Image {
                        Layout.preferredWidth: 128
                        Layout.preferredHeight: 128
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        source: "qrc:/images/iptvxs_tray.png"
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.6
                    }
                }
            }

            Item { Layout.preferredHeight: Theme.spacingLg }
        }
    }

    Dialog {
        id: resetConfirmDialog
        anchors.centerIn: parent
        width: 400
        modal: true
        title: "Reset Database"

        background: Rectangle {
            color: Theme.surfaceElevated
            radius: Theme.borderRadiusLarge
            border.color: Theme.error
            border.width: 1
        }

        header: Rectangle {
            height: 48
            color: "transparent"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingLg
                anchors.verticalCenter: parent.verticalCenter
                text: "Confirm Reset"
                font.pixelSize: Theme.fontSizeLg
                font.bold: true
                color: Theme.error
            }
        }

        contentItem: Text {
            text: "This will permanently delete all data including servers, channels, favorites, recordings, and settings. This cannot be undone."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.textSecondary
            wrapMode: Text.WordWrap
        }

        footer: Rectangle {
            height: 56
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingMd

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth: cancelResetText.implicitWidth + Theme.spacingLg * 2
                    Layout.preferredHeight: 36
                    radius: Theme.borderRadius
                    color: cancelResetHov ? Theme.surfaceHover : "transparent"
                    border.color: Theme.surfaceBorder
                    border.width: 1

                    property bool cancelResetHov: false

                    Text {
                        id: cancelResetText
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.cancelResetHov = true
                        onExited: parent.cancelResetHov = false
                        onClicked: resetConfirmDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: confirmResetText.implicitWidth + Theme.spacingLg * 2
                    Layout.preferredHeight: 36
                    radius: Theme.borderRadius
                    color: confirmResetHov ? Theme.error : Theme.error + "80"

                    property bool confirmResetHov: false

                    Text {
                        id: confirmResetText
                        anchors.centerIn: parent
                        text: "Reset"
                        font.pixelSize: Theme.fontSizeSm
                        font.bold: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.confirmResetHov = true
                        onExited: parent.confirmResetHov = false
                        onClicked: {
                            if (appViewModel) {
                                appViewModel.resetDatabase()
                            }
                            resetConfirmDialog.close()
                        }
                    }
                }
            }
        }

        Overlay.modal: Rectangle {
            color: "#80000000"
        }
    }

    FolderDialog {
        id: recordingFolderDialog
        title: "Choose Recording Directory"
        currentFolder: appViewModel
            ? "file://" + appViewModel.recordingDirectory : ""

        onAccepted: {
            if (appViewModel) {
                var path = selectedFolder.toString().replace("file://", "")
                appViewModel.recordingDirectory = path
            }
        }
    }

    // --- Google Drive auth URL fallback dialog (for GameScope / no desktop browser) ---

    property string pendingAuthUrl: ""

    Connections {
        target: appViewModel
        function onAuthUrlReady(url) {
            settingsView.pendingAuthUrl = url
            authUrlDialog.open()
        }
    }

    Dialog {
        id: authUrlDialog
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.85, 600)
        modal: true
        title: "Google Drive Login"
        standardButtons: Dialog.Close

        background: Rectangle {
            color: Theme.surfaceElevated
            border.color: Theme.surfaceBorder
            border.width: 1
            radius: Theme.borderRadiusLarge
        }

        header: Item {
            height: 48
            Text {
                anchors.centerIn: parent
                text: "Google Drive Login"
                font.pixelSize: Theme.fontSizeMd
                font.bold: true
                color: Theme.textPrimary
            }
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacingMd

            Text {
                Layout.fillWidth: true
                text: "If your browser did not open automatically (e.g. on Steam Deck in Gaming Mode), copy the URL below and paste it into a browser on any device:"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: authUrlText.implicitHeight + Theme.spacingMd
                color: Theme.background
                border.color: Theme.surfaceBorder
                border.width: 1
                radius: Theme.borderRadius

                TextEdit {
                    id: authUrlText
                    anchors.fill: parent
                    anchors.margins: Theme.spacingSm
                    text: settingsView.pendingAuthUrl
                    font.pixelSize: Theme.fontSizeXs
                    font.family: "monospace"
                    color: Theme.accent
                    wrapMode: TextEdit.WrapAnywhere
                    readOnly: true
                    selectByMouse: true
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: copyBtn.implicitWidth + Theme.spacingLg * 2
                Layout.preferredHeight: 36
                radius: Theme.borderRadius
                color: copyBtnHovered ? Theme.accent : Theme.accentHover
                border.color: Theme.accent
                border.width: 1
                property bool copyBtnHovered: false

                Text {
                    id: copyBtn
                    anchors.centerIn: parent
                    text: "Select All"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.textOnAccent
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: parent.copyBtnHovered = true
                    onExited: parent.copyBtnHovered = false
                    onClicked: {
                        authUrlText.selectAll()
                        authUrlText.focus = true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "After granting access, the browser will redirect to localhost and this app will receive the token automatically."
                font.pixelSize: Theme.fontSizeXs
                color: Theme.textMuted
                wrapMode: Text.WordWrap
            }
        }
    }
}
