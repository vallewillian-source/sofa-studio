import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: control
    property var tabsModel: null // ListModel
    property alias currentIndex: tabBar.currentIndex
    property alias count: tabBar.count
    signal requestCloseTab(int index)
    signal requestCloseAllTabs()
    signal newQueryClicked()
    readonly property var avatarColors: Theme.connectionAvatarColors
    property string activeConnectionName: {
        var currentId = App.activeConnectionId
        if (currentId === -1) {
            return ""
        }
        
        var conns = App.connections
        for (var i = 0; i < conns.length; i++) {
            if (conns[i].id === currentId) {
                return conns[i].name
            }
        }
        return ""
    }
    property string activeConnectionColor: {
        var currentId = App.activeConnectionId
        if (currentId === -1) {
            return ""
        }
        
        var conns = App.connections
        for (var i = 0; i < conns.length; i++) {
            if (conns[i].id === currentId) {
                return conns[i].color || ""
            }
        }
        return ""
    }
    readonly property color tabAccentColor: App.activeConnectionId === -1 ? Theme.accent : getAvatarColor(activeConnectionName, activeConnectionColor)

    function getAvatarColor(name, colorValue) {
        if (colorValue && colorValue.length > 0) return colorValue
        if (!name) return avatarColors[0]
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        var index = Math.abs(hash % avatarColors.length)
        return avatarColors[index]
    }
    
    implicitHeight: Theme.tabBarHeight
    color: Theme.background
    border.color: Theme.border
    border.width: 1

    // Border only bottom
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.border
        anchors.bottom: parent.bottom
        z: 2
    }

    AppMenu {
        id: contextMenu
        property int targetIndex: -1
        
        Controls.MenuItem {
            text: "Close Tab"
            visible: contextMenu.targetIndex !== -1 && control.tabsModel && control.tabsModel.get(contextMenu.targetIndex).type !== "home"
            height: visible ? implicitHeight : 0
            onTriggered: control.requestCloseTab(contextMenu.targetIndex)
        }

        Controls.MenuItem {
            text: "Close All Tabs"
            onTriggered: control.requestCloseAllTabs()
        }

        Controls.MenuItem {
            text: "Close Others"
            onTriggered: console.log("Close others")
        }

        Controls.MenuItem {
            text: "Close To the Right"
            onTriggered: console.log("Close to the right")
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.targetIndex = -1
                contextMenu.popup()
            }
        }
        z: 0
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Controls.TabBar {
            id: tabBar
            Layout.preferredWidth: contentWidth
            Layout.fillHeight: true
            background: null // Transparent
            
            Repeater {
                model: control.tabsModel
                
                Controls.TabButton {
                    id: tabBtn
                    width: implicitWidth + 20
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.ArrowCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                contextMenu.targetIndex = index
                                contextMenu.popup()
                            }
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8
                        
                        Item {
                            Layout.preferredWidth: model.type === "table" ? 14 : 0
                            Layout.preferredHeight: model.type === "table" ? 14 : 0
                            visible: model.type === "table"

                            Image {
                                id: tableTabIcon
                                anchors.fill: parent
                                source: model.type === "table" ? "assets/table-list-solid-full.svg" : ""
                                sourceSize.width: 14
                                sourceSize.height: 14
                                visible: false
                                opacity: 1
                            }

                            ColorOverlay {
                                anchors.fill: tableTabIcon
                                source: tableTabIcon
                                visible: model.type === "table"
                                color: "#FFFFFF"
                                opacity: 0.7
                            }
                        }

                        Item {
                            Layout.preferredWidth: model.type === "sql" ? 14 : 0
                            Layout.preferredHeight: model.type === "sql" ? 14 : 0
                            visible: model.type === "sql"

                            Image {
                                id: sqlTabIcon
                                anchors.fill: parent
                                source: model.type === "sql" ? "assets/database-solid-full.svg" : ""
                                sourceSize.width: 14
                                sourceSize.height: 14
                                visible: false
                                opacity: 1
                            }

                            ColorOverlay {
                                anchors.fill: sqlTabIcon
                                source: sqlTabIcon
                                visible: model.type === "sql"
                                color: "#FFFFFF"
                                opacity: 0.7
                            }
                        }

                        Item {
                            Layout.preferredWidth: model.type === "connection_form" ? 14 : 0
                            Layout.preferredHeight: model.type === "connection_form" ? 14 : 0
                            visible: model.type === "connection_form"

                            Image {
                                id: connectionTabIcon
                                anchors.fill: parent
                                source: model.type === "connection_form" ? "assets/plug-solid-full.svg" : ""
                                sourceSize.width: 14
                                sourceSize.height: 14
                                visible: false
                                opacity: 1
                            }

                            ColorOverlay {
                                anchors.fill: connectionTabIcon
                                source: connectionTabIcon
                                visible: model.type === "connection_form"
                                color: "#FFFFFF"
                                opacity: 0.7
                            }
                        }

                        Text {
                            text: model.title
                            font: tabBtn.font
                            opacity: tabBtn.enabled ? 1.0 : 0.3
                            color: tabBtn.checked ? Theme.textPrimary : Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            Layout.maximumWidth: 200
                        }
                        
                        // Close Button
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 2
                            color: closeMouseArea.containsMouse ? Theme.surfaceHighlight : "transparent"
                            visible: model.type !== "home" // Home tab cannot be closed
                            
                            Text {
                                anchors.centerIn: parent
                                text: "×" // Multiplication sign looks better than X
                                color: tabBtn.checked ? Theme.textPrimary : Theme.textSecondary
                                font.pixelSize: 14
                            }
                            
                            MouseArea {
                                id: closeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    control.requestCloseTab(index)
                                }
                            }
                        }
                    }

                    background: Rectangle {
                        implicitHeight: Theme.tabBarHeight
                        color: tabBtn.checked ? Theme.background : "transparent"
                        
                        // Active Tab Indicator (Top Line)
                        Rectangle {
                            width: parent.width
                            height: 2
                            color: tabAccentColor
                            anchors.top: parent.top
                            visible: tabBtn.checked
                        }
                        
                        // Right separator for all tabs
                        Rectangle {
                            width: 1
                            height: parent.height - 12
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.border
                            opacity: 0.5
                            visible: !tabBtn.checked // Hide separator on active tab? Or keep it.
                        }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            width: 1
            height: parent.height
            color: Theme.border
            Layout.fillHeight: true
            visible: App.activeConnectionId !== -1
        }

        // New Query Button (+)
        Controls.Button {
            id: newTabBtn
            Layout.preferredWidth: 38
            Layout.fillHeight: true
            flat: true
            visible: App.activeConnectionId !== -1
            
            contentItem: Text {
                text: "+"
                font.pixelSize: 20
                color: newTabBtn.hovered ? "#FFFFFF" : Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Item {
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    anchors.centerIn: parent
                    color: newTabBtn.down ? Theme.surfaceHighlight : (newTabBtn.hovered ? Theme.surfaceHighlight : "transparent")
                }
            }
            
            onClicked: control.newQueryClicked()
            
            Controls.ToolTip {
                id: btnToolTip
                visible: newTabBtn.hovered
                text: "New SQL Console"
                delay: 500
                timeout: 5000
                
                contentItem: Text {
                    text: btnToolTip.text
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
        }

        // Spacer to push everything to the left
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
