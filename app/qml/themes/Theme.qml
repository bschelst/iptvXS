pragma Singleton

import QtQuick

QtObject {
    // Surface colors
    property color background: "#0a0a0f"
    property color surface: "#12121a"
    property color surfaceElevated: "#1a1a26"
    property color surfaceHover: "#22222e"
    property color surfaceBorder: "#2a2a3a"

    // Text colors
    property color textPrimary: "#f0f0f5"
    property color textSecondary: "#8888a0"
    property color textMuted: "#555566"

    // Accent colors
    property color accent: "#6c5ce7"
    property color accentHover: "#7c6cf7"
    property color accentGlow: "#6c5ce720"
    property color success: "#00cec9"
    property color warning: "#fdcb6e"
    property color error: "#ff6b6b"
    property color live: "#ff4757"

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

    // Theme state
    property string currentTheme: "midnight"
    property var themeNames: ["midnight", "ocean", "forest", "sunset", "nord", "light", "high-contrast"]

    function applyTheme(name) {
        currentTheme = name
        var t = themes[name]
        if (!t) return

        background = t.background
        surface = t.surface
        surfaceElevated = t.surfaceElevated
        surfaceHover = t.surfaceHover
        surfaceBorder = t.surfaceBorder
        textPrimary = t.textPrimary
        textSecondary = t.textSecondary
        textMuted = t.textMuted
        accent = t.accent
        accentHover = t.accentHover
        accentGlow = t.accent + "20"
        success = t.success
        warning = t.warning
        error = t.error
        live = t.live
    }

    property var themes: ({
        "midnight": {
            background: "#0a0a0f",
            surface: "#12121a",
            surfaceElevated: "#1a1a26",
            surfaceHover: "#22222e",
            surfaceBorder: "#2a2a3a",
            textPrimary: "#f0f0f5",
            textSecondary: "#8888a0",
            textMuted: "#555566",
            accent: "#6c5ce7",
            accentHover: "#7c6cf7",
            success: "#00cec9",
            warning: "#fdcb6e",
            error: "#ff6b6b",
            live: "#ff4757"
        },
        "ocean": {
            background: "#0b1628",
            surface: "#0f1e35",
            surfaceElevated: "#162a46",
            surfaceHover: "#1d3557",
            surfaceBorder: "#264573",
            textPrimary: "#e8edf5",
            textSecondary: "#7b8fb0",
            textMuted: "#4a5e80",
            accent: "#0ea5e9",
            accentHover: "#38bdf8",
            success: "#34d399",
            warning: "#fbbf24",
            error: "#f87171",
            live: "#ef4444"
        },
        "forest": {
            background: "#0a1210",
            surface: "#111d19",
            surfaceElevated: "#1a2b25",
            surfaceHover: "#233830",
            surfaceBorder: "#2d4a3f",
            textPrimary: "#e8f0ec",
            textSecondary: "#7da394",
            textMuted: "#4d7565",
            accent: "#10b981",
            accentHover: "#34d399",
            success: "#22d3ee",
            warning: "#fbbf24",
            error: "#fb7185",
            live: "#ef4444"
        },
        "sunset": {
            background: "#140a0a",
            surface: "#1e1010",
            surfaceElevated: "#2a1818",
            surfaceHover: "#352020",
            surfaceBorder: "#4a2c2c",
            textPrimary: "#f5ebe8",
            textSecondary: "#b08888",
            textMuted: "#7a5555",
            accent: "#f97316",
            accentHover: "#fb923c",
            success: "#4ade80",
            warning: "#fde047",
            error: "#f87171",
            live: "#ef4444"
        },
        "nord": {
            background: "#2e3440",
            surface: "#3b4252",
            surfaceElevated: "#434c5e",
            surfaceHover: "#4c566a",
            surfaceBorder: "#5a657a",
            textPrimary: "#eceff4",
            textSecondary: "#a3b1c4",
            textMuted: "#6b7a90",
            accent: "#88c0d0",
            accentHover: "#8fbcbb",
            success: "#a3be8c",
            warning: "#ebcb8b",
            error: "#bf616a",
            live: "#d08770"
        },
        "light": {
            background: "#f5f5f7",
            surface: "#ffffff",
            surfaceElevated: "#f0f0f2",
            surfaceHover: "#e8e8ec",
            surfaceBorder: "#d4d4d8",
            textPrimary: "#18181b",
            textSecondary: "#71717a",
            textMuted: "#a1a1aa",
            accent: "#6c5ce7",
            accentHover: "#7c6cf7",
            success: "#059669",
            warning: "#d97706",
            error: "#dc2626",
            live: "#dc2626"
        },
        "high-contrast": {
            background: "#000000",
            surface: "#0a0a0a",
            surfaceElevated: "#1a1a1a",
            surfaceHover: "#2a2a2a",
            surfaceBorder: "#ffffff",
            textPrimary: "#ffffff",
            textSecondary: "#e0e0e0",
            textMuted: "#b0b0b0",
            accent: "#ffcc00",
            accentHover: "#ffdd44",
            success: "#00ff88",
            warning: "#ffdd00",
            error: "#ff3333",
            live: "#ff0040"
        }
    })
}
