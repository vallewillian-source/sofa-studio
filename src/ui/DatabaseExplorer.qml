import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: Theme.surface
    
    property int currentConnectionId: -1
    signal tableClicked(string schema, string table)
    signal newQueryClicked()
    
    // --- Logic ---

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
        
        // Safety check
        if (currentConnectionId === -1) return

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
                "name": "Hidden Schemas",
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

    // --- Components ---

    component ExplorerRow : Rectangle {
        id: row
        property string label
        property string icon
        property bool isExpanded: false
        property bool isExpandable: false
        property int level: 0
        property bool isSelected: false
        property color iconColor: Theme.accent
        property bool isDimmed: false
        signal clicked()

        width: treeView.width
        height: 24 
        color: mouse.containsMouse ? Theme.surfaceHighlight : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: (level * 12) + 8 
            spacing: 6

            // Arrow / Spacer
            Item {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                visible: true
                
                Text {
                    anchors.centerIn: parent
                    visible: isExpandable
                    text: isExpanded ? "⌄" : "›"
                    color: Theme.textSecondary
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            // Icon
            Text {
                visible: icon !== ""
                text: icon
                color: row.iconColor
                font.pixelSize: 12
                Layout.preferredWidth: 16
                horizontalAlignment: Text.AlignHCenter
                opacity: row.isDimmed ? 0.7 : 1.0
            }

            // Label
            Text {
                text: label
                color: row.isDimmed ? Theme.textSecondary : Theme.textPrimary
                font.pixelSize: 13
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }

    // --- Layout ---
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            color: "transparent" // VS Code explorer headers are usually transparent or same as bg
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium
                
                Text {
                    text: "EXPLORER"
                    font.bold: true
                    font.pixelSize: 11
                    font.letterSpacing: 0.5
                    color: Theme.textSecondary
                    Layout.fillWidth: true
                }

                // Header Actions
                Text {
                    text: "↺"
                    font.pixelSize: 14
                    color: headerMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    Layout.alignment: Qt.AlignRight
                    
                    MouseArea {
                        id: headerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }
            }
        }
        
        // Content
        ListView {
            id: treeView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentConnectionId !== -1
            clip: true
            model: schemaModel
            boundsBehavior: Flickable.StopAtBounds
            
            delegate: Column {
                id: schemaDelegate
                property string schemaName: model.name
                property bool isGroup: model.type === "group"
                property bool isExpanded: model.expanded
                property var tableList: model.tables
                width: ListView.view.width
                
                // 1. Schema / Group Row
                ExplorerRow {
                    label: schemaDelegate.isGroup ? "Hidden Schemas" : model.name
                    icon: schemaDelegate.isGroup ? "👁" : "📦" 
                    iconColor: schemaDelegate.isGroup ? Theme.textSecondary : Theme.accent
                    isExpandable: true
                    isExpanded: schemaDelegate.isExpanded
                    level: 0
                    isDimmed: schemaDelegate.isGroup
                    onClicked: {
                        if (schemaDelegate.isGroup) root.toggleGroupAt(index)
                        else root.toggleSchemaAt(schemaModel, index)
                    }
                }
                
                // 2. Tables (for regular Schema)
                Repeater {
                    model: (!schemaDelegate.isGroup && isExpanded) ? tableList : null
                    delegate: ExplorerRow {
                        label: name
                        icon: "▦"
                        iconColor: Theme.textPrimary // Neutral color for tables
                        level: 1
                        onClicked: {
                            console.log("\u001b[35m🗂️ Abrindo tabela\u001b[0m", schemaDelegate.schemaName + "." + name)
                            root.tableClicked(schemaDelegate.schemaName, name)
                        }
                    }
                }

                // 3. Hidden Schemas (for Group)
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
                            
                            // Hidden Schema Row
                            ExplorerRow {
                                label: name
                                icon: "📦"
                                iconColor: Theme.textSecondary
                                isExpandable: true
                                isExpanded: hiddenSchemaDelegate.isExpanded
                                level: 1
                                isDimmed: true
                                onClicked: root.toggleSchemaAt(hiddenSchemaModel, index)
                            }
                            
                            // Tables in Hidden Schema
                            Repeater {
                                model: isExpanded ? tableList : null
                                delegate: ExplorerRow {
                                    label: name
                                    icon: "▦"
                                    iconColor: Theme.textSecondary
                                    level: 2
                                    isDimmed: true
                                    onClicked: {
                                        console.log("\u001b[35m🗂️ Abrindo tabela oculta\u001b[0m", hiddenSchemaDelegate.schemaName + "." + name)
                                        root.tableClicked(hiddenSchemaDelegate.schemaName, name)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Empty State
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentConnectionId === -1

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 12

                Text {
                    text: "No Connection"
                    color: Theme.textPrimary
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Select or create a connection to start exploring."
                    color: Theme.textSecondary
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                
                Item { Layout.preferredHeight: 10 }
                
                AppButton {
                    text: "New Connection"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: root.newQueryClicked() // Reusing signal or we can emit a new one
                }
            }
        }
    }
    
    ListModel { id: schemaModel }
    ListModel { id: hiddenSchemaModel }
}
