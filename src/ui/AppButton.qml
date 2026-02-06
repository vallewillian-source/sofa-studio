import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Button {
    id: control
    
    // Custom properties
    property bool isPrimary: false
    property bool isOutline: false
    property color textColor: {
        if (isPrimary) return "#000000"
        if (isOutline) return accentColor
        return Theme.textPrimary
    }
    property string tooltip: ""
    property int iconSize: 16
    spacing: 8
    property color accentColor: Theme.accent

    // Reset default padding to ensure centering
    padding: 0
    horizontalPadding: control.text.length > 0 ? 12 : 0
    verticalPadding: 0

    ToolTip {
        visible: control.hovered && control.tooltip.length > 0
        text: control.tooltip
        delay: 500
        timeout: 5000
        
        contentItem: Text {
            text: control.tooltip
            font.pixelSize: 12
            color: Theme.textPrimary
        }
        
        background: Rectangle {
            color: Theme.surfaceHighlight
            border.color: Theme.border
            border.width: 1
            radius: 4
        }
    }

    contentItem: RowLayout {
        spacing: textItem.text.length > 0 ? control.spacing : 0
        
        Item {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            visible: control.icon.source.toString().length > 0
            Layout.preferredWidth: control.iconSize
            Layout.preferredHeight: control.iconSize
            
            Image {
                id: btnIcon
                anchors.fill: parent
                source: control.icon.source
                sourceSize.width: control.iconSize
                sourceSize.height: control.iconSize
                visible: false
                fillMode: Image.PreserveAspectFit
            }
            
            ColorOverlay {
                anchors.fill: btnIcon
                source: btnIcon
                color: control.textColor
                antialiasing: true
            }
        }

        Text {
            id: textItem
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            text: control.text
            visible: text.length > 0
            font: control.font
            opacity: enabled ? 1.0 : 0.3
            color: control.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        
        // Add a spacer if we want to center the content in the button
        // But RowLayout inside contentItem usually centers itself if we don't force it
    }

    background: Rectangle {
        implicitWidth: Theme.buttonHeight
        implicitHeight: Theme.buttonHeight
        opacity: enabled ? 1 : 0.3
        color: {
            if (control.isOutline) {
                if (control.pressed) return Theme.tintColor(Theme.background, control.accentColor, 0.2)
                if (control.hovered) return Theme.tintColor(Theme.background, control.accentColor, 0.1)
                return "transparent"
            }
            if (control.pressed) return control.isPrimary ? Qt.darker(control.accentColor, 1.1) : Theme.surfaceHighlight
            if (control.hovered) return control.isPrimary ? Qt.lighter(control.accentColor, 1.1) : Theme.surfaceHighlight
            return control.isPrimary ? control.accentColor : Theme.surface
        }
        border.color: {
            if (control.isOutline) return control.accentColor
            return control.isPrimary ? "transparent" : Theme.border
        }
        border.width: 1
        radius: Theme.radius
    }
}
