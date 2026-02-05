import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    
    // Custom properties
    property bool isPrimary: false
    property color textColor: isPrimary ? "#000000" : Theme.textPrimary

    contentItem: Text {
        text: control.text
        font: control.font
        opacity: enabled ? 1.0 : 0.3
        color: control.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: Theme.buttonHeight
        opacity: enabled ? 1 : 0.3
        color: {
            if (control.pressed) return control.isPrimary ? Qt.darker(Theme.accent, 1.1) : Theme.surfaceHighlight
            if (control.hovered) return control.isPrimary ? Theme.accentHover : Theme.surfaceHighlight
            return control.isPrimary ? Theme.accent : Theme.surface
        }
        border.color: control.isPrimary ? "transparent" : Theme.border
        border.width: 1
        radius: Theme.radius
    }
}
