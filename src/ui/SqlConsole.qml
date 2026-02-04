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
    signal queryTextEdited(string text)

    function setQueryText(text) {
        if (root.queryText !== text) {
            root.queryText = text
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
            color: Theme.background
            
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
                            highlighted: true
                            onClicked: runQuery()
                        }

                        AppButton {
                            text: "Cancel"
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
                        font.family: "Monospace" // TODO: Use a proper mono font
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        selectionColor: Theme.accent
                        selectedTextColor: "#FFFFFF"
                        selectByMouse: true
                        background: Rectangle { color: Theme.background }
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
                }
            }
        }
        
        // Results Area
        Rectangle {
            SplitView.fillHeight: true
            color: Theme.background
            
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
                        controlsVisible: root.gridControlsVisible
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: root.running || root.empty || root.errorMessage.length > 0

                        Text {
                            anchors.centerIn: parent
                            text: root.running ? "Carregando..." : (root.errorMessage.length > 0 ? root.errorMessage : "Sem resultados.")
                            color: root.errorMessage.length > 0 ? Theme.error : Theme.textSecondary
                            font.pixelSize: 14
                        }
                    }
                }
                
                // Status Bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        
                        Label {
                            id: statusLabel
                            text: root.statusText
                            color: Theme.textSecondary
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
            root.errorMessage = error
            root.statusText = "Error"
        }
        function onSqlCanceled(tag) {
            if (tag !== root.requestTag && root.requestTag.length > 0) return;
            root.running = false
            root.empty = false
            root.errorMessage = "Query cancelada."
            root.statusText = "Canceled"
        }
    }
}
