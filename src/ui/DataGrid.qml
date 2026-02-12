import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
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
    property bool emptyStateEnabled: true
    property bool emptyStateSuppressed: false
    property string emptyStateTitle: "No rows found"
    property string emptyStateDescription: "This result set is empty. Try changing filters, pagination, or inserting new records."
    property int sortedColumnIndex: -1
    property bool sortAscending: true
    property string schemaName: ""
    property string tableName: ""
    property int contextRow: -1
    property int contextCol: -1
    property string toastText: ""
    property bool toastVisible: false
    signal addRowClicked()
    signal previousClicked()
    signal nextClicked()
    signal sortRequested(int columnIndex, bool ascending)
    signal editRowRequested(int rowIndex)
    
    function showToast(message) {
        toastText = message
        toastVisible = true
        toastTimer.restart()
    }
    
    function copyAndToast(text) {
        App.copyToClipboard(text)
        showToast("Copiado para a área de trabalho")
    }

    readonly property bool showEmptyState: emptyStateEnabled
                                         && !emptyStateSuppressed
                                         && view.engine
                                         && view.engine.columnCount > 0
                                         && view.engine.rowCount === 0

    function maxScrollX() {
        return Math.max(0, view.totalWidth - view.width)
    }

    function maxScrollY() {
        return Math.max(0, view.totalHeight - view.height)
    }

    function syncScrollBarsFromView() {
        var maxX = maxScrollX()
        var maxY = maxScrollY()
        var hRange = Math.max(0, 1 - hScroll.size)
        var vRange = Math.max(0, 1 - vScroll.size)
        hScroll.position = (maxX > 0 && hRange > 0) ? (view.contentX / maxX) * hRange : 0
        vScroll.position = (maxY > 0 && vRange > 0) ? (view.contentY / maxY) * vRange : 0
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
                resizeGuideColor: {
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

                    return activeColor
                }
                sortedColumnIndex: root.sortedColumnIndex
                sortAscending: root.sortAscending
                
                onCellContextMenuRequested: (row, col, x, y) => {
                    contextRow = row
                    contextCol = col
                    if (col === -1) {
                        rowContextMenu.popup(view, x, y)
                    } else {
                        cellContextMenu.popup(view, x, y)
                    }
                }

                onSortRequested: (columnIndex, ascending) => {
                    root.sortRequested(columnIndex, ascending)
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

            Rectangle {
                anchors.fill: parent
                visible: root.showEmptyState
                color: Theme.background
                z: 8

                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 48, 520)
                    spacing: 14

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 76
                        height: 76
                        radius: 18
                        color: Theme.tintColor(Theme.background, root.addRowAccentColor, 0.10)
                        border.color: Theme.tintColor(Theme.border, root.addRowAccentColor, 0.45)
                        border.width: 1

                        Image {
                            id: emptyStateIcon
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            source: "qrc:/qt/qml/sofa/ui/assets/table-cells-large-solid-full.svg"
                            sourceSize.width: 30
                            sourceSize.height: 30
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: emptyStateIcon
                            source: emptyStateIcon
                            color: root.addRowAccentColor
                            opacity: 0.9
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.emptyStateTitle
                        color: Theme.textPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        text: root.emptyStateDescription
                        color: Theme.textSecondary
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        lineHeight: 1.25
                    }
                }
            }

            Connections {
                target: view

                function onContentXChanged() { root.syncScrollBarsFromView() }
                function onContentYChanged() { root.syncScrollBarsFromView() }
                function onTotalWidthChanged() { root.syncScrollBarsFromView() }
                function onTotalHeightChanged() { root.syncScrollBarsFromView() }
                function onWidthChanged() { root.syncScrollBarsFromView() }
                function onHeightChanged() { root.syncScrollBarsFromView() }
            }
            
            AppMenu {
                id: cellContextMenu

                Controls.MenuItem {
                    text: "Edit Row"
                    enabled: contextRow !== -1
                    onTriggered: root.editRowRequested(contextRow)
                }

                Controls.MenuSeparator {}
                
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
                
                Controls.MenuSeparator {}
                
                Controls.MenuItem {
                    text: "Copy Row as JSON"
                    enabled: contextRow !== -1
                    onTriggered: copyAndToast(rowAsJson())
                }
                
                Controls.MenuItem {
                    text: "Copy Row as SQL"
                    enabled: contextRow !== -1
                    onTriggered: copyAndToast(rowAsSql())
                }
                
                Controls.MenuItem {
                    text: "Copy Row as Markdown"
                    enabled: contextRow !== -1
                    onTriggered: copyAndToast(rowAsMarkdown())
                }
            }

            AppMenu {
                id: rowContextMenu

                Controls.MenuItem {
                    text: "Copy Row as JSON"
                    enabled: contextRow !== -1
                    onTriggered: copyAndToast(rowAsJson())
                }

                Controls.MenuItem {
                    text: "Copy Row as SQL"
                    enabled: contextRow !== -1
                    onTriggered: copyAndToast(rowAsSql())
                }

                Controls.MenuItem {
                    text: "Copy Row as Markdown"
                    enabled: contextRow !== -1
                    onTriggered: copyAndToast(rowAsMarkdown())
                }
            }
            
            ScrollBar {
                id: vScroll
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: hScroll.top
                active: true
                visible: root.maxScrollY() > 0
                orientation: Qt.Vertical
                size: view.height / Math.max(view.height, view.totalHeight)
                
                onPositionChanged: {
                    if (pressed) {
                        var maxY = root.maxScrollY()
                        var vRange = Math.max(0, 1 - size)
                        view.contentY = (maxY > 0 && vRange > 0) ? (position / vRange) * maxY : 0
                    }
                }
            }
            
            ScrollBar {
                id: hScroll
                anchors.left: parent.left
                anchors.right: vScroll.left
                anchors.bottom: parent.bottom
                active: true
                visible: root.maxScrollX() > 0
                orientation: Qt.Horizontal
                size: view.width / Math.max(view.width, view.totalWidth)
                
                onPositionChanged: {
                    if (pressed) {
                        var maxX = root.maxScrollX()
                        var hRange = Math.max(0, 1 - size)
                        view.contentX = (maxX > 0 && hRange > 0) ? (position / hRange) * maxX : 0
                    }
                }
            }
            
            // Mouse Wheel Support (handler avoids overlay items that can steal hover/cursor)
            WheelHandler {
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y !== 0) {
                        var newY = view.contentY - wheel.angleDelta.y
                        if (newY < 0) newY = 0
                        if (newY > view.totalHeight - view.height) newY = view.totalHeight - view.height
                        view.contentY = newY
                        // Sync ScrollBar
                        var maxY = root.maxScrollY()
                        var vRange = Math.max(0, 1 - vScroll.size)
                        vScroll.position = (maxY > 0 && vRange > 0) ? (view.contentY / maxY) * vRange : 0
                    }
                    if (wheel.angleDelta.x !== 0) {
                        var newX = view.contentX - wheel.angleDelta.x
                        if (newX < 0) newX = 0
                        if (newX > view.totalWidth - view.width) newX = view.totalWidth - view.width
                        view.contentX = newX
                        var maxX = root.maxScrollX()
                        var hRange = Math.max(0, 1 - hScroll.size)
                        hScroll.position = (maxX > 0 && hRange > 0) ? (view.contentX / maxX) * hRange : 0
                    }

                    wheel.accepted = true
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
