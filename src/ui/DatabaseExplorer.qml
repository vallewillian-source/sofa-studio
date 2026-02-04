import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: Theme.surface
    
    property int currentConnectionId: -1
    signal tableClicked(string tableName)
    
    function refresh() {
        schemaModel.clear()
        var list = App.getSchemas()
        for (var i = 0; i < list.length; i++) {
            schemaModel.append({
                "name": list[i],
                "expanded": false,
                "tables": []
            })
        }
        
        // Auto-expand "public" schema if present
        for (var i = 0; i < schemaModel.count; i++) {
            if (schemaModel.get(i).name === "public") {
                toggleSchema(i)
                break
            }
        }
    }
    
    function toggleSchema(index) {
        var item = schemaModel.get(index)
        if (item.expanded) {
            item.expanded = false
        } else {
            // Fetch tables
            var tables = App.getTables(item.name)
            var tableList = []
            for (var i = 0; i < tables.length; i++) {
                tableList.push({"name": tables[i]})
            }
            item.tables = tableList
            item.expanded = true
        }
    }
    
    Connections {
        target: App
        function onConnectionOpened(id) {
            currentConnectionId = id
            refresh()
        }
        function onConnectionClosed() {
            currentConnectionId = -1
            schemaModel.clear()
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
                text: "EXPLORER"
                font.bold: true
                font.pixelSize: 11
                color: Theme.textSecondary
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        
        // Tree View
        ListView {
            id: treeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: schemaModel
            
            delegate: Column {
                width: ListView.view.width
                property bool isExpanded: model.expanded
                property var tableList: model.tables
                
                // Schema Item
                Rectangle {
                    width: parent.width
                    height: 28
                    color: schemaMouse.containsMouse ? Theme.surfaceHighlight : "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingMedium
                        spacing: 8
                        
                        Text {
                            text: isExpanded ? "▼" : "▶"
                            color: Theme.textSecondary
                            font.pixelSize: 10
                        }
                        
                        Text {
                            text: model.name
                            color: Theme.textPrimary
                            font.pixelSize: 13
                        }
                    }
                    
                    MouseArea {
                        id: schemaMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSchema(index)
                    }
                }
                
                // Tables List
                Repeater {
                    model: isExpanded ? tableList : null
                    delegate: Rectangle {
                        width: parent.width
                        height: 28
                        color: tableMouse.containsMouse ? Theme.surfaceHighlight : "transparent"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingMedium * 2 + 10
                            spacing: 8
                            
                            Text {
                                text: "▦" // Table icon
                                color: Theme.primary
                                font.pixelSize: 12
                            }
                            
                            Text {
                                text: modelData.name
                                color: Theme.textPrimary
                                font.pixelSize: 13
                            }
                        }
                        
                        MouseArea {
                            id: tableMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.tableClicked(modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }
    
    ListModel {
        id: schemaModel
    }
}
