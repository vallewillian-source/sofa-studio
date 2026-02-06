import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import sofa.ui
import sofa.datagrid 1.0

ApplicationWindow {
    id: root
    width: 1024
    height: 768
    visible: true
    title: qsTr("Sofa Studio")
    color: "transparent"
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
        var title = tableName
        console.log("\u001b[36m📌 Abrindo aba\u001b[0m", schema + "." + tableName)
        // Check if already open
        for (var i = 0; i < tabModel.count; i++) {
            var item = tabModel.get(i)
            if (item.type === "table" && item.schema === schema && item.tableName === tableName) {
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
    
    Item {
        id: mainContainer
        anchors.fill: parent
        anchors.margins: root.visibility === Window.Maximized ? 0 : 0
        
        Rectangle {
            id: windowBackground
            anchors.fill: parent
            color: Theme.background
            radius: root.visibility === Window.Maximized ? 0 : 10
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // App Header (Connections)
            AppHeader {
                id: appHeader
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
                maximized: root.visibility === Window.Maximized
                onTableClicked: function(schema, tableName) {
                    openTable(schema, tableName)
                }
                onNewQueryClicked: openSqlConsole()
                onRequestNewConnection: appHeader.openConnectionModal()
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
                        var wasNew = tabModel.get(i).connectionId === -1
                        tabModel.remove(i)
                        
                        if (wasNew) {
                            console.log("Auto-opening new connection:", id)
                            App.openConnection(id)
                        }
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
            color: "transparent"
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
            
            // Helper to get active connection color
            function getActiveConnectionColor() {
                var currentId = App.activeConnectionId
                if (currentId === -1) return Theme.accent
                
                var conns = App.connections
                for (var i = 0; i < conns.length; i++) {
                    if (conns[i].id === currentId) {
                        return conns[i].color && conns[i].color.length > 0 ? conns[i].color : Theme.connectionAvatarColors[0]
                    }
                }
                return Theme.accent
            }

            color: Theme.background
            
            DataGridEngine {
                id: gridEngine
            }
            
            // Toolbar
            Rectangle {
                id: toolbar
                height: 48
                width: parent.width
                color: Theme.background
                border.color: Theme.border
                border.width: 1
                z: 10
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingLarge
                    spacing: Theme.spacingMedium
                    
                    AppButton {
                        text: ""
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/rotate-right-solid-full.svg"
                        isPrimary: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        tooltip: "Refresh Data"
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 24
                        iconSize: 12
                        opacity: 0.8
                        onClicked: tableRoot.loadData()
                    }

                    AppButton {
                        text: "Add Row"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/plus-solid-full.svg"
                        isPrimary: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        iconSize: 12
                        spacing: 4
                        opacity: 0.8
                        font.weight: Font.DemiBold
                        onClicked: console.log("Add row clicked")
                    }

                    AppButton {
                        id: btnCount
                        text: "Count"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/hashtag-solid-full.svg"
                        isPrimary: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        iconSize: 12
                        spacing: 4
                        opacity: 0.8
                        font.weight: Font.DemiBold
                        
                        // Dynamic padding to shrink button when loading
                        horizontalPadding: isLoading ? 4 : (text.length > 0 ? 12 : 0)
                        
                        property bool isLoading: false
                        property string originalText: "Count"
                        property var countStartTime: 0
                        
                        Timer {
                            id: delayTimer
                            property var pendingTotal: 0
                            repeat: false
                            onTriggered: {
                                btnCount.finishLoading(pendingTotal)
                            }
                        }
                        
                        function startDelay(total, interval) {
                            delayTimer.pendingTotal = total
                            delayTimer.interval = interval
                            delayTimer.start()
                        }
                        
                        function finishLoading(total) {
                            isLoading = false
                            var suffix = (total === 1) ? " record" : " records"
                            text = total + suffix
                        }
                        
                        // Custom content item to support loading animation
                        contentItem: Item {
                            implicitWidth: btnCount.isLoading ? 16 : (rowLayout.implicitWidth)
                            implicitHeight: 24 // Match button height for proper vertical centering
                            
                            // Normal Content
                            RowLayout {
                                id: rowLayout
                                anchors.centerIn: parent
                                spacing: btnCount.spacing
                                visible: !btnCount.isLoading
                                
                                Image {
                                    id: iconItem
                                    source: btnCount.icon.source
                                    Layout.preferredWidth: btnCount.iconSize
                                    Layout.preferredHeight: btnCount.iconSize
                                    sourceSize: Qt.size(btnCount.iconSize, btnCount.iconSize)
                                    fillMode: Image.PreserveAspectFit
                                    visible: btnCount.icon.source != ""
                                    Layout.alignment: Qt.AlignVCenter
                                    
                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        color: btnCount.textColor
                                    }
                                }
                                
                                Text {
                                    id: labelItem
                                    text: btnCount.text
                                    font: btnCount.font
                                    color: btnCount.textColor
                                    verticalAlignment: Text.AlignVCenter
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                            
                            // Loading Indicator
                            BusyIndicator {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                visible: btnCount.isLoading
                                running: btnCount.isLoading
                                
                                contentItem: Item {
                                    RotationAnimator on rotation {
                                        running: btnCount.isLoading
                                        loops: Animation.Infinite
                                        duration: 1500
                                        from: 0 ; to: 360
                                    }
                                    
                                    Rectangle {
                                        id: rect
                                        width: 16
                                        height: 16
                                        color: "transparent"
                                        radius: 8
                                        border.width: 2
                                        border.color: btnCount.textColor
                                        opacity: 0.3
                                    }
                                    
                                    Rectangle {
                                        width: 16
                                        height: 16
                                        color: "transparent"
                                        radius: 8
                                        border.width: 2
                                        border.color: btnCount.textColor
                                        
                                        // Clip half to create spinner effect
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: 16
                                                height: 16
                                                radius: 8
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: "transparent" }
                                                    GradientStop { position: 0.5; color: "black" }
                                                    GradientStop { position: 1.0; color: "black" }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        onClicked: {
                            if (!isLoading) {
                                isLoading = true
                                countStartTime = Date.now()
                                tableRoot.runCount()
                            }
                        }
                    }

                    AppButton {
                        text: "Structure"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/table-list-solid-full.svg"
                        isPrimary: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        iconSize: 12
                        spacing: 4
                        opacity: 0.8
                        font.weight: Font.DemiBold
                        onClicked: console.log("Structure clicked")
                    }

                    AppButton {
                        text: "Indexes"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/key-solid-full.svg"
                        isPrimary: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        iconSize: 12
                        spacing: 4
                        opacity: 0.8
                        font.weight: Font.DemiBold
                        onClicked: console.log("Indexes clicked")
                    }

                    AppButton {
                        text: "Views"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/eye-solid-full.svg"
                        isPrimary: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        iconSize: 12
                        spacing: 4
                        opacity: 0.8
                        font.weight: Font.DemiBold
                        onClicked: console.log("Views clicked")
                    }

                    Item { Layout.fillWidth: true }
                    
                    // View Selector
                    Label { 
                        text: "VIEW" 
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: Theme.textSecondary
                    }
                    
                    ComboBox {
                        id: viewSelector
                        Layout.preferredWidth: 200
                        Layout.preferredHeight: 32
                        textRole: "name"
                        valueRole: "id"
                        model: ListModel { id: viewModel }
                        
                        onActivated: (index) => {
                            var viewId = viewModel.get(index).id
                            tableRoot.applyView(viewId)
                        }
                    }
                    
                    // Actions
                    AppButton {
                        text: "New View"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/table-cells-large-solid-full.svg"
                        onClicked: viewEditor.openEditor(tableRoot.rawColumns, null)
                        opacity: 0.8
                        font.weight: Font.DemiBold
                    }
                    
                    AppButton {
                        text: "Edit"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/gear-solid-full.svg"
                        enabled: tableRoot.currentViewId !== -1
                        onClicked: viewEditor.openEditor(tableRoot.rawColumns, tableRoot.currentViewData)
                        opacity: 0.8
                        font.weight: Font.DemiBold
                    }
                }
            }

            DataGrid {
                anchors.top: toolbar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                engine: gridEngine
                visible: !tableRoot.loading && !tableRoot.empty && tableRoot.errorMessage.length === 0
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

            // Empty/Loading/Error State
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: toolbar.height
                color: Theme.background
                visible: tableRoot.loading || tableRoot.empty || tableRoot.errorMessage.length > 0
                z: 5
                
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingLarge
                    
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        
                        Image {
                            id: stateIcon
                            anchors.fill: parent
                            source: tableRoot.loading ? "qrc:/qt/qml/sofa/ui/assets/buffer-brands-solid-full.svg" : (tableRoot.errorMessage.length > 0 ? "qrc:/qt/qml/sofa/ui/assets/eye-slash-solid-full.svg" : "qrc:/qt/qml/sofa/ui/assets/table-list-solid-full.svg")
                            sourceSize.width: 64
                            sourceSize.height: 64
                            visible: false
                        }
                         
                        ColorOverlay {
                            anchors.fill: stateIcon
                            source: stateIcon
                            color: Theme.textSecondary
                            opacity: 0.1
                        }
                        
                        // Simple rotation for loading
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 2000
                            loops: Animation.Infinite
                            running: tableRoot.loading
                        }
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: tableRoot.loading ? "Loading Data..." : (tableRoot.errorMessage.length > 0 ? "Error Loading Data" : "No Data Found")
                        color: Theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 400
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        text: tableRoot.errorMessage.length > 0 ? tableRoot.errorMessage : "The query returned no results."
                        color: Theme.textSecondary
                        font.pixelSize: 14
                        visible: !tableRoot.loading
                    }
                    
                    AppButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Try Again"
                        isPrimary: true
                        visible: tableRoot.errorMessage.length > 0
                        onClicked: tableRoot.loadData()
                    }
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

            function runCount() {
                var tag = "count_" + Date.now()
                App.getCount(schema, tableName, tag)
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

                function onCountFinished(tag, total) {
                    if (tag.startsWith("count_")) {
                        // Assuming this is for the current table's count button
                        if (btnCount.isLoading) {
                            var elapsed = Date.now() - btnCount.countStartTime
                            var minTime = 300
                            var remaining = minTime - elapsed
                            
                            if (remaining > 0) {
                                btnCount.startDelay(total, remaining)
                            } else {
                                btnCount.finishLoading(total)
                            }
                        }
                    }
                }
            }
        }
    }
}
