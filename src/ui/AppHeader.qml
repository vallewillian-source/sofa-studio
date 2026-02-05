import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root
    height: 30
    color: "transparent"

    property Window windowRef: null
    property bool isMac: Qt.platform.os === "osx"
    property int radius: (windowRef && windowRef.visibility === Window.Maximized) ? 0 : 10
    
    // Background with top rounded corners
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: root.radius
        border.color: Theme.border
        border.width: 1
        
        // Patch Bottom (make square)
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.radius
            color: Theme.surface
            visible: parent.radius > 0
        }
    }
    
    // Re-draw borders covered by patch
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 1
        height: root.radius
        color: Theme.border
        visible: root.radius > 0
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        height: root.radius
        color: Theme.border
        visible: root.radius > 0
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.border
    }

    signal requestNewConnection()
    signal requestEditConnection(var connectionId)
    signal requestDeleteConnection(var connectionId)

    property string activeConnectionName: {
        var currentId = App.activeConnectionId
        if (currentId === -1) {
            return "Sofa Studio"
        }
        
        var conns = App.connections
        for (var i = 0; i < conns.length; i++) {
            if (conns[i].id === currentId) {
                return conns[i].name
            }
        }
        return "Unknown"
    }

    ConnectionSelectorModal {
        id: connectionModal
        onNewConnectionRequested: root.requestNewConnection()
        onConnectionSelected: (id) => App.openConnection(id)
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onPressed: {
            if (windowRef) {
                windowRef.startSystemMove()
            }
        }
        onDoubleClicked: {
            if (windowRef && windowRef.toggleMaximize) {
                windowRef.toggleMaximize()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMedium
        anchors.rightMargin: Theme.spacingMedium
        spacing: Theme.spacingMedium
        z: 1

        RowLayout {
            spacing: 6

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: "#FF5F57"
                border.color: "#E0443E"
                visible: isMac

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (windowRef) windowRef.close()
                }
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: "#FFBD2E"
                border.color: "#DEA123"
                visible: isMac

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (windowRef) windowRef.showMinimized()
                }
            }

            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: "#28C840"
                border.color: "#1EAE33"
                visible: isMac

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (windowRef && windowRef.toggleMaximize) windowRef.toggleMaximize()
                }
            }

            Rectangle {
                width: 28
                height: 22
                radius: 3
                color: minMouseArea.containsMouse ? Theme.surfaceHighlight : "transparent"
                visible: !isMac

                Text {
                    anchors.centerIn: parent
                    text: "—"
                    color: Theme.textPrimary
                    font.pixelSize: 12
                }

                MouseArea {
                    id: minMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (windowRef) windowRef.showMinimized()
                }
            }

            Rectangle {
                width: 28
                height: 22
                radius: 3
                color: maxMouseArea.containsMouse ? Theme.surfaceHighlight : "transparent"
                visible: !isMac

                Text {
                    anchors.centerIn: parent
                    text: windowRef && windowRef.visibility === Window.Maximized ? "❐" : "□"
                    color: Theme.textPrimary
                    font.pixelSize: 11
                }

                MouseArea {
                    id: maxMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (windowRef && windowRef.toggleMaximize) windowRef.toggleMaximize()
                }
            }

            Rectangle {
                width: 28
                height: 22
                radius: 3
                color: closeMouseArea.containsMouse ? Theme.surfaceHighlight : "transparent"
                visible: !isMac

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Theme.textPrimary
                    font.pixelSize: 14
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (windowRef) windowRef.close()
                }
            }
        }
        
        Rectangle {
            Layout.preferredHeight: 26
            Layout.fillWidth: false
            implicitWidth: triggerRow.implicitWidth + 16
            radius: 4
            color: triggerMouse.containsMouse ? Theme.surfaceHighlight : "transparent"
            
            MouseArea {
                id: triggerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: connectionModal.open()
            }
            
            RowLayout {
                id: triggerRow
                anchors.centerIn: parent
                spacing: 8
                
                // Avatar
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    color: App.activeConnectionId !== -1 ? connectionModal.getAvatarColor(activeConnectionName) : "transparent"
                    visible: App.activeConnectionId !== -1
                    
                    Text {
                        anchors.centerIn: parent
                        text: activeConnectionName.length > 0 ? activeConnectionName.charAt(0).toUpperCase() : ""
                        color: connectionModal.getAvatarTextColor(connectionModal.getAvatarColor(activeConnectionName))
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
                
                Text {
                    text: activeConnectionName
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: 13
                }
                
                Text {
                    text: "⌄"
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    Layout.topMargin: -2
                }
            }
        }
        
        AppButton {
            text: "✎"
            Layout.preferredHeight: 22
            Layout.preferredWidth: 22
            visible: App.activeConnectionId !== -1
            onClicked: root.requestEditConnection(App.activeConnectionId)
            ToolTip.visible: hovered
            ToolTip.text: "Edit Connection"
        }

        AppButton {
            text: "✖"
            Layout.preferredHeight: 22
            Layout.preferredWidth: 22
            visible: App.activeConnectionId !== -1
            onClicked: root.requestDeleteConnection(App.activeConnectionId)
            ToolTip.visible: hovered
            ToolTip.text: "Delete Connection"
        }
        
        // Error Message Display
        Text {
            text: App.lastError
            color: Theme.error
            visible: App.lastError.length > 0
            font.pixelSize: 11
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        
        Item { Layout.fillWidth: true } // Spacer
    }
}
