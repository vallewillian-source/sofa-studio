import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

TabBar {
    id: control
    
    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        // Border only bottom
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
            anchors.bottom: parent.bottom
        }
    }

    TabButton {
        text: "Home"
        width: implicitWidth + Theme.spacingXLarge
        
        contentItem: Text {
            text: parent.text
            font: parent.font
            opacity: enabled ? 1.0 : 0.3
            color: parent.checked ? Theme.textPrimary : Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            implicitHeight: Theme.tabBarHeight
            color: parent.checked ? Theme.background : "transparent"
            
            // Top highlight line for active tab
            Rectangle {
                width: parent.width
                height: 2
                color: Theme.accent
                anchors.top: parent.top
                visible: parent.parent.checked
            }
        }
    }

    TabButton {
        text: "Query 1"
        width: implicitWidth + Theme.spacingXLarge
        
        contentItem: Text {
            text: parent.text
            font: parent.font
            opacity: enabled ? 1.0 : 0.3
            color: parent.checked ? Theme.textPrimary : Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            implicitHeight: Theme.tabBarHeight
            color: parent.checked ? Theme.background : "transparent"
            
            // Top highlight line for active tab
            Rectangle {
                width: parent.width
                height: 2
                color: Theme.accent
                anchors.top: parent.top
                visible: parent.parent.checked
            }
        }
    }
}
