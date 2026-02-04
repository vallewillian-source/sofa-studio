import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui
import sofa.datagrid 1.0

ApplicationWindow {
    width: 1024
    height: 768
    visible: true
    title: qsTr("Sofa Studio")
    color: Theme.background
    
    ListModel {
        id: tabModel
        ListElement { 
            title: "Home"
            type: "home"
            schema: ""
            tableName: ""
        }
    }
    
    function openTable(schema, tableName) {
        var title = "Table: " + schema + "." + tableName
        console.log("\u001b[36m📌 Abrindo aba\u001b[0m", title)
        // Check if already open
        for (var i = 0; i < tabModel.count; i++) {
            if (tabModel.get(i).title === title) {
                appTabs.currentIndex = i
                return
            }
        }
        tabModel.append({ "title": title, "type": "table", "schema": schema, "tableName": tableName })
        appTabs.currentIndex = tabModel.count - 1
    }

    function openSqlConsole() {
        tabModel.append({ "title": "SQL Console", "type": "sql" })
        appTabs.currentIndex = tabModel.count - 1
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left Sidebar
        AppSidebar {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.sidebarWidth
        }

        // Database Explorer
        DatabaseExplorer {
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            visible: App.activeConnectionId !== -1
            onTableClicked: function(schema, tableName) {
                openTable(schema, tableName)
            }
            onNewQueryClicked: openSqlConsole()
        }

        // Main Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Top Tabs
            AppTabs {
                id: appTabs
                Layout.fillWidth: true
                tabsModel: tabModel
            }
            
            // Content Area
            StackLayout {
                currentIndex: appTabs.currentIndex
                Layout.fillWidth: true
                Layout.fillHeight: true
                onCurrentIndexChanged: console.log("\u001b[35m🥞 StackLayout\u001b[0m", "index=" + currentIndex)
                
                Repeater {
                    model: tabModel
                    
                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        property string itemType: model.type || "home"
                        property string itemSchema: model.schema || "public"
                        property string itemTable: model.tableName || ""
                        
                        sourceComponent: itemType === "home" ? homeComponent : (itemType === "table" ? tableComponent : sqlComponent)
                        
                        onLoaded: {
                            console.log("\u001b[36m🧭 Loader\u001b[0m", "index=" + index, "type=" + itemType, "schema=" + itemSchema, "table=" + itemTable)
                            if (item && itemType === "table") {
                                item.schema = itemSchema
                                item.tableName = itemTable
                                item.loadData()
                            }
                        }
                        
                        onItemTypeChanged: console.log("Loader type changed:", index, itemType)
                    }
                }
            }
        }
    }
    
    Component {
        id: sqlComponent
        SqlConsole {
            
        }
    }

    Component {
        id: homeComponent
        Rectangle {
            color: Theme.background
            Column {
                anchors.centerIn: parent
                spacing: 20
                Text {
                    text: qsTr("Boot OK")
                    font.pixelSize: 24
                    color: Theme.textPrimary
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                AppButton {
                    text: "Test Command"
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: {
                        App.executeCommand("test.hello")
                    }
                }
            }
        }
    }
    
    Component {
        id: tableComponent
        Rectangle {
            id: tableRoot
            property string schema: "public"
            property string tableName: ""
            property string errorMessage: ""
            
            // View State
            property var views: []
            property int currentViewId: -1
            property var currentViewData: null
            property var rawColumns: [] // Store raw columns for ViewEditor
            
            color: Theme.background
            
            DataGridEngine {
                id: gridEngine
            }
            
            // Toolbar
            Rectangle {
                id: toolbar
                height: 40
                width: parent.width
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                z: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    
                    Label { text: "View:" }
                    
                    ComboBox {
                        id: viewSelector
                        Layout.preferredWidth: 150
                        textRole: "name"
                        valueRole: "id"
                        model: ListModel { id: viewModel }
                        
                        onActivated: (index) => {
                            var viewId = viewModel.get(index).id
                            tableRoot.applyView(viewId)
                        }
                    }
                    
                    AppButton {
                        text: "New View"
                        onClicked: viewEditor.openEditor(tableRoot.rawColumns, null)
                    }
                    
                    AppButton {
                        text: "Edit"
                        enabled: tableRoot.currentViewId !== -1
                        onClicked: viewEditor.openEditor(tableRoot.rawColumns, tableRoot.currentViewData)
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    AppButton {
                        text: "Refresh"
                        onClicked: tableRoot.loadData()
                    }
                }
            }

            DataGrid {
                anchors.top: toolbar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                engine: gridEngine
            }
            
            ViewEditor {
                id: viewEditor
                anchors.centerIn: parent
                onViewSaved: (data) => {
                    data.sourceRef = tableRoot.schema + "." + tableRoot.tableName
                    var newId = App.saveView(data)
                    if (newId !== -1) {
                        tableRoot.loadViews()
                        tableRoot.applyView(newId)
                    }
                }
                
                function openEditor(cols, view) {
                    load(cols, view)
                    open()
                }
            }

            Text {
                visible: tableRoot.errorMessage.length > 0
                text: tableRoot.errorMessage
                color: Theme.error
                font.pixelSize: 14
                anchors.centerIn: parent
            }

            function loadViews() {
                var list = App.getViews(schema, tableName)
                viewModel.clear()
                viewModel.append({ "id": -1, "name": "Default", "definition": "" })
                
                for (var i = 0; i < list.length; i++) {
                    viewModel.append(list[i])
                }
                
                // Restore selection
                for (var j = 0; j < viewModel.count; j++) {
                    if (viewModel.get(j).id === currentViewId) {
                        viewSelector.currentIndex = j
                        return
                    }
                }
                viewSelector.currentIndex = 0
            }
            
            function applyView(viewId) {
                currentViewId = viewId
                currentViewData = null
                
                var viewDef = null
                for (var i = 0; i < viewModel.count; i++) {
                    if (viewModel.get(i).id === viewId) {
                        currentViewData = viewModel.get(i)
                        if (currentViewData.definition) {
                            try {
                                viewDef = JSON.parse(currentViewData.definition)
                            } catch(e) { console.error(e) }
                        }
                        break
                    }
                }
                
                // Reload grid with view applied
                // Note: ideally we don't re-fetch data, just re-apply schema.
                // But for now, let's just trigger a "refresh" of the engine schema if we have the data.
                // Or simpler: loadData() again? No, expensive.
                // Let's pass the viewDef to engine? 
                // Engine doesn't know about JSON.
                // We should parse viewDef and update gridEngine schema.
                
                if (gridEngine.columnCount > 0) {
                    gridEngine.applyView(viewDef ? JSON.stringify(viewDef) : "")
                }
            }

            function loadData() {
                tableRoot.errorMessage = ""
                if (tableName) {
                    loadViews() // Refresh views list
                    
                    console.log("\u001b[34m📥 Buscando dados\u001b[0m", schema + "." + tableName)
                    var data = App.getDataset(schema, tableName, 100, 0)
                    console.log("\u001b[32m✅ Dataset recebido\u001b[0m", "colunas=" + (data.columns ? data.columns.length : 0) + " linhas=" + (data.rows ? data.rows.length : 0))
                    
                    if (data.error) {
                        console.error("\u001b[31m❌ Dataset\u001b[0m", data.error)
                        tableRoot.errorMessage = data.error
                        gridEngine.clear()
                        return
                    }
                    if (!data.columns || data.columns.length === 0) {
                        tableRoot.errorMessage = "Falha ao carregar dados da tabela."
                        gridEngine.clear()
                        return
                    }
                    
                    // Save raw columns for editor
                    tableRoot.rawColumns = []
                    for (var i = 0; i < data.columns.length; i++) {
                        tableRoot.rawColumns.push(data.columns[i])
                    }
                    
                    gridEngine.loadFromVariant(data)
                    
                    // Re-apply current view if needed
                    applyView(currentViewId)
                } else {
                    tableRoot.errorMessage = "Tabela inválida."
                    gridEngine.clear()
                }
            }
        }
    }
}
