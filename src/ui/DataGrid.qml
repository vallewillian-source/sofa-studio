import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import sofa.ui
import sofa.datagrid 1.0

Rectangle {
    id: root
    color: "transparent"
    
    // Public API
    property alias engine: view.engine
    property int pageSize: 100
    property int currentPage: 1
    property bool canPrevious: false
    property bool canNext: false
    property color addRowAccentColor: Theme.accent
    property string schemaName: ""
    property string tableName: ""
    property int contextRow: -1
    property int contextCol: -1
    property string toastText: ""
    property bool toastVisible: false
    signal addRowClicked()
    signal previousClicked()
    signal nextClicked()
    
    function showToast(message) {
        toastText = message
        toastVisible = true
        toastTimer.restart()
    }
    
    function copyAndToast(text) {
        App.copyToClipboard(text)
        showToast("Copiado para a área de trabalho")
    }
    
    function columnNames() {
        var cols = []
        if (!view.engine) return cols
        var count = view.engine.columnCount
        for (var i = 0; i < count; i++) {
            cols.push(view.engine.getColumnName(i))
        }
        return cols
    }
    
    function rowValues() {
        if (!view.engine) return []
        return view.engine.getRow(contextRow)
    }
    
    function sqlValue(value) {
        if (value === null || value === undefined) return "NULL"
        if (typeof value === "number") return value.toString()
        if (typeof value === "boolean") return value ? "TRUE" : "FALSE"
        var text = String(value)
        text = text.replace(/'/g, "''")
        return "'" + text + "'"
    }
    
    function markdownCell(value) {
        if (value === null || value === undefined) return ""
        var text = String(value)
        text = text.replace(/\|/g, "\\|")
        text = text.replace(/\n/g, " ")
        return text
    }
    
    function rowAsJson() {
        var cols = columnNames()
        var row = rowValues()
        var obj = {}
        for (var i = 0; i < cols.length; i++) {
            obj[cols[i]] = row[i]
        }
        return JSON.stringify(obj, null, 2)
    }
    
    function rowAsSql() {
        var cols = columnNames()
        var row = rowValues()
        var baseTable = tableName.length > 0 ? tableName : "table"
        var fullName = schemaName.length > 0 ? schemaName + "." + baseTable : baseTable
        var colSql = cols.map((c) => "\"" + String(c).replace(/"/g, "\"\"") + "\"").join(", ")
        var valSql = row.map(sqlValue).join(", ")
        return "INSERT INTO " + fullName + " (" + colSql + ") VALUES (" + valSql + ");"
    }
    
    function rowAsMarkdown() {
        var cols = columnNames()
        var row = rowValues()
        if (cols.length === 0) return ""
        var header = "| " + cols.map(markdownCell).join(" | ") + " |"
        var sep = "| " + cols.map(() => "---").join(" | ") + " |"
        var line = "| " + row.map(markdownCell).join(" | ") + " |"
        return header + "\n" + sep + "\n" + line
    }
    
    Timer {
        id: toastTimer
        interval: 2000
        repeat: false
        onTriggered: toastVisible = false
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Grid Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true
            
            DataGridView {
                id: view
                anchors.fill: parent

                // Colors
                // Header darker than background
                headerColor: "#050505" 
                
                onTotalWidthChanged: console.log("DataGrid TotalWidth:", totalWidth, "ViewWidth:", width)
                
                // Zebra striping with connection tint
                alternateRowColor: {
                    var id = App.activeConnectionId
                    var activeColor = Theme.accent
                    
                    if (id !== -1) {
                        var conns = App.connections
                        for (var i = 0; i < conns.length; i++) {
                            if (conns[i].id === id) {
                                activeColor = Theme.getConnectionColor(conns[i].name, conns[i].color)
                                break
                            }
                        }
                    }
                    
                    // Mix Theme.background with activeColor (4% opacity)
                    return Theme.tintColor(Theme.background, activeColor, 0.04)
                }
                
                // Selection with connection tint (80% opacity)
                selectionColor: {
                    var id = App.activeConnectionId
                    var activeColor = Theme.accent
                    
                    if (id !== -1) {
                        var conns = App.connections
                        for (var i = 0; i < conns.length; i++) {
                            if (conns[i].id === id) {
                                activeColor = Theme.getConnectionColor(conns[i].name, conns[i].color)
                                break
                            }
                        }
                    }
                    
                    return Theme.tintColor(Theme.background, activeColor, 0.8)
                }

                gridLineColor: "transparent"
                textColor: Theme.textPrimary
                resizeGuideColor: Theme.accent
                
                // Bind scrollbars
                contentY: vScroll.position * view.totalHeight
                contentX: hScroll.position * view.totalWidth
                
                onCellContextMenuRequested: (row, col, x, y) => {
                    contextRow = row
                    contextCol = col
                    contextMenu.popup(view, x, y)
                }

                onColumnResized: (index, width) => {
                    var name = view.engine ? view.engine.getColumnName(index) : ("Column " + (index + 1))
                    showToast("Coluna \"" + name + "\": " + width + " px")
                }

                onRowHeightResized: (height) => {
                    showToast("Altura das linhas: " + Math.round(height) + " px")
                }

                onRowResized: (row, height) => {
                    showToast("Linha " + (row + 1) + ": " + Math.round(height) + " px")
                }
            }
            
            AppMenu {
                id: contextMenu
                
                Controls.MenuItem {
                    text: "Copy"
                    enabled: contextRow !== -1 && contextCol !== -1
                    onTriggered: {
                        var value = view.engine ? view.engine.getData(contextRow, contextCol) : ""
                        copyAndToast(String(value))
                    }
                }
                
                Controls.MenuItem {
                    text: "Copy Column Name"
                    enabled: contextRow !== -1 && contextCol !== -1
                    onTriggered: {
                        var name = view.engine ? view.engine.getColumnName(contextCol) : ""
                        copyAndToast(String(name))
                    }
                }
                
                Controls.MenuItem {
                    text: "Copy Row as JSON"
                    enabled: contextRow !== -1 && contextCol !== -1
                    onTriggered: copyAndToast(rowAsJson())
                }
                
                Controls.MenuItem {
                    text: "Copy Row as SQL"
                    enabled: contextRow !== -1 && contextCol !== -1
                    onTriggered: copyAndToast(rowAsSql())
                }
                
                Controls.MenuItem {
                    text: "Copy Row as Markdown"
                    enabled: contextRow !== -1 && contextCol !== -1
                    onTriggered: copyAndToast(rowAsMarkdown())
                }
            }
            
            ScrollBar {
                id: vScroll
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: hScroll.top
                active: true
                orientation: Qt.Vertical
                size: view.height / Math.max(view.height, view.totalHeight)
                
                onPositionChanged: {
                    if (pressed) {
                        view.contentY = position * view.totalHeight
                    }
                }
            }
            
            ScrollBar {
                id: hScroll
                anchors.left: parent.left
                anchors.right: vScroll.left
                anchors.bottom: parent.bottom
                active: true
                orientation: Qt.Horizontal
                size: view.width / Math.max(view.width, view.totalWidth)
                
                onPositionChanged: {
                    if (pressed) {
                        view.contentX = position * view.totalWidth
                    }
                }
            }
            
            // Mouse Wheel Support
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y !== 0) {
                        var newY = view.contentY - wheel.angleDelta.y
                        if (newY < 0) newY = 0
                        if (newY > view.totalHeight - view.height) newY = view.totalHeight - view.height
                        view.contentY = newY
                        // Sync ScrollBar
                        if (view.totalHeight > 0)
                            vScroll.position = view.contentY / view.totalHeight
                    }
                    if (wheel.angleDelta.x !== 0) {
                        var newX = view.contentX - wheel.angleDelta.x
                        if (newX < 0) newX = 0
                        if (newX > view.totalWidth - view.width) newX = view.totalWidth - view.width
                        view.contentX = newX
                        if (view.totalWidth > 0)
                            hScroll.position = view.contentX / view.totalWidth
                    }
                }
            }
            
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: Theme.spacingLarge
                anchors.bottomMargin: Theme.spacingLarge
                color: Theme.surfaceHighlight
                border.color: Theme.border
                border.width: 1
                radius: Theme.radius
                visible: toastVisible
                z: 10
                
                Text {
                    text: toastText
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacingMedium
                }
            }
        }
        
        // Footer / Status Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            visible: true
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium
                spacing: Theme.spacingMedium
                
                AppButton {
                    text: "Add Row"
                    icon.source: "qrc:/qt/qml/sofa/ui/assets/plus-solid-full.svg"
                    isPrimary: true
                    accentColor: root.addRowAccentColor
                    Layout.preferredHeight: 24
                    iconSize: 12
                    spacing: 4
                    opacity: 0.8
                    font.weight: Font.DemiBold
                    onClicked: root.addRowClicked()
                }

                Label {
                    text: "Rows: " + (view.engine ? view.engine.rowCount : 0)
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }
                
                Item { Layout.fillWidth: true }

                // Pagination
                RowLayout {
                    spacing: 8
                    
                    AppButton {
                        text: "Previous"
                        Layout.preferredHeight: 24
                        font.pixelSize: 11
                        isPrimary: false
                        enabled: root.canPrevious
                        opacity: root.canPrevious ? 1.0 : 0.5
                        onClicked: root.previousClicked()
                    }
                    
                    Label {
                        text: "Page " + root.currentPage
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                    
                    AppButton {
                        text: "Next"
                        Layout.preferredHeight: 24
                        font.pixelSize: 11
                        isPrimary: false
                        enabled: root.canNext
                        opacity: root.canNext ? 1.0 : 0.5
                        onClicked: root.nextClicked()
                    }
                }
            }
        }
    }
}
