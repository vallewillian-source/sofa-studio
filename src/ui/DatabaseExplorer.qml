import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    color: Theme.surface
    
    property int currentConnectionId: -1
    signal tableClicked(string schema, string table)
    signal newQueryClicked()
    signal requestNewConnection()
    
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
    
    readonly property color connectionAccentColor: App.activeConnectionId === -1 ? Theme.accent : getAvatarColor(activeConnectionName, activeConnectionColor)

    component ExplorerRow : Rectangle {
        id: row
        property string label
        property string icon
        property bool isExpanded: false
        property bool isExpandable: false
        property int level: 0
        property bool isSelected: false
        property color iconColor: Theme.accent
        property real iconOpacity: 1.0
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

            Item {
                id: iconRoot
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                visible: icon !== ""
                property bool isSvg: icon.indexOf(".svg") !== -1
                
                Text {
                    anchors.centerIn: parent
                    visible: !iconRoot.isSvg
                    text: icon
                    color: row.iconColor
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    opacity: row.iconOpacity
                }
                
                Item {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    visible: iconRoot.isSvg
                    
                    Image {
                        id: svgIcon
                        anchors.fill: parent
                        source: iconRoot.isSvg ? icon : ""
                        sourceSize.width: 14
                        sourceSize.height: 14
                        visible: false
                        opacity: 1
                    }

                    ColorOverlay {
                        anchors.fill: svgIcon
                        source: svgIcon
                        visible: iconRoot.isSvg
                        color: row.iconColor
                        opacity: row.iconOpacity
                    }
                }
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
                    icon: schemaDelegate.isGroup ? "assets/eye-slash-solid-full.svg" : "assets/folder-tree-solid-full.svg" 
                    iconColor: schemaDelegate.isGroup ? "#FFF9E6" : root.connectionAccentColor
                    iconOpacity: schemaDelegate.isGroup ? 0.7 : 1.0
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
                        icon: "assets/table-list-solid-full.svg"
                        iconColor: "#FFFFFF"
                        iconOpacity: 0.7
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
                                icon: "assets/folder-tree-solid-full.svg"
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
                                    icon: "assets/table-list-solid-full.svg"
                                    iconColor: "#FFFFFF"
                                    iconOpacity: 0.7
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
                width: parent.width - 40 // More padding
                spacing: 20 // More breathing room

                // Icon
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 48
                    height: 48
                    
                    Image {
                        id: emptyIcon
                        anchors.fill: parent
                        source: "assets/database-solid-full.svg"
                        sourceSize: Qt.size(48, 48)
                        visible: false
                        fillMode: Image.PreserveAspectFit
                    }
                    
                    ColorOverlay {
                        anchors.fill: emptyIcon
                        source: emptyIcon
                        color: Theme.textSecondary
                        opacity: 0.2 // Very subtle
                    }
                }

                // Text
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Text {
                        text: "No Open Connection"
                        color: Theme.textPrimary
                        font.pixelSize: 15 // Slightly larger
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Connect to a database to browse schemas, tables, and views."
                        color: Theme.textSecondary
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                    }
                }
                
                Item { Layout.preferredHeight: 4 }
                
                AppButton {
                    text: "Connect"
                    isPrimary: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 140
                    onClicked: root.requestNewConnection()
                }
            }
        }
    }
    
    ListModel { id: schemaModel }
    ListModel { id: hiddenSchemaModel }
}
