import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: Theme.sidebarWidth
    color: Theme.surface
    property string errorMessage: ""
    
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

    Connections {
        target: App
        function onConnectionOpened(id) {
            root.errorMessage = ""
        }
        function onConnectionClosed() {
            root.errorMessage = ""
        }
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

        Text {
            visible: root.errorMessage.length > 0
            text: root.errorMessage
            color: Theme.error
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.leftMargin: Theme.spacingMedium
            Layout.rightMargin: Theme.spacingMedium
            Layout.fillWidth: true
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
                            var ok = App.openConnection(modelData.id)
                            if (!ok) {
                                root.errorMessage = App.lastError
                            } else {
                                root.errorMessage = ""
                            }
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
