import QtQuick

Item {
    id: root

    property real logoSize: 0
    property real logoWidth: 0
    property real logoHeight: 0
    property real logoOpacity: 0.28
    property url logoSource: "qrc:/images/iptvxs_tray.png"
    property real logoAreaHeight: 110
    property real logoYOffset: 0
    property bool liveTvGeometry: false

    anchors.fill: parent
    clip: true

    readonly property real effectiveAreaHeight: {
        if (!parent) {
            return logoAreaHeight
        }
        if (liveTvGeometry) {
            return parent.height
        }
        return Math.min(logoAreaHeight, parent.height)
    }

    readonly property real effectiveLogoWidth: {
        if (logoWidth > 0) return logoWidth
        if (logoSize > 0) return logoSize
        if (parent) return Math.max(0, parent.width - 24)
        return 56
    }

    readonly property real effectiveLogoHeight: {
        if (logoHeight > 0) return logoHeight
        if (logoSize > 0) return logoSize
        if (parent) return Math.max(0, parent.height - 16)
        return 56
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.effectiveAreaHeight
        color: "transparent"

        Image {
            anchors.fill: parent
            visible: root.liveTvGeometry
            source: root.logoSource
            fillMode: Image.PreserveAspectFit
            opacity: root.logoOpacity
            asynchronous: false
            cache: true
        }

        Image {
            anchors.centerIn: parent
            visible: !root.liveTvGeometry
            anchors.verticalCenterOffset: root.logoYOffset
            width: root.effectiveLogoWidth
            height: root.effectiveLogoHeight
            source: root.logoSource
            fillMode: Image.PreserveAspectFit
            opacity: root.logoOpacity
            asynchronous: false
            cache: true
        }
    }
}
