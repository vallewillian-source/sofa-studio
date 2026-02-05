import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: Theme.surface
    
    property int currentConnectionId: -1
    signal tableClicked(string schema, string table)
    signal newQueryClicked()
    
    function appendSchema(targetModel, schemaName) {
        targetModel.append({
            "type": "schema",
            "name": schemaName,
            "expanded": false,
            "tables": []
        })
    }

    function refresh() {
        schemaModel.clear()
        hiddenSchemaModel.clear()
        var list = App.getSchemas()
        for (var i = 0; i < list.length; i++) {
            appendSchema(schemaModel, list[i])
        }
        
        var hiddenList = App.getHiddenSchemas()
        if (hiddenList.length > 0) {
            for (var j = 0; j < hiddenList.length; j++) {
                appendSchema(hiddenSchemaModel, hiddenList[j])
            }
            schemaModel.append({
                "type": "group",
                "name": "hiddens",
                "expanded": false
            })
        }
        
        // Auto-expand "public" schema if present
        for (var i = 0; i < schemaModel.count; i++) {
            var item = schemaModel.get(i)
            if (item.type === "schema" && item.name === "public") {
                toggleSchemaAt(schemaModel, i)
                break
            }
        }
    }
    
    function toggleSchemaAt(model, index) {
        var item = model.get(index)
        if (item.expanded) {
            item.expanded = false
        } else {
            // Fetch tables
            var tables = App.getTables(item.name)
            var rows = []
            for (var i = 0; i < tables.length; i++) {
                rows.push({"name": tables[i]})
            }
            item.tables = rows
            item.expanded = true
        }
    }

    function toggleGroupAt(index) {
        var item = schemaModel.get(index)
        if (item) {
            item.expanded = !item.expanded
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

    Component.onCompleted: {
        if (App.activeConnectionId !== -1) {
            currentConnectionId = App.activeConnectionId
            refresh()
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
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium
                
                Text {
                    text: "EXPLORER"
                    font.bold: true
                    font.pixelSize: 11
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }
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
                id: schemaDelegate
                property string schemaName: model.name
                property bool isGroup: model.type === "group"
                width: ListView.view.width
                property bool isExpanded: model.expanded
                property var tableList: model.tables
                
                // Schema Item
                Rectangle {
                    width: parent.width
                    height: 28
                    color: schemaMouse.containsMouse ? Theme.surfaceHighlight : "transparent"
                    visible: !schemaDelegate.isGroup
                    
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
                        onClicked: root.toggleSchemaAt(schemaModel, index)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 28
                    color: groupMouse.containsMouse ? Theme.surfaceHighlight : "transparent"
                    visible: schemaDelegate.isGroup
                    
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
                        id: groupMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGroupAt(index)
                    }
                }
                
                // Tables List
                Repeater {
                    model: (!schemaDelegate.isGroup && isExpanded) ? tableList : null
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
                                color: Theme.accent
                                font.pixelSize: 12
                            }
                            
                            Text {
                                text: name
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
                                console.log("\u001b[35m🗂️ Abrindo tabela\u001b[0m", schemaDelegate.schemaName + "." + name)
                                root.tableClicked(schemaDelegate.schemaName, name)
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    visible: schemaDelegate.isGroup && isExpanded
                    
                    Repeater {
                        model: hiddenSchemaModel
                        delegate: Column {
                            id: hiddenSchemaDelegate
                            property string schemaName: name
                            width: parent.width
                            property bool isExpanded: expanded
                            property var tableList: tables
                            
                            Rectangle {
                                width: parent.width
                                height: 28
                                color: hiddenSchemaMouse.containsMouse ? Theme.surfaceHighlight : "transparent"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingMedium * 2
                                    spacing: 8
                                    
                                    Text {
                                        text: isExpanded ? "▼" : "▶"
                                        color: Theme.textSecondary
                                        font.pixelSize: 10
                                    }
                                    
                                    Text {
                                        text: name
                                        color: Theme.textPrimary
                                        font.pixelSize: 13
                                    }
                                }
                                
                                MouseArea {
                                    id: hiddenSchemaMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSchemaAt(hiddenSchemaModel, index)
                                }
                            }
                            
                            Repeater {
                                model: isExpanded ? tableList : null
                                delegate: Rectangle {
                                    width: parent.width
                                    height: 28
                                    color: hiddenTableMouse.containsMouse ? Theme.surfaceHighlight : "transparent"
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingMedium * 3 + 10
                                        spacing: 8
                                        
                                        Text {
                                            text: "▦"
                                            color: Theme.accent
                                            font.pixelSize: 12
                                        }
                                        
                                        Text {
                                            text: name
                                            color: Theme.textPrimary
                                            font.pixelSize: 13
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: hiddenTableMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            console.log("\u001b[35m🗂️ Abrindo tabela\u001b[0m", hiddenSchemaDelegate.schemaName + "." + name)
                                            root.tableClicked(hiddenSchemaDelegate.schemaName, name)
                                        }
                                    }
                                }
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

    ListModel {
        id: hiddenSchemaModel
    }
}
