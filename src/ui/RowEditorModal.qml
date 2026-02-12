import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui

Popup {
    id: root
    parent: Overlay.overlay
    width: {
        if (!parent) return 760
        var maxAllowed = Math.max(420, parent.width - (Theme.spacingXLarge * 2))
        return Math.min(820, maxAllowed)
    }
    height: {
        if (!parent) return 700
        return Math.min(760, parent.height - (Theme.spacingXLarge * 2))
    }
    x: Math.round((parent.width - width) / 2)
    y: Math.max(Theme.spacingXLarge, Math.round((parent.height - height) / 2))
    padding: 0
    modal: true
    focus: true
    clip: true
    closePolicy: root.submitting ? Popup.NoAutoClose : (Popup.CloseOnEscape | Popup.CloseOnPressOutside)

    property string schemaName: ""
    property string tableName: ""
    property bool submitting: false
    property string errorMessage: ""
    property color accentColor: Theme.accent
    property bool editing: false
    readonly property string fullTableName: (root.schemaName.length > 0 ? root.schemaName + "." : "") + root.tableName
    readonly property int fieldCount: fieldsModel.count

    signal submitRequested(var entries)

    function openForAdd(schema, table, columns) {
        editing = false
        schemaName = schema || ""
        tableName = table || ""
        errorMessage = ""
        submitting = false
        fieldsModel.clear()

        for (var i = 0; i < columns.length; i++) {
            var column = columns[i]
            var columnName = ""
            var columnType = ""
            if (typeof column === "string") {
                columnName = column
            } else if (column) {
                columnName = column.name || ""
                columnType = column.type || ""
            }
            if (!columnName || columnName.length === 0) {
                continue
            }
            fieldsModel.append({
                "name": columnName,
                "type": columnType,
                "value": ""
            })
        }

        open()
        Qt.callLater(function() {
            var firstItem = fieldRepeater.itemAt(0)
            if (firstItem && firstItem.focusEditor) {
                firstItem.focusEditor()
            }
        })
    }

    function collectEntries() {
        var entries = []
        for (var i = 0; i < fieldsModel.count; i++) {
            var row = fieldsModel.get(i)
            entries.push({ "name": row.name, "value": row.value })
        }
        return entries
    }

    function clearAllValues() {
        for (var i = 0; i < fieldsModel.count; i++) {
            fieldsModel.setProperty(i, "value", "")
        }
    }

    function requestSubmit() {
        if (root.submitting) return
        root.errorMessage = ""
        root.submitRequested(root.collectEntries())
    }

    Keys.onPressed: function(event) {
        if ((event.modifiers & Qt.ControlModifier)
                && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            event.accepted = true
            root.requestSubmit()
        }
    }

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: 10
    }

    ListModel {
        id: fieldsModel
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            color: Theme.surfaceHighlight
            border.color: Theme.border
            border.width: 1
            implicitHeight: headerContent.implicitHeight + (Theme.spacingLarge * 2)

            ColumnLayout {
                id: headerContent
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                spacing: Theme.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 15
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: root.accentColor
                            font.bold: true
                            font.pixelSize: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: root.editing ? "Edit Row to " : "Add Row to "
                                color: Theme.textPrimary
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                text: root.schemaName.length > 0 ? root.schemaName : "default"
                                color: Theme.textSecondary
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                text: "."
                                color: Theme.textSecondary
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.tableName
                                color: root.accentColor
                                font.pixelSize: 20
                                font.bold: true
                                elide: Text.ElideMiddle
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.editing
                                  ? "Adjust values and save the row changes."
                                  : "Fill in the values to insert a new row."
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    AppButton {
                        text: "Close"
                        isPrimary: false
                        enabled: !root.submitting
                        onClicked: root.close()
                    }
                }

            }
        }

        ScrollView {
            id: bodyScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Item {
                width: Math.max(bodyScroll.availableWidth, 1)
                implicitHeight: bodyContent.implicitHeight + (Theme.spacingLarge * 2)

                ColumnLayout {
                    id: bodyContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingLarge
                    anchors.topMargin: Theme.spacingLarge
                    spacing: Theme.spacingLarge

                    Rectangle {
                        Layout.fillWidth: true
                        radius: Theme.radius
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.08)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
                        border.width: 1
                        implicitHeight: helperContent.implicitHeight + (Theme.spacingMedium * 2)

                        ColumnLayout {
                            id: helperContent
                            anchors.fill: parent
                            anchors.margins: Theme.spacingMedium
                            spacing: Theme.spacingSmall

                            Text {
                                Layout.fillWidth: true
                                text: "Input semantics"
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: Theme.spacingSmall

                                Rectangle {
                                    radius: Theme.radius
                                    color: Theme.surface
                                    border.color: Theme.border
                                    border.width: 1
                                    height: 24
                                    width: emptyTokenLabel.implicitWidth + (Theme.spacingMedium * 2)

                                    Text {
                                        id: emptyTokenLabel
                                        anchors.centerIn: parent
                                        text: "Empty -> DB default"
                                        color: Theme.textSecondary
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                Rectangle {
                                    radius: Theme.radius
                                    color: Theme.surface
                                    border.color: Theme.border
                                    border.width: 1
                                    height: 24
                                    width: nullTokenLabel.implicitWidth + (Theme.spacingMedium * 2)

                                    Text {
                                        id: nullTokenLabel
                                        anchors.centerIn: parent
                                        text: "NULL -> SQL null"
                                        color: Theme.textSecondary
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    GridLayout {
                        id: fieldsGrid
                        Layout.fillWidth: true
                        columns: root.width >= 760 ? 2 : 1
                        columnSpacing: Theme.spacingMedium
                        rowSpacing: Theme.spacingMedium

                        Repeater {
                            id: fieldRepeater
                            model: fieldsModel

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: fieldsGrid.columns > 1
                                    ? (fieldsGrid.width - fieldsGrid.columnSpacing) / 2
                                    : fieldsGrid.width
                                radius: Theme.radius
                                color: Theme.surface
                                border.width: 0
                                implicitHeight: fieldCardContent.implicitHeight + (Theme.spacingMedium * 2)

                                function focusEditor() {
                                    valueInput.forceActiveFocus()
                                }

                                ColumnLayout {
                                    id: fieldCardContent
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingMedium
                                    spacing: Theme.spacingSmall

                                    RowLayout {
                                        id: fieldMetaRow
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSmall

                                        Text {
                                            id: fieldNameLabel
                                            Layout.preferredWidth: Math.min(
                                                                       fieldNameLabel.implicitWidth,
                                                                       Math.max(
                                                                           0,
                                                                           fieldMetaRow.width - (fieldTypeLabel.visible
                                                                                                 ? (fieldTypeLabel.implicitWidth + fieldMetaRow.spacing)
                                                                                                 : 0)))
                                            text: model.name
                                            color: Theme.textPrimary
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            id: fieldTypeLabel
                                            Layout.alignment: Qt.AlignVCenter
                                            text: model.type || ""
                                            visible: text.length > 0
                                            color: Theme.textSecondary
                                            font.pixelSize: 11
                                            font.bold: false
                                        }
                                    }

                                    AppTextField {
                                        id: valueInput
                                        Layout.fillWidth: true
                                        accentColor: root.accentColor
                                        enabled: !root.submitting
                                        placeholderText: ""
                                        text: model.value
                                        onTextChanged: {
                                            fieldsModel.setProperty(index, "value", text)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.spacingSmall
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            implicitHeight: footerContent.implicitHeight + (Theme.spacingLarge * 2)

            ColumnLayout {
                id: footerContent
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                spacing: Theme.spacingMedium

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.errorMessage.length > 0 ? errorText.implicitHeight + (Theme.spacingMedium * 2) : 0
                    visible: root.errorMessage.length > 0
                    radius: Theme.radius
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.38)
                    border.width: 1

                    Text {
                        id: errorText
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        wrapMode: Text.WordWrap
                        text: root.errorMessage
                        color: Theme.error
                        font.pixelSize: 12
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium

                    AppButton {
                        text: "Clear Values"
                        isOutline: true
                        accentColor: root.accentColor
                        enabled: !root.submitting && root.fieldCount > 0
                        onClicked: root.clearAllValues()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Tip: Use Ctrl+Enter to submit quickly."
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    AppButton {
                        text: "Cancel"
                        isPrimary: false
                        enabled: !root.submitting
                        onClicked: root.close()
                    }

                    AppButton {
                        text: root.submitting
                              ? (root.editing ? "Saving..." : "Inserting...")
                              : (root.editing ? "Save Changes" : "Insert Row")
                        isPrimary: true
                        accentColor: root.accentColor
                        enabled: !root.submitting
                        onClicked: root.requestSubmit()
                    }
                }
            }
        }
    }
}
