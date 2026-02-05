pragma Singleton
import QtQuick

QtObject {
    // Colors
    property color background: "#0F0F0F"
    property color surface: "#181818"
    property color surfaceHighlight: "#222222"
    property color border: "#333333"
    property color textPrimary: "#E0E0E0"
    property color textSecondary: "#909090"
    property color accent: "#01D4FE"
    property color accentHover: "#34E0FF"
    property color accentSecondary: "#60115F"
    property color accentDark1: "#0C2433"
    property color accentDark2: "#12414E"
    property color error: "#F48771"

    // Spacing
    property int spacingSmall: 4
    property int spacingMedium: 8
    property int spacingLarge: 16
    property int spacingXLarge: 24

    // Sizes
    property int sidebarWidth: 250
    property int sidebarMinWidth: 200
    property int sidebarMaxWidth: 360
    property int sidebarRailWidth: 48
    property int sidebarIconSize: 18
    property int tabBarHeight: 35
    property int buttonHeight: 30
    property int radius: 4
}
