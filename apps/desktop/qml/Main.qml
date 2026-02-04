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
            focus: true
            property string schema: "public"
            property string tableName: ""
            property string errorMessage: ""
            property bool loading: false
            property bool empty: false
            property bool gridControlsVisible: true
            property string requestTag: ""
            
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
                controlsVisible: tableRoot.gridControlsVisible
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

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: tableRoot.loading || tableRoot.empty || tableRoot.errorMessage.length > 0

                Text {
                    anchors.centerIn: parent
                    text: tableRoot.loading ? "Carregando..." : (tableRoot.errorMessage.length > 0 ? tableRoot.errorMessage : "Sem resultados.")
                    color: tableRoot.errorMessage.length > 0 ? Theme.error : Theme.textSecondary
                    font.pixelSize: 14
                }
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
                tableRoot.empty = false
                tableRoot.loading = false
                if (tableName) {
                    loadViews() // Refresh views list
                    
                    console.log("\u001b[34m📥 Buscando dados\u001b[0m", schema + "." + tableName)
                    tableRoot.requestTag = "table:" + schema + "." + tableName
                    tableRoot.loading = true
                    var ok = App.getDatasetAsync(schema, tableName, 100, 0, tableRoot.requestTag)
                    if (!ok) {
                        tableRoot.loading = false
                        tableRoot.errorMessage = App.lastError
                        gridEngine.clear()
                    }
                } else {
                    tableRoot.errorMessage = "Tabela inválida."
                    gridEngine.clear()
                }
            }

            Keys.onPressed: (event) => {
                if ((event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Period) {
                    tableRoot.gridControlsVisible = !tableRoot.gridControlsVisible
                    event.accepted = true;
                }
                if (event.key === Qt.Key_Escape) {
                    if (tableRoot.loading) {
                        App.cancelActiveQuery();
                        event.accepted = true;
                    }
                }
            }

            Connections {
                target: App
                function onDatasetStarted(tag) {
                    if (tag !== tableRoot.requestTag) return;
                    tableRoot.loading = true
                    tableRoot.errorMessage = ""
                }
                function onDatasetFinished(tag, result) {
                    if (tag !== tableRoot.requestTag) return;
                    tableRoot.loading = false
                    tableRoot.errorMessage = ""
                    console.log("\u001b[32m✅ Dataset recebido\u001b[0m", "colunas=" + (result.columns ? result.columns.length : 0) + " linhas=" + (result.rows ? result.rows.length : 0))
                    if (!result.columns || result.columns.length === 0) {
                        tableRoot.errorMessage = "Falha ao carregar dados da tabela."
                        tableRoot.empty = false
                        gridEngine.clear()
                        return
                    }
                    tableRoot.empty = result.rows && result.rows.length === 0

                    tableRoot.rawColumns = []
                    for (var i = 0; i < result.columns.length; i++) {
                        tableRoot.rawColumns.push(result.columns[i])
                    }
                    gridEngine.loadFromVariant(result)
                    applyView(currentViewId)
                }
                function onDatasetError(tag, error) {
                    if (tag !== tableRoot.requestTag && tableRoot.requestTag.length > 0) return;
                    tableRoot.loading = false
                    tableRoot.empty = false
                    tableRoot.errorMessage = error
                    gridEngine.clear()
                }
                function onDatasetCanceled(tag) {
                    if (tag !== tableRoot.requestTag && tableRoot.requestTag.length > 0) return;
                    tableRoot.loading = false
                    tableRoot.empty = false
                    tableRoot.errorMessage = "Query cancelada."
                    gridEngine.clear()
                }
            }
        }
    }
}
