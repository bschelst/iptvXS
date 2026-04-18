pragma Singleton

import QtQuick

QtObject {
    // Surface colors
    readonly property color background: "#0a0a0f"
    readonly property color surface: "#12121a"
    readonly property color surfaceElevated: "#1a1a26"
    readonly property color surfaceHover: "#22222e"
    readonly property color surfaceBorder: "#2a2a3a"

    // Text colors
    readonly property color textPrimary: "#f0f0f5"
    readonly property color textSecondary: "#8888a0"
    readonly property color textMuted: "#555566"

    // Accent colors
    readonly property color accent: "#6c5ce7"
    readonly property color accentHover: "#7c6cf7"
    readonly property color accentGlow: "#6c5ce720"
    readonly property color success: "#00cec9"
    readonly property color warning: "#fdcb6e"
    readonly property color error: "#ff6b6b"
    readonly property color live: "#ff4757"

    // Dimensions
    readonly property int sidebarWidth: 240
    readonly property int sidebarCollapsedWidth: 64
    readonly property int topBarHeight: 56
    readonly property int borderRadius: 8
    readonly property int borderRadiusSmall: 4
    readonly property int borderRadiusLarge: 16

    // Spacing
    readonly property int spacingXs: 4
    readonly property int spacingSm: 8
    readonly property int spacingMd: 16
    readonly property int spacingLg: 24
    readonly property int spacingXl: 32

    // Typography
    readonly property int fontSizeXs: 11
    readonly property int fontSizeSm: 13
    readonly property int fontSizeMd: 15
    readonly property int fontSizeLg: 20
    readonly property int fontSizeXl: 28
    readonly property int fontSizeHero: 48

    // Animation
    readonly property int animFast: 150
    readonly property int animNormal: 250
    readonly property int animSlow: 400
}
