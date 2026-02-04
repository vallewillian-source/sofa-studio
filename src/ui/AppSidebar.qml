import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: Theme.sidebarWidth
    color: Theme.surface
    
    border.color: Theme.border
    border.width: 1
    // Border only on right side
    Rectangle {
        width: 1
        height: parent.height
        color: Theme.border
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "transparent"
            
            Text {
                text: "CONNECTIONS"
                font.bold: true
                font.pixelSize: 11
                color: Theme.textSecondary
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // List Placeholder
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Text {
                text: "No connections"
                color: Theme.textSecondary
                font.italic: true
                anchors.centerIn: parent
            }
        }

        // Footer Actions
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "transparent"
            
            AppButton {
                text: "New Connection"
                isPrimary: true
                anchors.centerIn: parent
                width: parent.width - (Theme.spacingMedium * 2)
                onClicked: console.log("New Connection clicked")
            }
        }
    }
}
