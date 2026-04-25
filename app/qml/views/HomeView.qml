import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import app.iptvxs

Item {
    id: homeView

    property int currentCardIndex: 0

    function activateCurrentCard() {
        var card = homeCards.itemAt(currentCardIndex)
        if (card && card.activateCard) {
            card.activateCard()
        }
    }

    function focusPrimary() {
        homeView.forceActiveFocus()
    }

    Keys.onLeftPressed: {
        if (currentCardIndex % 3 !== 0) currentCardIndex--
    }
    Keys.onRightPressed: {
        if (currentCardIndex % 3 !== 2 && currentCardIndex < homeCards.count - 1) currentCardIndex++
    }
    Keys.onUpPressed: {
        if (currentCardIndex >= 3) currentCardIndex -= 3
        else if (Window.window && Window.window.focusSidebar) Window.window.focusSidebar()
    }
    Keys.onDownPressed: {
        if (currentCardIndex + 3 < homeCards.count) currentCardIndex += 3
    }
    Keys.onReturnPressed: activateCurrentCard()
    Keys.onEnterPressed: activateCurrentCard()
    focus: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXl
        spacing: Theme.spacingLg

        Text {
            text: "Welcome to iptvXS"
            font.pixelSize: Theme.fontSizeHero
            font.bold: true
            color: Theme.textPrimary

            opacity: 0
            Component.onCompleted: {
                opacity = 1
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animSlow
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            text: "Live TV, VOD & recordings — all in one"
            font.pixelSize: Theme.fontSizeLg
            color: Theme.textSecondary
            Layout.bottomMargin: Theme.spacingLg

            opacity: 0
            Component.onCompleted: {
                opacity = 1
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animSlow
                    easing.type: Easing.OutCubic
                }
            }
        }

        GridLayout {
            columns: 3
            columnSpacing: Theme.spacingMd
            rowSpacing: Theme.spacingMd
            Layout.fillWidth: true

            Repeater {
                id: homeCards
                model: [
                    { title: "Add Server", desc: "Connect to Xtream Codes or M3U", icon: "🔗", color: "#6c5ce7" },
                    { title: "Browse Channels", desc: "Explore your channel library", icon: "📺", color: "#00cec9" },
                    { title: "TV Guide", desc: "Check what's on now", icon: "📅", color: "#fd79a8" },
                    { title: "Recordings", desc: "Manage your recordings", icon: "⏺", color: "#ff6b6b" },
                    { title: "Speed Test", desc: "Check your connection", icon: "⚡", color: "#fdcb6e" },
                    { title: "Settings", desc: "Customize your experience", icon: "⚙", color: "#a29bfe" }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 140
                    radius: Theme.borderRadiusLarge
                    color: cardHovered ? Theme.surfaceHover : Theme.surfaceElevated
                    border.color: homeView.currentCardIndex === index && homeView.activeFocus
                        ? Theme.accent
                        : cardHovered ? modelData.color + "40" : Theme.surfaceBorder
                    border.width: homeView.currentCardIndex === index && homeView.activeFocus ? 2 : 1

                    property bool cardHovered: false

                    function activateCard() {
                        var viewMap = {
                            "Add Server": "servers",
                            "Browse Channels": "channels",
                            "TV Guide": "epg",
                            "Recordings": "recordings",
                            "Speed Test": "speedtest",
                            "Settings": "settings"
                        }
                        var target = viewMap[modelData.title]
                        if (target && appViewModel) {
                            appViewModel.currentView = target
                        }
                    }

                    opacity: 0
                    Component.onCompleted: {
                        delayAnim.start()
                    }

                    Timer {
                        id: delayAnim
                        interval: index * 80
                        onTriggered: parent.opacity = 1
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animNormal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation { duration: Theme.animFast }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: Theme.animFast }
                    }

                    scale: cardHovered ? 1.02 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingLg
                        spacing: Theme.spacingSm

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: Theme.borderRadius
                            color: modelData.color + "20"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: Theme.fontSizeXl
                            }
                        }

                        Text {
                            text: modelData.title
                            font.pixelSize: Theme.fontSizeMd
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: modelData.desc
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textSecondary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.cardHovered = true
                        onExited: parent.cardHovered = false
                        onClicked: {
                            homeView.currentCardIndex = index
                            homeView.forceActiveFocus()
                            parent.activateCard()
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: Theme.success
            }

            Text {
                text: "Database ready"
                font.pixelSize: Theme.fontSizeXs
                color: Theme.textMuted
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "v" + (appViewModel ? appViewModel.appVersion : "0.1.0")
                font.pixelSize: Theme.fontSizeXs
                color: Theme.textMuted
            }
        }
    }
}
