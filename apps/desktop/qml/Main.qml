import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import sofa.ui
import sofa.datagrid 1.0

ApplicationWindow {
    id: root
    width: 1024
    height: 768
    visible: true
    title: qsTr("Sofa Studio")
    color: Theme.background
    flags: Qt.FramelessWindowHint | Qt.Window
    
    property bool isRestoring: false
    property int resizeHandleSize: 6

    ListModel {
        id: tabModel
        ListElement { 
            title: "Home"
            type: "home"
            schema: ""
            tableName: ""
            connectionId: -1
            sqlText: ""
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

    function openConnectionTab(connectionId) {
        var title = connectionId === -1 ? "New Connection" : "Edit Connection"
        
        // Check if already open
        for (var i = 0; i < tabModel.count; i++) {
            var item = tabModel.get(i)
            if (item.type === "connection_form" && item.connectionId === connectionId) {
                appTabs.currentIndex = i
                return
            }
        }
        
        tabModel.append({ 
            "title": title, 
            "type": "connection_form",
            "connectionId": connectionId
        })
        appTabs.currentIndex = tabModel.count - 1
    }

    function openSqlConsole(initialText) {
        var baseTitle = "SQL"
        var title = baseTitle
        var suffix = 1
        var exists = true
        while (exists) {
            exists = false
            for (var i = 0; i < tabModel.count; i++) {
                if (tabModel.get(i).title === title) {
                    exists = true
                    suffix += 1
                    title = baseTitle + " " + suffix
                    break
                }
            }
        }
        tabModel.append({ "title": title, "type": "sql", "sqlText": initialText || "" })
        appTabs.currentIndex = tabModel.count - 1
    }

    function saveState() {
        if (isRestoring) {
            return
        }

        var tabs = []
        for (var i = 0; i < tabModel.count; i++) {
            var item = tabModel.get(i)
            if (item.type !== "home") {
                var tabData = {
                    "title": item.title,
                    "type": item.type,
                    "schema": item.schema || "",
                    "tableName": item.tableName || "",
                    "connectionId": item.connectionId || -1
                }
                if (item.type === "sql") {
                    tabData.sqlText = item.sqlText || ""
                }
                tabs.push(tabData)
            }
        }
        
        var state = {
            "lastConnectionId": App.activeConnectionId,
            "openTabs": tabs
        }
        
        App.saveAppState(state)
    }

    function restoreState() {
        isRestoring = true
        var state = App.loadAppState()
        
        if (state && state.lastConnectionId !== undefined) {
            if (state.lastConnectionId !== -1) {
                App.openConnection(state.lastConnectionId)
            }
        }
        
        if (state && state.openTabs && state.openTabs.length > 0) {
            for (var i = 0; i < state.openTabs.length; i++) {
                var tab = state.openTabs[i]
                
                // Construct a clean object for the model
                var newTab = {
                    "title": tab.title || "Untitled",
                    "type": tab.type || "home",
                    "schema": tab.schema || "public",
                    "tableName": tab.tableName || "",
                    "connectionId": tab.connectionId !== undefined ? tab.connectionId : -1,
                    "sqlText": tab.sqlText || ""
                }
                
                tabModel.append(newTab)
            }
            if (tabModel.count > 1) {
                appTabs.currentIndex = tabModel.count - 1
            }
        }
        isRestoring = false
    }

    Component.onCompleted: {
        restoreState()
    }

    Connections {
        target: App
        function onActiveConnectionIdChanged() { 
            // If connection closed (id == -1), close all tabs except Home
            if (App.activeConnectionId === -1) {
                // Iterate backwards to avoid index issues when removing
                for (var i = tabModel.count - 1; i >= 0; i--) {
                    if (tabModel.get(i).type !== "home") {
                        tabModel.remove(i)
                    }
                }
                appTabs.currentIndex = 0 // Ensure Home is active
            }
            saveState() 
        }
    }
    
    Connections {
        target: tabModel
        function onCountChanged() { 
            saveState() 
        }
    }
    
    Connections {
        target: tabModel
        function onDataChanged() {
            saveState()
        }
    }

    // ConnectionDialog removed, using ConnectionForm in tabs
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // App Header (Connections)
        AppHeader {
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            windowRef: root
            
            onRequestNewConnection: {
                openConnectionTab(-1)
            }
            
            onRequestEditConnection: (id) => {
                openConnectionTab(id)
            }
            
            onRequestDeleteConnection: (id) => {
                App.deleteConnection(id)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            AppSidebar {
                Layout.fillHeight: true
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
                    onNewQueryClicked: openSqlConsole()
                    onRequestCloseTab: (index) => {
                        console.log("Closing tab:", index)
                        if (index > 0 && index < tabModel.count) {
                            tabModel.remove(index)
                            // If we closed the active tab, or a tab before it, we need to adjust index
                            // TabBar usually handles index adjustment automatically when model changes,
                            // but let's ensure we land on a safe tab (e.g. last one) if current becomes invalid
                        }
                    }
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
                            property string itemSqlText: model.sqlText || ""
                            
                            sourceComponent: itemType === "home" ? homeComponent : (itemType === "table" ? tableComponent : (itemType === "connection_form" ? connectionFormComponent : sqlComponent))
                            
                            onLoaded: {
                                console.log("\u001b[36m🧭 Loader\u001b[0m", "index=" + index, "type=" + itemType, "schema=" + itemSchema, "table=" + itemTable)
                                if (item && itemType === "table") {
                                    item.schema = itemSchema
                                    item.tableName = itemTable
                                    item.loadData()
                                }
                                if (item && itemType === "connection_form") {
                                    if (model.connectionId !== -1) {
                                        // Find connection data
                                        for (var i = 0; i < App.connections.length; i++) {
                                            if (App.connections[i].id === model.connectionId) {
                                                item.load(App.connections[i])
                                                break
                                            }
                                        }
                                    } else {
                                        item.resetFields()
                                    }
                                }
                                if (item && itemType === "sql") {
                                    item.setQueryText(itemSqlText)
                                }
                            }
                            
                            onItemSqlTextChanged: {
                                if (item && itemType === "sql") {
                                    item.setQueryText(itemSqlText)
                                }
                            }
                            
                            onItemTypeChanged: console.log("Loader type changed:", index, itemType)
                            
                            Connections {
                                target: itemType === "sql" ? item : null
                                function onQueryTextEdited(text) {
                                    tabModel.setProperty(index, "sqlText", text)
                                    saveState()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            onPressed: root.startSystemResize(Qt.LeftEdge)
        }

        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            onPressed: root.startSystemResize(Qt.RightEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            onPressed: root.startSystemResize(Qt.TopEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            onPressed: root.startSystemResize(Qt.BottomEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            width: resizeHandleSize
            height: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: root.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
        }

        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            width: resizeHandleSize
            height: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeBDiagCursor
            onPressed: root.startSystemResize(Qt.TopEdge | Qt.RightEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: resizeHandleSize
            height: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeBDiagCursor
            onPressed: root.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
        }

        MouseArea {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: resizeHandleSize
            height: resizeHandleSize
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            onPressed: root.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
        }
    }

    function toggleMaximize() {
        if (root.visibility === Window.Maximized) {
            root.showNormal()
        } else {
            root.showMaximized()
        }
    }
    
    Component {
        id: connectionFormComponent
        ConnectionForm {
            onSaved: (id) => {
                // Close tab after save? Or just update title?
                // Let's close it for now as it's the standard behavior for dialogs
                // Find the tab index
                for (var i = 0; i < tabModel.count; i++) {
                    // Check if this form instance corresponds to this tab
                    // Since Loader recreates item, we can't easily check 'this' against loaded item
                    // But we know current index
                    if (appTabs.currentIndex === i) {
                        tabModel.remove(i)
                        break
                    }
                }
            }
            onCanceled: {
                for (var i = 0; i < tabModel.count; i++) {
                    if (appTabs.currentIndex === i) {
                        tabModel.remove(i)
                        break
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
