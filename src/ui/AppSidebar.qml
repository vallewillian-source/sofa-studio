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

    ConnectionDialog {
        id: connectionDialog
        anchors.centerIn: Overlay.overlay
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

        // Connections List
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: App.connections
            
            delegate: Rectangle {
                width: ListView.view.width
                height: 30
                color: (modelData.id === App.activeConnectionId) ? Theme.surfaceHighlight : (mouseArea.containsMouse ? Theme.surfaceHighlight : "transparent")
                
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.id !== App.activeConnectionId) {
                            App.openConnection(modelData.id)
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.rightMargin: Theme.spacingMedium
                    spacing: Theme.spacingSmall
                    
                    Text {
                        text: modelData.name
                        color: (modelData.id === App.activeConnectionId) ? Theme.accent : Theme.textPrimary
                        font.pixelSize: 13
                        font.bold: (modelData.id === App.activeConnectionId)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    
                    // Edit Button (Text for now)
                    Text {
                        text: "✎"
                        color: Theme.textSecondary
                        visible: mouseArea.containsMouse
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                connectionDialog.resetFields()
                                connectionDialog.load(modelData)
                                connectionDialog.open()
                            }
                        }
                    }

                    // Delete Button
                    Text {
                        text: "✖"
                        color: Theme.textSecondary
                        visible: mouseArea.containsMouse
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: App.deleteConnection(modelData.id)
                        }
                    }
                }
                
                MouseArea {
                    id: backgroundMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    onClicked: mouse.accepted = false // Pass through
                }
            }
            
            // Empty State
            Text {
                visible: parent.count === 0
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
                onClicked: {
                    connectionDialog.resetFields()
                    connectionDialog.open()
                }
            }
        }
    }
}
