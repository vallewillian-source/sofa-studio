pragma Singleton
import QtQuick

QtObject {
    // Colors
    property color background: "#1E1E1E"
    property color surface: "#252526"
    property color surfaceHighlight: "#2A2D2E"
    property color border: "#3E3E42"
    property color textPrimary: "#CCCCCC"
    property color textSecondary: "#858585"
    property color accent: "#007ACC"
    property color accentHover: "#0098FF"
    property color error: "#F48771"

    // Spacing
    property int spacingSmall: 4
    property int spacingMedium: 8
    property int spacingLarge: 16
    property int spacingXLarge: 24

    // Sizes
    property int sidebarWidth: 250
    property int sidebarRailWidth: 48
    property int sidebarIconSize: 18
    property int tabBarHeight: 35
    property int buttonHeight: 30
    property int radius: 4
}
