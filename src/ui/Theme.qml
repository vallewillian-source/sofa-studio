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
    property color accent: "#FFA507"
    property color accentHover: "#FEB83B"
    property color accentSecondary: "#FEB83B"
    property color accentDark1: "#13132B"
    property color accentDark2: "#262645"
    property color error: "#F48771"
    readonly property var connectionAvatarColors: [
        "#FFA507", // Sofa Orange (Institutional)
        "#01D4FE", // Electric Blue
        "#FF5F5F", // Soft Red
        "#4CAF50", // Success Green
        "#A855F7", // Modern Purple
        "#EC4899", // Vibrant Pink
        "#3B82F6", // Royal Blue
        "#14B8A6", // Teal
        "#F59E0B", // Amber
        "#6366F1"  // Indigo
    ]

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
    property int sidebarIconSize: 20
    property int tabBarHeight: 35
    property int buttonHeight: 30
    property int radius: 4
}
