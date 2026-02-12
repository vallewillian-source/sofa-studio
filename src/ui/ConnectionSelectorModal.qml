import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import sofa.ui

Popup {
    id: root
    width: 500
    readonly property real searchAreaHeight: 40
    readonly property real dividerHeight: 1
    readonly property real listAreaHeight: Math.min(connectionsList.contentHeight, 400)
    height: Math.min(searchAreaHeight + dividerHeight + listAreaHeight, 500)
    x: (parent.width - width) / 2
    y: 40
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    signal connectionSelected(int connectionId)
    signal newConnectionRequested()
    signal editConnectionRequested(int connectionId)
    signal deleteConnectionRequested(int connectionId)

    // Background
    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: 6
    }

    // Avatar Colors
    readonly property var avatarColors: Theme.connectionAvatarColors
    readonly property int avatarSize: 32
    readonly property int avatarRadius: Math.round(avatarSize * 0.28)

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

    function colorToRgb(colorValue) {
        if (typeof colorValue === "string") {
            var hex = colorValue.replace("#", "")
            if (hex.length === 3) {
                hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
            }
            if (hex.length !== 6) return { "r": 0, "g": 0, "b": 0 }
            return {
                "r": parseInt(hex.slice(0, 2), 16) / 255,
                "g": parseInt(hex.slice(2, 4), 16) / 255,
                "b": parseInt(hex.slice(4, 6), 16) / 255
            }
        }
        if (colorValue && colorValue.r !== undefined) {
            return { "r": colorValue.r, "g": colorValue.g, "b": colorValue.b }
        }
        return { "r": 0, "g": 0, "b": 0 }
    }

    function relativeLuminance(colorValue) {
        var rgb = colorToRgb(colorValue)
        var toLinear = function(value) {
            return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        }
        var r = toLinear(rgb.r)
        var g = toLinear(rgb.g)
        var b = toLinear(rgb.b)
        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }

    function isColorDark(colorValue) {
        return relativeLuminance(colorValue) < 0.5
    }

    function getAvatarTextColor(colorValue) {
        return "#000000"
    }

    // Model Logic
    ListModel {
        id: connectionsModel
    }

    function syncModel(filterText) {
        connectionsModel.clear()
        var filter = (filterText || "").toLowerCase()
        
        // Helper to check match
        var matches = function(text) {
            if (!filter) return true
            return text && text.toLowerCase().indexOf(filter) !== -1
        }
        
        // 1. Action: Connect new database
        var newActionName = "Connect a new database"
        var newActionDesc = "Configure a new connection"
        if (matches(newActionName) || matches(newActionDesc)) {
            connectionsModel.append({
                "id": -999,
                "name": newActionName,
                "type": "action",
                "dbType": "",
                "icon": "+",
                "color": ""
            })
        }

        // 2. Connections
        var conns = App.connections
        for (var i = 0; i < conns.length; i++) {
            var item = conns[i]
            var dbType = "PostgreSQL" // Fixed for now as requested
            
            if (matches(item.name) || matches(dbType)) {
                connectionsModel.append({
                    "id": item.id,
                    "name": item.name,
                    "type": "connection",
                    "dbType": dbType,
                    "icon": "",
                    "color": item.color
                })
            }
        }
        
        // 3. Action: Close Connection (if active)
        if (App.activeConnectionId !== -1) {
            var closeActionName = "Close Connection"
            var closeActionDesc = "Disconnect from current database"
            if (matches(closeActionName) || matches(closeActionDesc)) {
                connectionsModel.append({
                    "id": -1,
                    "name": closeActionName,
                    "type": "action",
                    "dbType": "",
                    "icon": "×",
                    "color": ""
                })
            }
        }
        
        // Reset index based on filter
        if (connectionsList.count > 0) {
             // Only select first item if filtering, otherwise no selection initially
             if (filterText.length > 0) {
                 connectionsList.currentIndex = 0
             } else {
                 connectionsList.currentIndex = -1
             }
        }
    }

    onOpened: {
        syncModel("")
        filterInput.text = ""
        filterInput.forceActiveFocus()
        // No initial selection
        connectionsList.currentIndex = -1
    }

    ColumnLayout {
        id: mainLayout
        width: parent.width
        spacing: 0

        // Search Input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "transparent"
            
            TextField {
                id: filterInput
                anchors.fill: parent
                anchors.margins: 6
                placeholderText: "Select a connection..."
                color: Theme.textPrimary
                font.pixelSize: 14
                background: Rectangle {
                    color: Theme.background
                    border.color: Theme.border
                    radius: 4
                }
                
                onTextChanged: {
                    root.syncModel(text)
                }
                
                // Keyboard navigation for list
                Keys.onDownPressed: connectionsList.incrementCurrentIndex()
                Keys.onUpPressed: connectionsList.decrementCurrentIndex()
                Keys.onEnterPressed: root.selectCurrent()
                Keys.onReturnPressed: root.selectCurrent()
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.border
        }

        ListView {
            id: connectionsList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 400)
            model: connectionsModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            
            delegate: Rectangle {
                id: delegateRoot
                width: connectionsList.width
                height: 54
                color: {
                    if (ListView.isCurrentItem) return Theme.surfaceHighlight // Subtle selection
                    if (hoverHandler.hovered) return Theme.surfaceHighlight // Hover
                    return "transparent"
                }

                HoverHandler {
                    id: hoverHandler
                }
                
                MouseArea {
                    z: 0
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        connectionsList.currentIndex = index
                        root.selectCurrent()
                    }
                }

                RowLayout {
                    z: 1
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Avatar
                    Rectangle {
                        Layout.preferredWidth: root.avatarSize
                        Layout.preferredHeight: root.avatarSize
                        radius: root.avatarRadius
                        color: model.type === "action" ? Theme.surfaceHighlight : root.getAvatarColor(model.name, model.color)
                        border.color: Theme.border
                        border.width: model.type === "action" ? 1 : 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: model.type === "action" ? model.icon : (model.name ? model.name.charAt(0).toUpperCase() : "?")
                            color: model.type === "action" ? Theme.textPrimary : root.getAvatarTextColor(root.getAvatarColor(model.name, model.color))
                            font.bold: true
                            font.pixelSize: 16
                        }
                    }

                    // Content
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        
                        Text {
                            text: model.name
                            color: Theme.textPrimary
                            font.bold: true
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        
                        Text {
                            text: model.type === "action" && model.id === -999 ? "Configure a new connection" : 
                                  model.type === "action" && model.id === -1 ? "Disconnect from current database" :
                                  model.dbType
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                    
                    // Active Indicator
                    Text {
                        text: "✓"
                        color: Theme.textPrimary
                        font.bold: true
                        visible: model.id === App.activeConnectionId
                    }

                    RowLayout {
                        visible: model.type === "connection"
                        spacing: 2

                        Controls.Button {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 22
                            padding: 0
                            onClicked: {
                                root.editConnectionRequested(model.id)
                                root.close()
                            }

                            background: Rectangle {
                                radius: 4
                                color: parent.hovered ? Theme.surfaceHighlight : "transparent"
                            }

                            contentItem: Text {
                                text: "✎"
                                color: parent.hovered ? Theme.textPrimary : Theme.textSecondary
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            Controls.ToolTip {
                                visible: parent.hovered
                                text: "Edit Connection"
                                delay: 500

                                contentItem: Text {
                                    text: "Edit Connection"
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

                        Controls.Button {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: 22
                            padding: 0
                            onClicked: {
                                root.deleteConnectionRequested(model.id)
                                root.close()
                            }

                            background: Rectangle {
                                radius: 4
                                color: parent.hovered ? Theme.surfaceHighlight : "transparent"
                            }

                            contentItem: Text {
                                text: "✕"
                                color: parent.hovered ? Theme.error : Theme.textSecondary
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            Controls.ToolTip {
                                visible: parent.hovered
                                text: "Delete Connection"
                                delay: 500

                                contentItem: Text {
                                    text: "Delete Connection"
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
                    }
                }
            }
        }
    }
    
    function selectCurrent() {
        var item = connectionsModel.get(connectionsList.currentIndex)
        if (item) {
            if (item.id === -999) {
                root.newConnectionRequested()
            } else if (item.id === -1) {
                App.closeConnection()
            } else {
                root.connectionSelected(item.id)
            }
            root.close()
        }
    }
}
