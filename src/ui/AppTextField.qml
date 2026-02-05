import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TextField {
    id: control
    
    placeholderTextColor: Theme.textSecondary
    color: Theme.textPrimary
    selectionColor: Theme.accent
    selectedTextColor: "#FFFFFF"
    font.pixelSize: 14
    leftPadding: 10
    rightPadding: 10
    topPadding: 6
    bottomPadding: 6
    
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: Theme.buttonHeight
        color: Theme.surface
        border.color: control.activeFocus ? Theme.accent : Theme.border
        border.width: 1
        radius: Theme.radius
    }
}
