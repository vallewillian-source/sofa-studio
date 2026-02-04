import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui

Dialog {
    id: root
    title: "Edit View"
    width: 500
    height: 600
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    
    property var originalColumns: [] // array of {name: "col1", type: "int"}
    property var currentView: null // {id, name, definition}
    
    signal viewSaved(var viewData)
    
    onAccepted: {
        var def = []
        for (var i = 0; i < columnModel.count; i++) {
            var item = columnModel.get(i)
            def.push({
                "name": item.name,
                "label": item.label,
                "visible": item.visible
            })
        }
        
        var data = {
            "id": currentView ? currentView.id : -1,
            "name": nameField.text,
            "definition": JSON.stringify(def)
        }
        root.viewSaved(data)
    }
    
    function load(columns, view) {
        originalColumns = columns
        currentView = view
        
        nameField.text = view ? view.name : "New View"
        columnModel.clear()
        
        var defMap = {}
        if (view && view.definition) {
            try {
                var defs = JSON.parse(view.definition)
                for (var i = 0; i < defs.length; i++) {
                    defMap[defs[i].name] = defs[i]
                }
            } catch (e) {
                console.error("Failed to parse view definition", e)
            }
        }
        
        for (var i = 0; i < columns.length; i++) {
            var colName = columns[i].name
            var existing = defMap[colName]
            
            columnModel.append({
                "name": colName,
                "label": existing ? (existing.label || colName) : colName,
                "visible": existing ? (existing.visible !== false) : true,
                "type": columns[i].type || ""
            })
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "View Name"
        }
        
        Label { text: "Columns" }
        
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: ListModel { id: columnModel }
            
            delegate: Rectangle {
                width: ListView.view.width
                height: 40
                color: index % 2 === 0 ? Theme.surface : "transparent"
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    
                    CheckBox {
                        checked: model.visible
                        onCheckedChanged: model.visible = checked
                    }
                    
                    Text {
                        text: model.name
                        color: Theme.textSecondary
                        Layout.preferredWidth: 120
                        elide: Text.ElideRight
                    }
                    
                    Text {
                        text: "→"
                        color: Theme.textSecondary
                    }
                    
                    TextField {
                        text: model.label
                        Layout.fillWidth: true
                        placeholderText: "Alias"
                        onTextChanged: model.label = text
                    }
                }
            }
        }
    }
}
