import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui
import sofa.datagrid 1.0

Item {
    id: root
    focus: true
    property bool running: false
    property bool empty: false
    property bool gridControlsVisible: true
    property string statusText: "Ready"
    property string errorMessage: ""
    property string requestTag: "sql"
    property string queryText: "SELECT * FROM users LIMIT 10;"
    property int sortColumnIndex: -1
    property bool sortAscending: true
    property bool sortActive: false
    property var lastResult: ({})
    readonly property color activeConnectionColor: {
        var id = App.activeConnectionId
        if (id === -1) return Theme.accent
        var conns = App.connections
        for (var i = 0; i < conns.length; i++) {
            if (conns[i].id === id) {
                return Theme.getConnectionColor(conns[i].name, conns[i].color)
            }
        }
        return Theme.accent
    }
    signal queryTextEdited(string text)

    function setQueryText(text) {
        if (root.queryText !== text) {
            root.queryText = text
        }
    }

    function resetSortState() {
        root.sortColumnIndex = -1
        root.sortAscending = true
        root.sortActive = false
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

    function sortLocalResult(columnIndex, ascending) {
        if (!root.lastResult || !root.lastResult.columns || columnIndex < 0) {
            return null
        }

        var rows = root.lastResult.rows ? root.lastResult.rows.slice(0) : []
        var nulls = root.lastResult.nulls ? root.lastResult.nulls.slice(0) : []
        var zipped = []
        for (var i = 0; i < rows.length; i++) {
            zipped.push({
                row: rows[i],
                nullRow: i < nulls.length ? nulls[i] : []
            })
        }

        zipped.sort(function(left, right) {
            var leftRow = left.row || []
            var rightRow = right.row || []
            var leftNullRow = left.nullRow || []
            var rightNullRow = right.nullRow || []
            var leftVal = columnIndex < leftRow.length ? leftRow[columnIndex] : null
            var rightVal = columnIndex < rightRow.length ? rightRow[columnIndex] : null
            var leftIsNull = (columnIndex < leftNullRow.length && leftNullRow[columnIndex] === true) || leftVal === null || leftVal === undefined
            var rightIsNull = (columnIndex < rightNullRow.length && rightNullRow[columnIndex] === true) || rightVal === null || rightVal === undefined
            return compareCellValues(leftIsNull ? null : leftVal, rightIsNull ? null : rightVal, ascending)
        })

        var sortedRows = []
        var sortedNulls = []
        for (var j = 0; j < zipped.length; j++) {
            sortedRows.push(zipped[j].row)
            sortedNulls.push(zipped[j].nullRow)
        }

        return {
            "columns": root.lastResult.columns,
            "rows": sortedRows,
            "nulls": sortedNulls,
            "executionTime": root.lastResult.executionTime,
            "warning": root.lastResult.warning,
            "hasMore": root.lastResult.hasMore
        }
    }
    
    // SplitView for Editor (top) and Results (bottom)
    SplitView {
        anchors.fill: parent
        orientation: Qt.Vertical
        
        // Editor Area
        Rectangle {
            SplitView.preferredHeight: parent.height * 0.4
            SplitView.minimumHeight: 100
            color: "transparent"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // Toolbar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingMedium
                        anchors.rightMargin: Theme.spacingMedium
                        spacing: Theme.spacingMedium
                        
                        AppButton {
                            text: "Run"
                            isPrimary: true
                            accentColor: root.activeConnectionColor
                            onClicked: runQuery()
                        }

                        AppButton {
                            text: "Cancel"
                            isOutline: true
                            accentColor: root.activeConnectionColor
                            enabled: root.running
                            onClicked: {
                                if (root.running) {
                                    App.cancelActiveQuery()
                                }
                            }
                        }
                        
                        Label {
                            text: "(Cmd+Enter)"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                        }
                        
                        Item { Layout.fillWidth: true }
                    }
                }
                
                // Editor
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    TextArea {
                        id: queryEditor
                        font.family: Qt.platform.os === "osx" ? "Menlo" : "Monospace"
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        selectionColor: root.activeConnectionColor
                        selectedTextColor: "#FFFFFF"
                        selectByMouse: true
                        background: Rectangle { color: "transparent" }
                        padding: 10
                        text: root.queryText
                        
                        Keys.onPressed: (event) => {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier)) {
                                runQuery();
                                event.accepted = true;
                            }
                            if (event.key === Qt.Key_Escape) {
                                if (root.running) {
                                    App.cancelActiveQuery();
                                    event.accepted = true;
                                }
                            }
                        }
                        
                        onTextChanged: {
                            if (root.queryText !== text) {
                                root.queryText = text
                                root.queryTextEdited(text)
                            }
                        }
                    }

                    SqlSyntaxHighlighter {
                        document: queryEditor.textDocument
                        keywordColor: root.activeConnectionColor
                        stringColor: Theme.tintColor(Theme.textPrimary, root.activeConnectionColor, 0.35)
                        numberColor: Theme.tintColor(Theme.textPrimary, root.activeConnectionColor, 0.55)
                        commentColor: Theme.textSecondary
                    }
                }
            }
        }
        
        // Results Area
        Rectangle {
            SplitView.fillHeight: true
            color: "transparent"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                
                // DataGrid Container with Overlay
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    DataGrid {
                        anchors.fill: parent
                        engine: gridEngine
                        addRowAccentColor: root.activeConnectionColor
                        emptyStateSuppressed: root.running || root.errorMessage.length > 0
                        emptyStateTitle: "No results returned"
                        emptyStateDescription: "Run another query or adjust the current SQL to retrieve matching rows."
                        sortedColumnIndex: root.sortActive ? root.sortColumnIndex : -1
                        sortAscending: root.sortAscending
                        onSortRequested: (columnIndex, ascending) => {
                            var sorted = root.sortLocalResult(columnIndex, ascending)
                            if (!sorted) return
                            root.sortColumnIndex = columnIndex
                            root.sortAscending = ascending
                            root.sortActive = true
                            gridEngine.loadFromVariant(sorted)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: root.running || root.errorMessage.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: root.running ? "Carregando..." : (root.errorMessage.length > 0 ? root.errorMessage : "Sem resultados.")
                            color: root.errorMessage.length > 0 ? Theme.error : root.activeConnectionColor
                            font.pixelSize: 14
                        }
                    }
                }
                
                // Status Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    color: "transparent"
                    
                    // Top Border
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.border
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        
                        Label {
                            id: statusLabel
                            text: root.statusText
                            color: root.errorMessage.length > 0
                                ? Theme.error
                                : (root.running ? root.activeConnectionColor : Theme.textSecondary)
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
    
    DataGridEngine {
        id: gridEngine
    }
    
    function runQuery() {
        var query = queryEditor.text;
        if (!query.trim()) return;
        root.resetSortState()
        root.errorMessage = ""
        root.empty = false
        root.statusText = "Running..."
        root.requestTag = "sql"
        var ok = App.runQueryAsync(query, root.requestTag)
        if (!ok) {
            root.running = false
            root.statusText = "Error"
            root.errorMessage = App.lastError
        }
    }

    Keys.onPressed: (event) => {
        if ((event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_Period) {
            root.gridControlsVisible = !root.gridControlsVisible
            event.accepted = true;
        }
        if (event.key === Qt.Key_Escape) {
            if (root.running) {
                App.cancelActiveQuery();
                event.accepted = true;
            }
        }
    }

    Connections {
        target: App
        function onSqlStarted(tag) {
            if (tag !== root.requestTag) return;
            root.running = true
            root.statusText = "Running..."
            root.errorMessage = ""
        }
        function onSqlFinished(tag, result) {
            if (tag !== root.requestTag) return;
            root.running = false
            root.errorMessage = ""
            root.lastResult = result
            root.resetSortState()
            if (result && result.rows && result.rows.length === 0) {
                root.empty = true
            } else {
                root.empty = false
            }
            gridEngine.loadFromVariant(result)
            var msg = "Done."
            if (result.executionTime) {
                msg += " Time: " + result.executionTime + "ms";
            }
            if (result.warning) {
                msg += " Warning: " + result.warning;
            }
            root.statusText = msg
        }
        function onSqlError(tag, error) {
            if (tag !== root.requestTag && root.requestTag.length > 0) return;
            root.running = false
            root.empty = false
            root.lastResult = ({})
            root.resetSortState()
            root.errorMessage = error
            root.statusText = "Error"
        }
        function onSqlCanceled(tag) {
            if (tag !== root.requestTag && root.requestTag.length > 0) return;
            root.running = false
            root.empty = false
            root.lastResult = ({})
            root.resetSortState()
            root.errorMessage = "Query cancelada."
            root.statusText = "Canceled"
        }
    }
}
