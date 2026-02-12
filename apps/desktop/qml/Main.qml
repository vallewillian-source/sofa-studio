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
    property int filtersPanelWidth: 320
    property int pendingDeleteConnectionId: -1

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
                root.pendingDeleteConnectionId = Number(id)
                deleteConnectionConfirmPopup.open()
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
                    onRequestCloseAllTabs: () => {
                        for (var i = tabModel.count - 1; i >= 1; i--) {
                            tabModel.remove(i)
                        }
                        appTabs.currentIndex = 0
                    }
                    onRequestCloseOthers: (index) => {
                        if (index < 0 || index >= tabModel.count) {
                            return
                        }
                        for (var i = tabModel.count - 1; i >= 0; i--) {
                            if (i !== index && tabModel.get(i).type !== "home") {
                                tabModel.remove(i)
                            }
                        }
                        if (appTabs.currentIndex !== index) {
                            appTabs.currentIndex = Math.min(index, tabModel.count - 1)
                        }
                    }
                    onRequestCloseTabsToRight: (index) => {
                        if (index < 0 || index >= tabModel.count) {
                            return
                        }
                        for (var i = tabModel.count - 1; i > index; i--) {
                            if (tabModel.get(i).type !== "home") {
                                tabModel.remove(i)
                            }
                        }
                        if (appTabs.currentIndex > index) {
                            appTabs.currentIndex = index
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
            property int pageSize: 100
            property int pageIndex: 0
            property bool hasMore: false
            property bool pendingLoad: false
            property bool pendingLoadUseDelayed: false
            property string insertRequestTag: ""
            property bool insertRunning: false
            property string sortColumnName: ""
            property bool sortAscending: true
            property bool sortActive: false
            property var lastDatasetResult: ({})
            property bool requestInFlight: false
            property bool delayedLoadingForCurrentRequest: false
            
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

            function quoteIdentifier(name) {
                return "\"" + String(name).replace(/"/g, "\"\"") + "\""
            }

            function addRowColumns() {
                var cols = []
                if (!gridEngine) return cols
                var count = gridEngine.columnCount
                for (var i = 0; i < count; i++) {
                    cols.push({
                        "name": gridEngine.getColumnName(i),
                        "type": gridEngine.getColumnType(i),
                        "defaultValue": gridEngine.getColumnDefaultValue(i),
                        "temporalInputGroup": gridEngine.getColumnTemporalInputGroup(i),
                        "temporalNowExpression": gridEngine.getColumnTemporalNowExpression(i),
                        "isNullable": gridEngine.getColumnIsNullable(i),
                        "isPrimaryKey": gridEngine.getColumnIsPrimaryKey(i)
                    })
                }
                return cols
            }

            function currentSortColumnIndex() {
                if (!sortActive || !sortColumnName || !gridEngine) return -1
                var count = gridEngine.columnCount
                for (var i = 0; i < count; i++) {
                    if (gridEngine.getColumnName(i) === sortColumnName) {
                        return i
                    }
                }
                return -1
            }

            function resetSortState() {
                sortColumnName = ""
                sortAscending = true
                sortActive = false
            }

            function parseDateMs(value) {
                if (value === null || value === undefined) return NaN
                var parsed = Date.parse(String(value))
                return isNaN(parsed) ? NaN : parsed
            }

            function compareCellValues(a, b, ascending) {
                var aNull = (a === null || a === undefined)
                var bNull = (b === null || b === undefined)
                if (aNull || bNull) {
                    if (aNull && bNull) return 0
                    if (ascending) return aNull ? 1 : -1
                    return aNull ? -1 : 1
                }

                if (typeof a === "number" && typeof b === "number") {
                    return ascending ? (a - b) : (b - a)
                }

                if (typeof a === "boolean" && typeof b === "boolean") {
                    if (a === b) return 0
                    var boolCmp = a ? 1 : -1
                    return ascending ? boolCmp : -boolCmp
                }

                var aDate = parseDateMs(a)
                var bDate = parseDateMs(b)
                if (!isNaN(aDate) && !isNaN(bDate)) {
                    return ascending ? (aDate - bDate) : (bDate - aDate)
                }

                var aText = String(a).toLocaleLowerCase()
                var bText = String(b).toLocaleLowerCase()
                var textCmp = aText.localeCompare(bText)
                return ascending ? textCmp : -textCmp
            }

            function sortDatasetLocally(dataset, columnName, ascending) {
                if (!dataset || !dataset.columns || !dataset.rows || !columnName) return null

                var sortIndex = -1
                for (var i = 0; i < dataset.columns.length; i++) {
                    if ((dataset.columns[i].name || "") === columnName) {
                        sortIndex = i
                        break
                    }
                }
                if (sortIndex < 0) return null

                var rows = dataset.rows ? dataset.rows.slice(0) : []
                var nulls = dataset.nulls ? dataset.nulls.slice(0) : []
                var zipped = []
                for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
                    zipped.push({
                        row: rows[rowIndex],
                        nullRow: rowIndex < nulls.length ? nulls[rowIndex] : []
                    })
                }

                zipped.sort(function(left, right) {
                    var leftRow = left.row || []
                    var rightRow = right.row || []
                    var leftNullRow = left.nullRow || []
                    var rightNullRow = right.nullRow || []
                    var leftVal = sortIndex < leftRow.length ? leftRow[sortIndex] : null
                    var rightVal = sortIndex < rightRow.length ? rightRow[sortIndex] : null
                    var leftIsNull = (sortIndex < leftNullRow.length && leftNullRow[sortIndex] === true) || leftVal === null || leftVal === undefined
                    var rightIsNull = (sortIndex < rightNullRow.length && rightNullRow[sortIndex] === true) || rightVal === null || rightVal === undefined
                    return compareCellValues(leftIsNull ? null : leftVal, rightIsNull ? null : rightVal, ascending)
                })

                var sortedRows = []
                var sortedNulls = []
                for (var sortedIndex = 0; sortedIndex < zipped.length; sortedIndex++) {
                    sortedRows.push(zipped[sortedIndex].row)
                    sortedNulls.push(zipped[sortedIndex].nullRow)
                }

                return {
                    "columns": dataset.columns,
                    "rows": sortedRows,
                    "nulls": sortedNulls,
                    "hasMore": dataset.hasMore,
                    "executionTime": dataset.executionTime,
                    "warning": dataset.warning
                }
            }

            function applySortToCurrentDataset() {
                if (!sortActive || !sortColumnName || !lastDatasetResult || !lastDatasetResult.columns) {
                    if (lastDatasetResult && lastDatasetResult.columns) {
                        gridEngine.loadFromVariant(lastDatasetResult)
                    }
                    return
                }

                var sorted = sortDatasetLocally(lastDatasetResult, sortColumnName, sortAscending)
                if (sorted) {
                    gridEngine.loadFromVariant(sorted)
                } else {
                    gridEngine.loadFromVariant(lastDatasetResult)
                }
            }

            function openAddRowModal() {
                var cols = addRowColumns()
                if (cols.length === 0) return
                rowEditorModal.openForAdd(tableRoot.schema, tableRoot.tableName, cols)
            }

            function openEditRowModal(rowIndex, focusColumnIndex) {
                if (rowIndex === undefined || rowIndex === null || rowIndex < 0) return
                var cols = addRowColumns()
                if (cols.length === 0) return
                var rowValues = gridEngine.getRow(rowIndex)
                if (!rowValues || rowValues.length === 0) return
                var focusIndex = Number(focusColumnIndex)
                if (!isFinite(focusIndex)) {
                    focusIndex = -1
                }
                rowEditorModal.openForEdit(tableRoot.schema, tableRoot.tableName, cols, rowValues, focusIndex)
            }

            function buildInsertSql(entries) {
                var quotedCols = []
                var quotedVals = []
                for (var i = 0; i < entries.length; i++) {
                    var rawValue = entries[i].value
                    if (rawValue === null || rawValue === undefined) {
                        continue
                    }

                    var text = String(rawValue)
                    var trimmed = text.trim()
                    if (trimmed.length === 0) {
                        // Empty input means: let DB default apply.
                        continue
                    }

                    quotedCols.push(quoteIdentifier(entries[i].name))
                    if (trimmed.toUpperCase() === "NULL") {
                        // Explicit NULL token.
                        quotedVals.push("NULL")
                    } else {
                        quotedVals.push("'" + text.replace(/'/g, "''") + "'")
                    }
                }

                var target = quoteIdentifier(tableRoot.schema) + "." + quoteIdentifier(tableRoot.tableName)
                if (quotedCols.length === 0) {
                    return "INSERT INTO " + target + " DEFAULT VALUES;"
                }
                return "INSERT INTO " + target + " (" + quotedCols.join(", ") + ") VALUES (" + quotedVals.join(", ") + ");"
            }

            function buildUpdateSql(entries) {
                if (!entries || entries.length === 0) return ""

                var target = quoteIdentifier(tableRoot.schema) + "." + quoteIdentifier(tableRoot.tableName)
                var setParts = []
                var whereParts = []
                var pkWhereParts = []

                for (var i = 0; i < entries.length; i++) {
                    var entry = entries[i]
                    var colName = quoteIdentifier(entry.name)
                    var valueText = String(entry.value === null || entry.value === undefined ? "" : entry.value)
                    var trimmed = valueText.trim()
                    var initialText = String(entry.initialValue === null || entry.initialValue === undefined ? "" : entry.initialValue)
                    var original = entry.originalValue

                    if (valueText !== initialText) {
                        if (trimmed.toUpperCase() === "NULL") {
                            setParts.push(colName + " = NULL")
                        } else {
                            setParts.push(colName + " = '" + valueText.replace(/'/g, "''") + "'")
                        }
                    }

                    if (original === null || original === undefined) {
                        whereParts.push(colName + " IS NULL")
                        if (entry.isPrimaryKey === true) {
                            pkWhereParts.push(colName + " IS NULL")
                        }
                    } else if (typeof original === "number") {
                        whereParts.push(colName + " = " + String(original))
                        if (entry.isPrimaryKey === true) {
                            pkWhereParts.push(colName + " = " + String(original))
                        }
                    } else if (typeof original === "boolean") {
                        whereParts.push(colName + " = " + (original ? "TRUE" : "FALSE"))
                        if (entry.isPrimaryKey === true) {
                            pkWhereParts.push(colName + " = " + (original ? "TRUE" : "FALSE"))
                        }
                    } else {
                        var quotedOriginal = "'" + String(original).replace(/'/g, "''") + "'"
                        whereParts.push(colName + " = " + quotedOriginal)
                        if (entry.isPrimaryKey === true) {
                            pkWhereParts.push(colName + " = " + quotedOriginal)
                        }
                    }
                }

                if (setParts.length === 0) return ""

                var finalWhereParts = pkWhereParts.length > 0 ? pkWhereParts : whereParts
                if (finalWhereParts.length === 0) return ""

                return "UPDATE " + target + " SET " + setParts.join(", ") + " WHERE " + finalWhereParts.join(" AND ") + ";"
            }

            color: Theme.background
            
            DataGridEngine {
                id: gridEngine
            }

            Timer {
                id: loadRetryTimer
                interval: 150
                repeat: false
                onTriggered: {
                    if (tableRoot.pendingLoad) {
                        tableRoot.loadData(tableRoot.pendingLoadUseDelayed)
                    }
                }
            }

            Timer {
                id: loadingVisualDelayTimer
                interval: 150
                repeat: false
                onTriggered: {
                    if (tableRoot.requestInFlight && tableRoot.delayedLoadingForCurrentRequest) {
                        tableRoot.loading = true
                    }
                }
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
                        isPrimary: false
                        isOutline: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        tooltip: "Refresh Data"
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 24
                        iconSize: 12
                        opacity: 0.8
                        onClicked: tableRoot.loadData()
                    }

                    AppButton {
                        id: btnCount
                        text: "Count"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/hashtag-solid-full.svg"
                        isPrimary: false
                        isOutline: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        iconSize: 12
                        spacing: 4
                        opacity: 0.8
                        font.weight: Font.DemiBold
                        
                        // Dynamic padding to shrink button when loading
                        horizontalPadding: (text.length > 0 ? 12 : 0)
                        
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
                            implicitWidth: rowLayout.implicitWidth
                            implicitHeight: 24 // Match button height for proper vertical centering
                            
                            // Normal Content
                            RowLayout {
                                id: rowLayout
                                anchors.centerIn: parent
                                spacing: btnCount.spacing
                                visible: true
                                
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
                            
                        }

                        onClicked: {
                            if (!isLoading) {
                                isLoading = true
                                countStartTime = Date.now()
                                text = "loading..."
                                tableRoot.runCount()
                            }
                        }
                    }

                    AppButton {
                        text: "Structure"
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/table-list-solid-full.svg"
                        isPrimary: false
                        isOutline: true
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
                        isPrimary: false
                        isOutline: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        iconSize: 12
                        spacing: 4
                        opacity: 0.8
                        font.weight: Font.DemiBold
                        onClicked: console.log("Indexes clicked")
                    }

                    Item { Layout.fillWidth: true }

                    AppButton {
                        id: btnFilters
                        text: "Filters"
                        isPrimary: false
                        isOutline: true
                        accentColor: tableRoot.getActiveConnectionColor()
                        Layout.preferredHeight: 24
                        spacing: 4
                        opacity: 1.0
                        font.weight: Font.DemiBold
                        contentItem: RowLayout {
                            spacing: 6
                            Text {
                                text: "Filters"
                                color: btnFilters.textColor
                                font: btnFilters.font
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                text: "›"
                                color: btnFilters.textColor
                                font.pixelSize: 14
                                font.bold: true
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        onClicked: {
                            if (rightFiltersDrawer.visible) {
                                rightFiltersDrawer.close()
                            } else {
                                rightFiltersDrawer.open()
                            }
                        }
                    }
                }
            }

            DataGrid {
                anchors.top: toolbar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                engine: gridEngine
                schemaName: tableRoot.schema
                tableName: tableRoot.tableName
                emptyStateTitle: "This table has no rows yet"
                emptyStateDescription: "Use Add Row to insert the first record, or adjust your pagination to inspect other pages."
                sortedColumnIndex: tableRoot.currentSortColumnIndex()
                sortAscending: tableRoot.sortAscending
                visible: !tableRoot.loading && tableRoot.errorMessage.length === 0
                currentPage: tableRoot.pageIndex + 1
                pageSize: tableRoot.pageSize
                canPrevious: tableRoot.pageIndex > 0 && !tableRoot.requestInFlight
                canNext: tableRoot.hasMore && !tableRoot.requestInFlight
                addRowAccentColor: tableRoot.getActiveConnectionColor()
                onPreviousClicked: tableRoot.previousPage()
                onNextClicked: tableRoot.nextPage()
                onAddRowClicked: tableRoot.openAddRowModal()
                onEditRowRequested: (rowIndex, columnIndex) => {
                    tableRoot.openEditRowModal(rowIndex, columnIndex)
                }
                onSortRequested: (columnIndex, ascending) => {
                    var columnName = gridEngine.getColumnName(columnIndex)
                    if (!columnName || columnName.length === 0) return
                    tableRoot.sortColumnName = columnName
                    tableRoot.sortAscending = ascending
                    tableRoot.sortActive = true
                    tableRoot.applySortToCurrentDataset()
                }
            }

            RowEditorModal {
                id: rowEditorModal
                accentColor: tableRoot.getActiveConnectionColor()
                onSubmitRequested: (entries) => {
                    if (tableRoot.insertRunning) return
                    if (!entries || entries.length === 0) return

                    errorMessage = ""
                    submitting = true
                    var mode = rowEditorModal.editing ? "update" : "insert"
                    tableRoot.insertRequestTag = mode + ":" + tableRoot.schema + "." + tableRoot.tableName + ":" + Date.now()

                    var mutationSql = rowEditorModal.editing
                        ? tableRoot.buildUpdateSql(entries)
                        : tableRoot.buildInsertSql(entries)
                    if (!mutationSql || mutationSql.length === 0) {
                        submitting = false
                        errorMessage = rowEditorModal.editing ? "Nenhuma alteração detectada." : "Falha ao montar INSERT."
                        return
                    }

                    var ok = App.runQueryAsync(mutationSql, tableRoot.insertRequestTag)
                    if (!ok) {
                        submitting = false
                        errorMessage = App.lastError.length > 0
                            ? App.lastError
                            : (rowEditorModal.editing ? "Falha ao executar UPDATE." : "Falha ao executar INSERT.")
                    }
                }
            }
            
            // ViewEditor removed

            // Empty/Loading/Error State
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: toolbar.height
                color: Theme.background
                visible: tableRoot.loading || tableRoot.errorMessage.length > 0
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
                            source: tableRoot.loading ? "qrc:/qt/qml/sofa/ui/assets/buffer-brands-solid-full.svg" : (tableRoot.errorMessage.length > 0 ? "qrc:/qt/qml/sofa/ui/assets/eye-slash-solid-full.svg" : "qrc:/qt/qml/sofa/ui/assets/table-cells-large-solid-full.svg")
                            sourceSize.width: 64
                            sourceSize.height: 64
                            visible: false
                        }
                         
                        ColorOverlay {
                            anchors.fill: stateIcon
                            source: stateIcon
                            color: (tableRoot.loading || tableRoot.empty || tableRoot.errorMessage.length > 0) ? Theme.textPrimary : Theme.textSecondary
                            opacity: (tableRoot.loading || tableRoot.empty || tableRoot.errorMessage.length > 0) ? 0.5 : 0.1
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
                        accentColor: tableRoot.getActiveConnectionColor()
                        visible: tableRoot.errorMessage.length > 0
                        onClicked: tableRoot.loadData()
                    }
                }
            }


            function loadData(useDelayedLoading) {
                if (useDelayedLoading === undefined) useDelayedLoading = false
                tableRoot.errorMessage = ""
                tableRoot.empty = false
                tableRoot.loading = false
                tableRoot.hasMore = false
                if (tableName) {
                    if (App.queryRunning) {
                        tableRoot.pendingLoad = true
                        tableRoot.pendingLoadUseDelayed = useDelayedLoading
                        tableRoot.requestInFlight = true
                        tableRoot.delayedLoadingForCurrentRequest = useDelayedLoading
                        tableRoot.loading = !useDelayedLoading
                        if (!loadRetryTimer.running) {
                            loadRetryTimer.start()
                        }
                        return
                    }

                    tableRoot.pendingLoad = false
                    tableRoot.pendingLoadUseDelayed = false
                    console.log("\u001b[34m📥 Buscando dados\u001b[0m", schema + "." + tableName)
                    tableRoot.requestTag = "table:" + schema + "." + tableName + ":page:" + tableRoot.pageIndex
                    tableRoot.requestInFlight = true
                    tableRoot.delayedLoadingForCurrentRequest = useDelayedLoading
                    tableRoot.loading = !useDelayedLoading
                    if (useDelayedLoading) {
                        loadingVisualDelayTimer.restart()
                    } else {
                        loadingVisualDelayTimer.stop()
                    }
                    var offset = tableRoot.pageIndex * tableRoot.pageSize
                    var ok = App.getDatasetAsync(
                        schema,
                        tableName,
                        tableRoot.pageSize,
                        offset,
                        "",
                        true,
                        tableRoot.requestTag
                    )
                    if (!ok) {
                        tableRoot.requestInFlight = false
                        tableRoot.delayedLoadingForCurrentRequest = false
                        loadingVisualDelayTimer.stop()
                        tableRoot.loading = false
                        tableRoot.errorMessage = App.lastError
                        tableRoot.lastDatasetResult = ({})
                        gridEngine.clear()
                    }
                } else {
                    tableRoot.pendingLoad = false
                    tableRoot.pendingLoadUseDelayed = false
                    tableRoot.requestInFlight = false
                    tableRoot.delayedLoadingForCurrentRequest = false
                    loadingVisualDelayTimer.stop()
                    tableRoot.errorMessage = "Tabela inválida."
                    tableRoot.lastDatasetResult = ({})
                    gridEngine.clear()
                }
            }

            onSchemaChanged: {
                tableRoot.pageIndex = 0
                tableRoot.resetSortState()
                tableRoot.lastDatasetResult = ({})
                tableRoot.requestInFlight = false
                tableRoot.delayedLoadingForCurrentRequest = false
                loadingVisualDelayTimer.stop()
            }

            onTableNameChanged: {
                tableRoot.pageIndex = 0
                tableRoot.resetSortState()
                tableRoot.lastDatasetResult = ({})
                tableRoot.requestInFlight = false
                tableRoot.delayedLoadingForCurrentRequest = false
                loadingVisualDelayTimer.stop()
            }

            function runCount() {
                var tag = "count_" + Date.now()
                App.getCount(schema, tableName, tag)
            }

            function nextPage() {
                if (!tableRoot.requestInFlight && tableRoot.hasMore) {
                    tableRoot.pageIndex += 1
                    tableRoot.loadData(true)
                }
            }

            function previousPage() {
                if (!tableRoot.requestInFlight && tableRoot.pageIndex > 0) {
                    tableRoot.pageIndex -= 1
                    tableRoot.loadData(true)
                }
            }

            Keys.onPressed: (event) => {
                if ((event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Period) {
                    tableRoot.gridControlsVisible = !tableRoot.gridControlsVisible
                    event.accepted = true;
                }
                if (event.key === Qt.Key_Escape) {
                    if (tableRoot.requestInFlight) {
                        App.cancelActiveQuery();
                        event.accepted = true;
                    }
                }
            }

            Connections {
                target: App
                function onDatasetStarted(tag) {
                    if (tag !== tableRoot.requestTag) return;
                    tableRoot.errorMessage = ""
                    if (!tableRoot.delayedLoadingForCurrentRequest) {
                        tableRoot.loading = true
                    }
                }
                function onDatasetFinished(tag, result) {
                    if (tag !== tableRoot.requestTag) return;
                    tableRoot.requestInFlight = false
                    tableRoot.delayedLoadingForCurrentRequest = false
                    loadingVisualDelayTimer.stop()
                    tableRoot.loading = false
                    tableRoot.errorMessage = ""
                    console.log("\u001b[32m✅ Dataset recebido\u001b[0m", "colunas=" + (result.columns ? result.columns.length : 0) + " linhas=" + (result.rows ? result.rows.length : 0))
                    tableRoot.hasMore = result.hasMore === true
                    if (!result.columns || result.columns.length === 0) {
                        tableRoot.errorMessage = "Falha ao carregar dados da tabela."
                        tableRoot.empty = false
                        gridEngine.clear()
                        return
                    }
                    tableRoot.empty = result.rows && result.rows.length === 0

                    tableRoot.lastDatasetResult = result
                    tableRoot.applySortToCurrentDataset()
                }
                function onDatasetError(tag, error) {
                    if (tag !== tableRoot.requestTag && tableRoot.requestTag.length > 0) return;
                    tableRoot.requestInFlight = false
                    tableRoot.delayedLoadingForCurrentRequest = false
                    loadingVisualDelayTimer.stop()
                    tableRoot.loading = false
                    tableRoot.empty = false
                    tableRoot.errorMessage = error
                    tableRoot.hasMore = false
                    tableRoot.lastDatasetResult = ({})
                    gridEngine.clear()
                }
                function onDatasetCanceled(tag) {
                    if (tag !== tableRoot.requestTag && tableRoot.requestTag.length > 0) return;
                    tableRoot.requestInFlight = false
                    tableRoot.delayedLoadingForCurrentRequest = false
                    loadingVisualDelayTimer.stop()
                    tableRoot.loading = false
                    tableRoot.empty = false
                    tableRoot.errorMessage = "Query cancelada."
                    tableRoot.hasMore = false
                    tableRoot.lastDatasetResult = ({})
                    gridEngine.clear()
                }

                function onSqlStarted(tag) {
                    if (tag !== tableRoot.insertRequestTag) return;
                    tableRoot.insertRunning = true
                    rowEditorModal.submitting = true
                    rowEditorModal.errorMessage = ""
                }

                function onSqlFinished(tag, result) {
                    if (tag !== tableRoot.insertRequestTag) return;
                    tableRoot.insertRunning = false
                    rowEditorModal.submitting = false
                    rowEditorModal.errorMessage = ""
                    rowEditorModal.close()
                    tableRoot.loadData()
                }

                function onSqlError(tag, error) {
                    if (tag !== tableRoot.insertRequestTag) return;
                    tableRoot.insertRunning = false
                    rowEditorModal.submitting = false
                    rowEditorModal.errorMessage = error
                }

                function onSqlCanceled(tag) {
                    if (tag !== tableRoot.insertRequestTag) return;
                    tableRoot.insertRunning = false
                    rowEditorModal.submitting = false
                    rowEditorModal.errorMessage = "INSERT cancelado."
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

    Drawer {
        id: rightFiltersDrawer
        parent: Overlay.overlay
        edge: Qt.RightEdge
        modal: false
        dim: false
        interactive: false
        closePolicy: Popup.NoAutoClose
        width: root.filtersPanelWidth
        height: root.height - appHeader.height
        y: appHeader.height
        z: 200
        property string filterMode: "simple"
        property string simpleValue: ""
        property string manualWhereText: ""
        property int simpleSelectedFieldIndex: 0
        property int simpleSelectedOperatorIndex: 0
        readonly property var currentTabItem: (appTabs.currentIndex >= 0 && appTabs.currentIndex < tabModel.count)
            ? tabModel.get(appTabs.currentIndex)
            : null
        readonly property string currentSchemaName: (currentTabItem && currentTabItem.schema && String(currentTabItem.schema).length > 0)
            ? String(currentTabItem.schema)
            : "public"
        readonly property string currentTableName: (currentTabItem && currentTabItem.tableName && String(currentTabItem.tableName).length > 0)
            ? String(currentTabItem.tableName)
            : "table_name"
        readonly property color accentColor: {
            var currentId = App.activeConnectionId
            if (currentId === -1) return Theme.accent
            var conns = App.connections
            for (var i = 0; i < conns.length; i++) {
                if (conns[i].id === currentId) {
                    return conns[i].color && conns[i].color.length > 0 ? conns[i].color : Theme.accent
                }
            }
            return Theme.accent
        }

        function quoteIdentifier(identifier) {
            var raw = String(identifier === undefined || identifier === null ? "" : identifier)
            return "\"" + raw.replace(/"/g, "\"\"") + "\""
        }

        function quoteSqlStringLiteral(value) {
            return "'" + String(value).replace(/'/g, "''") + "'"
        }

        function currentSimpleFieldSqlName() {
            if (simpleSelectedFieldIndex < 0 || simpleSelectedFieldIndex >= simpleFieldModel.count) {
                return "column_name"
            }
            return String(simpleFieldModel.get(simpleSelectedFieldIndex).sqlName || "column_name")
        }

        function currentSimpleOperatorSql() {
            if (simpleSelectedOperatorIndex < 0 || simpleSelectedOperatorIndex >= simpleOperatorModel.count) {
                return "="
            }
            return String(simpleOperatorModel.get(simpleSelectedOperatorIndex).sql || "=")
        }

        function currentSimpleOperatorNeedsValue() {
            if (simpleSelectedOperatorIndex < 0 || simpleSelectedOperatorIndex >= simpleOperatorModel.count) {
                return true
            }
            return simpleOperatorModel.get(simpleSelectedOperatorIndex).needsValue === true
        }

        function currentSimpleOperatorUsesPattern() {
            if (simpleSelectedOperatorIndex < 0 || simpleSelectedOperatorIndex >= simpleOperatorModel.count) {
                return false
            }
            return simpleOperatorModel.get(simpleSelectedOperatorIndex).usesPattern === true
        }

        function buildSimpleWhereClause() {
            var fieldSql = quoteIdentifier(currentSimpleFieldSqlName())
            var opSql = currentSimpleOperatorSql()
            if (!currentSimpleOperatorNeedsValue()) {
                return fieldSql + " " + opSql
            }
            var valueText = String(simpleValue || "")
            if (currentSimpleOperatorUsesPattern()) {
                valueText = "%" + valueText + "%"
            }
            return fieldSql + " " + opSql + " " + quoteSqlStringLiteral(valueText)
        }

        function buildPreviewFilterQuery() {
            var query = "SELECT *\nFROM " + quoteIdentifier(currentSchemaName) + "." + quoteIdentifier(currentTableName)
            var whereClause = ""
            if (filterMode === "manual") {
                whereClause = String(manualWhereText || "").trim()
            } else {
                whereClause = buildSimpleWhereClause()
            }
            if (whereClause.length > 0) {
                query += "\nWHERE " + whereClause
            }
            return query + ";"
        }

        function resetDraftFilters() {
            filterMode = "simple"
            simpleSelectedFieldIndex = 0
            simpleSelectedOperatorIndex = 0
            simpleValue = ""
            manualWhereText = ""
        }

        ListModel {
            id: simpleFieldModel
            ListElement { label: "id"; sqlName: "id" }
            ListElement { label: "name"; sqlName: "name" }
            ListElement { label: "status"; sqlName: "status" }
            ListElement { label: "created_at"; sqlName: "created_at" }
        }

        ListModel {
            id: simpleOperatorModel
            ListElement { label: "equals"; sql: "="; needsValue: true; usesPattern: false }
            ListElement { label: "does not equal"; sql: "<>"; needsValue: true; usesPattern: false }
            ListElement { label: "like"; sql: "LIKE"; needsValue: true; usesPattern: true }
            ListElement { label: "not like"; sql: "NOT LIKE"; needsValue: true; usesPattern: true }
            ListElement { label: "greater than"; sql: ">"; needsValue: true; usesPattern: false }
            ListElement { label: "less than"; sql: "<"; needsValue: true; usesPattern: false }
            ListElement { label: "is null"; sql: "IS NULL"; needsValue: false; usesPattern: false }
            ListElement { label: "is not null"; sql: "IS NOT NULL"; needsValue: false; usesPattern: false }
        }

        background: Rectangle {
            color: Theme.sidebarSurface
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: Theme.surface
                function withAlpha(colorValue, alphaValue) {
                    var c = Qt.color(colorValue)
                    return Qt.rgba(c.r, c.g, c.b, alphaValue)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 2
                    color: parent.withAlpha(rightFiltersDrawer.accentColor, 0.65)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.rightMargin: Theme.spacingMedium
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: Theme.spacingMedium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "Filters"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: "Refine this dataset with smart conditions"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    AppButton {
                        id: btnCloseFiltersPanel
                        text: "×"
                        isPrimary: false
                        isOutline: false
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        horizontalPadding: 0
                        verticalPadding: 0
                        font.pixelSize: 14
                        contentItem: Text {
                            text: "×"
                            color: btnCloseFiltersPanel.textColor
                            font.pixelSize: btnCloseFiltersPanel.font.pixelSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: rightFiltersDrawer.close()
                    }
                }
            }

            ScrollView {
                id: filtersBodyScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Item {
                    width: Math.max(filtersBodyScroll.availableWidth, 1)
                    implicitHeight: filtersBody.implicitHeight + (Theme.spacingLarge * 2)
                    height: Math.max(implicitHeight, filtersBodyScroll.availableHeight)

                    ColumnLayout {
                        id: filtersBody
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Theme.spacingLarge
                        anchors.rightMargin: Theme.spacingLarge
                        anchors.topMargin: Theme.spacingLarge
                        anchors.bottomMargin: Theme.spacingLarge
                        spacing: Theme.spacingLarge

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.preferredHeight: implicitHeight
                            Layout.maximumHeight: implicitHeight
                            spacing: Theme.spacingSmall

                            Text {
                                Layout.fillWidth: true
                                text: "Query preview"
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            TextArea {
                                id: filtersPreviewSql
                                Layout.fillWidth: true
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAnywhere
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                text: rightFiltersDrawer.buildPreviewFilterQuery()
                                color: Theme.textPrimary
                                selectionColor: Theme.accent
                                selectedTextColor: "#FFFFFF"
                                background: Rectangle { color: "transparent" }
                                font.pixelSize: 11
                                font.family: Qt.platform.os === "osx" ? "Menlo" : "Monospace"
                                implicitHeight: Math.max(44, contentHeight)
                            }

                            SqlSyntaxHighlighter {
                                document: filtersPreviewSql.textDocument
                                keywordColor: Theme.accentSecondary
                                stringColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[3], 0.55)
                                numberColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[8], 0.65)
                                commentColor: Theme.textSecondary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            Layout.preferredHeight: implicitHeight
                            Layout.maximumHeight: implicitHeight
                            spacing: Theme.spacingSmall

                            Text {
                                Layout.fillWidth: true
                                text: "Filter mode"
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: Theme.radius
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1

                                RowLayout {
                                    id: filterModeButtonsRow
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    spacing: 3

                                    AppButton {
                                        Layout.preferredWidth: (filterModeButtonsRow.width - filterModeButtonsRow.spacing) / 2
                                        Layout.preferredHeight: 28
                                        text: "Simple"
                                        isPrimary: rightFiltersDrawer.filterMode === "simple"
                                        isOutline: rightFiltersDrawer.filterMode !== "simple"
                                        accentColor: rightFiltersDrawer.accentColor
                                        font.pixelSize: 12
                                        onClicked: rightFiltersDrawer.filterMode = "simple"
                                    }

                                    AppButton {
                                        Layout.preferredWidth: (filterModeButtonsRow.width - filterModeButtonsRow.spacing) / 2
                                        Layout.preferredHeight: 28
                                        text: "Manual SQL"
                                        isPrimary: rightFiltersDrawer.filterMode === "manual"
                                        isOutline: rightFiltersDrawer.filterMode !== "manual"
                                        accentColor: rightFiltersDrawer.accentColor
                                        font.pixelSize: 12
                                        onClicked: rightFiltersDrawer.filterMode = "manual"
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: rightFiltersDrawer.filterMode === "simple"
                            Layout.fillHeight: rightFiltersDrawer.filterMode === "simple"
                            Layout.minimumHeight: visible ? implicitHeight : 0
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            Layout.maximumHeight: visible ? Number.POSITIVE_INFINITY : 0
                            spacing: Theme.spacingSmall

                            Text {
                                Layout.fillWidth: true
                                text: "Simple filter"
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 10
                                text: "Field"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                font.bold: true
                            }

                            ComboBox {
                                id: simpleFieldCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.buttonHeight
                                textRole: "label"
                                valueRole: "sqlName"
                                model: simpleFieldModel
                                currentIndex: Math.max(0, Math.min(simpleFieldModel.count - 1, rightFiltersDrawer.simpleSelectedFieldIndex))
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0) {
                                        rightFiltersDrawer.simpleSelectedFieldIndex = currentIndex
                                    }
                                }

                                background: Rectangle {
                                    implicitHeight: Theme.buttonHeight
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? rightFiltersDrawer.accentColor : Theme.border
                                    border.width: 1
                                    radius: Theme.radius
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    rightPadding: 10
                                    text: simpleFieldCombo.displayText
                                    color: Theme.textPrimary
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                delegate: ItemDelegate {
                                    required property string label
                                    required property int index
                                    width: simpleFieldCombo.width
                                    height: 30
                                    contentItem: Text {
                                        text: label
                                        color: Theme.textPrimary
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: highlighted ? Theme.surfaceHighlight : Theme.surface
                                    }
                                    highlighted: simpleFieldCombo.highlightedIndex === index
                                }

                                popup: Popup {
                                    y: simpleFieldCombo.height - 1
                                    width: simpleFieldCombo.width
                                    implicitHeight: Math.min(contentItem.implicitHeight, 220)
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: simpleFieldCombo.popup.visible ? simpleFieldCombo.delegateModel : null
                                        currentIndex: simpleFieldCombo.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }

                                    background: Rectangle {
                                        border.color: Theme.border
                                        color: Theme.surface
                                        radius: Theme.radius
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 10
                                text: "Condition"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                font.bold: true
                            }

                            ComboBox {
                                id: simpleOperatorCombo
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.buttonHeight
                                textRole: "label"
                                valueRole: "sql"
                                model: simpleOperatorModel
                                currentIndex: Math.max(0, Math.min(simpleOperatorModel.count - 1, rightFiltersDrawer.simpleSelectedOperatorIndex))
                                onCurrentIndexChanged: {
                                    if (currentIndex >= 0) {
                                        rightFiltersDrawer.simpleSelectedOperatorIndex = currentIndex
                                    }
                                }

                                background: Rectangle {
                                    implicitHeight: Theme.buttonHeight
                                    color: Theme.surface
                                    border.color: parent.activeFocus ? rightFiltersDrawer.accentColor : Theme.border
                                    border.width: 1
                                    radius: Theme.radius
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    rightPadding: 10
                                    text: simpleOperatorCombo.displayText
                                    color: Theme.textPrimary
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                delegate: ItemDelegate {
                                    required property string label
                                    required property int index
                                    width: simpleOperatorCombo.width
                                    height: 30
                                    contentItem: Text {
                                        text: label
                                        color: Theme.textPrimary
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        color: highlighted ? Theme.surfaceHighlight : Theme.surface
                                    }
                                    highlighted: simpleOperatorCombo.highlightedIndex === index
                                }

                                popup: Popup {
                                    y: simpleOperatorCombo.height - 1
                                    width: simpleOperatorCombo.width
                                    implicitHeight: Math.min(contentItem.implicitHeight, 220)
                                    padding: 1

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: simpleOperatorCombo.popup.visible ? simpleOperatorCombo.delegateModel : null
                                        currentIndex: simpleOperatorCombo.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }

                                    background: Rectangle {
                                        border.color: Theme.border
                                        color: Theme.surface
                                        radius: Theme.radius
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.topMargin: 10
                                text: "Value"
                                visible: rightFiltersDrawer.currentSimpleOperatorNeedsValue()
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                font.bold: true
                            }

                            AppTextField {
                                id: simpleValueInput
                                Layout.fillWidth: true
                                visible: rightFiltersDrawer.currentSimpleOperatorNeedsValue()
                                accentColor: rightFiltersDrawer.accentColor
                                placeholderText: "Type filter value"
                                text: rightFiltersDrawer.simpleValue
                                onTextChanged: {
                                    if (rightFiltersDrawer.simpleValue !== text) {
                                        rightFiltersDrawer.simpleValue = text
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: rightFiltersDrawer.filterMode === "simple"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: rightFiltersDrawer.filterMode === "manual"
                            visible: rightFiltersDrawer.filterMode === "manual"
                            Layout.minimumHeight: visible ? implicitHeight : 0
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            Layout.maximumHeight: visible ? Number.POSITIVE_INFINITY : 0
                            spacing: Theme.spacingSmall

                            Text {
                                Layout.fillWidth: true
                                text: "Manual <span style=\"color:" + rightFiltersDrawer.accentColor + ";\">where</span> clause"
                                textFormat: Text.RichText
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 180
                                color: Theme.surface
                                border.color: Theme.border
                                border.width: 1
                                radius: Theme.radius

                                TextArea {
                                    id: manualWhereEditor
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    font.family: Qt.platform.os === "osx" ? "Menlo" : "Monospace"
                                    font.pixelSize: 12
                                    color: Theme.textPrimary
                                    selectionColor: rightFiltersDrawer.accentColor
                                    selectedTextColor: "#FFFFFF"
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    background: Rectangle { color: "transparent" }
                                    placeholderText: "status = 'active'"
                                    text: rightFiltersDrawer.manualWhereText
                                    onTextChanged: {
                                        if (rightFiltersDrawer.manualWhereText !== text) {
                                            rightFiltersDrawer.manualWhereText = text
                                        }
                                    }
                                }

                                SqlSyntaxHighlighter {
                                    document: manualWhereEditor.textDocument
                                    keywordColor: Theme.accentSecondary
                                    stringColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[3], 0.55)
                                    numberColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[8], 0.65)
                                    commentColor: Theme.textSecondary
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                implicitHeight: footerActions.implicitHeight + (Theme.spacingMedium * 2)

                RowLayout {
                    id: footerActions
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingMedium
                    anchors.rightMargin: Theme.spacingMedium
                    anchors.topMargin: Theme.spacingMedium
                    anchors.bottomMargin: Theme.spacingMedium
                    spacing: Theme.spacingSmall

                    AppButton {
                        text: "Apply filters"
                        isPrimary: true
                        accentColor: rightFiltersDrawer.accentColor
                    }

                    Item { Layout.fillWidth: true }

                    AppButton {
                        text: "Clear filters"
                        isPrimary: false
                        isOutline: true
                        accentColor: rightFiltersDrawer.accentColor
                        onClicked: rightFiltersDrawer.resetDraftFilters()
                    }
                }
            }
        }
    }

    Popup {
        id: deleteConnectionConfirmPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        width: 380
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: Theme.spacingLarge
        implicitHeight: deleteConfirmContent.implicitHeight + topPadding + bottomPadding
        onClosed: {
            root.pendingDeleteConnectionId = -1
        }

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 8
        }

        contentItem: ColumnLayout {
            id: deleteConfirmContent
            width: deleteConnectionConfirmPopup.availableWidth
            spacing: Theme.spacingMedium

            Text {
                Layout.fillWidth: true
                text: "Delete connection?"
                color: Theme.textPrimary
                font.pixelSize: 15
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "This action removes the saved connection from Sofa Studio."
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "Cancel"
                    isPrimary: false
                    onClicked: deleteConnectionConfirmPopup.close()
                }

                AppButton {
                    text: "Delete"
                    isPrimary: true
                    accentColor: Theme.error
                    onClicked: {
                        if (root.pendingDeleteConnectionId >= 0) {
                            App.deleteConnection(root.pendingDeleteConnectionId)
                        }
                        deleteConnectionConfirmPopup.close()
                    }
                }
            }
        }
    }
}
