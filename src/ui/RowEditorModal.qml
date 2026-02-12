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
    closePolicy: Popup.NoAutoClose

    property string schemaName: ""
    property string tableName: ""
    property bool submitting: false
    property string errorMessage: ""
    property color accentColor: Theme.accent
    property bool editing: false
    property var originalRowValues: []
    readonly property color notNullMarkerColor: Qt.rgba(
                                                     (Theme.error.r * 0.82) + (root.accentColor.r * 0.18),
                                                     (Theme.error.g * 0.82) + (root.accentColor.g * 0.18),
                                                     (Theme.error.b * 0.82) + (root.accentColor.b * 0.18),
                                                     1.0)
    readonly property string fullTableName: (root.schemaName.length > 0 ? root.schemaName + "." : "") + root.tableName
    readonly property int fieldCount: fieldsModel.count

    signal submitRequested(var entries)

    function openForAdd(schema, table, columns) {
        editing = false
        originalRowValues = []
        schemaName = schema || ""
        tableName = table || ""
        errorMessage = ""
        submitting = false
        fieldsModel.clear()

        for (var i = 0; i < columns.length; i++) {
            var column = columns[i]
            var columnName = ""
            var columnType = ""
            var columnDefaultValue = ""
            var columnIsNullable = true
            if (typeof column === "string") {
                columnName = column
            } else if (column) {
                columnName = column.name || ""
                columnType = column.type || ""
                columnDefaultValue = column.defaultValue || ""
                columnIsNullable = column.isNullable !== false
            }
            if (!columnName || columnName.length === 0) {
                continue
            }
            fieldsModel.append({
                "name": columnName,
                "type": columnType,
                "defaultValue": columnDefaultValue,
                "notNull": !columnIsNullable,
                "initialValue": "",
                "originalRawValue": null,
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

    function openForEdit(schema, table, columns, rowValues) {
        editing = true
        schemaName = schema || ""
        tableName = table || ""
        errorMessage = ""
        submitting = false
        fieldsModel.clear()

        var values = rowValues || []
        originalRowValues = values.slice(0)

        for (var i = 0; i < columns.length; i++) {
            var column = columns[i]
            var columnName = ""
            var columnType = ""
            var columnDefaultValue = ""
            var columnIsNullable = true
            if (typeof column === "string") {
                columnName = column
            } else if (column) {
                columnName = column.name || ""
                columnType = column.type || ""
                columnDefaultValue = column.defaultValue || ""
                columnIsNullable = column.isNullable !== false
            }
            if (!columnName || columnName.length === 0) {
                continue
            }

            var originalRawValue = (i < values.length) ? values[i] : null
            var displayValue = (originalRawValue === null || originalRawValue === undefined) ? "" : String(originalRawValue)

            fieldsModel.append({
                "name": columnName,
                "type": columnType,
                "defaultValue": columnDefaultValue,
                "notNull": !columnIsNullable,
                "initialValue": displayValue,
                "originalRawValue": originalRawValue,
                "value": displayValue
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
            entries.push({
                "name": row.name,
                "value": row.value,
                "originalValue": row.originalRawValue
            })
        }
        return entries
    }

    function hasUnsavedChanges() {
        for (var i = 0; i < fieldsModel.count; i++) {
            var row = fieldsModel.get(i)
            var currentValue = row.value === null || row.value === undefined ? "" : String(row.value)
            var initialValue = row.initialValue === null || row.initialValue === undefined ? "" : String(row.initialValue)
            if (currentValue !== initialValue) {
                return true
            }
        }
        return false
    }

    function clearAllValues() {
        for (var i = 0; i < fieldsModel.count; i++) {
            fieldsModel.setProperty(i, "value", "")
        }
    }

    function quoteIdentifier(name) {
        return "\"" + String(name).replace(/"/g, "\"\"") + "\""
    }

    function quoteSqlStringLiteral(value) {
        return "'" + String(value).replace(/'/g, "''") + "'"
    }

    function buildPreviewSql() {
        if (!tableName || tableName.length === 0) return ""

        var target = schemaName && schemaName.length > 0
            ? quoteIdentifier(schemaName) + "." + quoteIdentifier(tableName)
            : quoteIdentifier(tableName)

        if (editing) {
            var assignments = []
            var conditions = []
            for (var e = 0; e < fieldsModel.count; e++) {
                var editRow = fieldsModel.get(e)
                var valueText = String(editRow.value === null || editRow.value === undefined ? "" : editRow.value)
                var trimmedEdit = valueText.trim()
                var initialText = String(editRow.initialValue === null || editRow.initialValue === undefined ? "" : editRow.initialValue)
                var quotedName = quoteIdentifier(editRow.name)

                if (valueText !== initialText) {
                    if (trimmedEdit.toUpperCase() === "NULL") {
                        assignments.push(quotedName + " = NULL")
                    } else {
                        assignments.push(quotedName + " = " + quoteSqlStringLiteral(valueText))
                    }
                }

                var originalValue = editRow.originalRawValue
                if (originalValue === null || originalValue === undefined) {
                    conditions.push(quotedName + " IS NULL")
                } else if (typeof originalValue === "number") {
                    conditions.push(quotedName + " = " + String(originalValue))
                } else if (typeof originalValue === "boolean") {
                    conditions.push(quotedName + " = " + (originalValue ? "TRUE" : "FALSE"))
                } else {
                    conditions.push(quotedName + " = " + quoteSqlStringLiteral(String(originalValue)))
                }
            }

            if (assignments.length === 0) {
                return "-- No changes detected."
            }
            if (conditions.length === 0) {
                return ""
            }
            return "UPDATE " + target + " SET " + assignments.join(", ") + " WHERE " + conditions.join(" AND ") + ";"
        }

        var quotedCols = []
        var quotedVals = []
        for (var i = 0; i < fieldsModel.count; i++) {
            var row = fieldsModel.get(i)
            var rawValue = row.value
            if (rawValue === null || rawValue === undefined) continue

            var rawText = String(rawValue)
            var trimmed = rawText.trim()
            if (trimmed.length === 0) continue

            quotedCols.push(quoteIdentifier(row.name))
            if (trimmed.toUpperCase() === "NULL") {
                quotedVals.push("NULL")
            } else {
                quotedVals.push(quoteSqlStringLiteral(rawText))
            }
        }

        if (quotedCols.length === 0) {
            return "INSERT INTO " + target + " DEFAULT VALUES;"
        }
        return "INSERT INTO " + target + " (" + quotedCols.join(", ") + ") VALUES (" + quotedVals.join(", ") + ");"
    }

    function requestSubmit() {
        if (root.submitting) return
        root.errorMessage = ""
        root.submitRequested(root.collectEntries())
    }

    function requestCloseConfirmation() {
        if (root.submitting) return
        if (!root.hasUnsavedChanges()) {
            root.close()
            return
        }
        closeConfirmPopup.open()
    }

    function confirmAndClose() {
        closeConfirmPopup.close()
        root.close()
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
                        onClicked: root.requestCloseConfirmation()
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Text {
                            Layout.fillWidth: true
                            text: "SQL preview"
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            font.bold: true
                        }

                        TextArea {
                            id: previewSqlText
                            Layout.fillWidth: true
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            text: root.buildPreviewSql()
                            color: Theme.textPrimary
                            selectionColor: Theme.accent
                            selectedTextColor: "#FFFFFF"
                            background: Rectangle { color: "transparent" }
                            font.pixelSize: 11
                            font.family: Qt.platform.os === "osx" ? "Menlo" : "Monospace"
                            implicitHeight: Math.max(40, contentHeight)
                        }

                        SqlSyntaxHighlighter {
                            document: previewSqlText.textDocument
                            keywordColor: Theme.accentSecondary
                            stringColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[3], 0.55)
                            numberColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[8], 0.65)
                            commentColor: Theme.textSecondary
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
                                            id: notNullMarker
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "*"
                                            visible: model.notNull === true
                                            color: root.notNullMarkerColor
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        Text {
                                            id: fieldNameLabel
                                            Layout.preferredWidth: Math.min(
                                                                       fieldNameLabel.implicitWidth,
                                                                       Math.max(
                                                                           0,
                                                                           fieldMetaRow.width
                                                                           - (notNullMarker.visible
                                                                                ? (notNullMarker.implicitWidth + fieldMetaRow.spacing)
                                                                                : 0)
                                                                           - (fieldTypeLabel.visible
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
                                        placeholderText: model.defaultValue || ""
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
                        onClicked: root.requestCloseConfirmation()
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

    Popup {
        id: closeConfirmPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        width: 360
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: Theme.spacingLarge
        implicitHeight: confirmContent.implicitHeight + topPadding + bottomPadding

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 8
        }

        contentItem: ColumnLayout {
            id: confirmContent
            width: closeConfirmPopup.availableWidth
            spacing: Theme.spacingMedium

            Text {
                Layout.fillWidth: true
                text: "Close and discard changes?"
                color: Theme.textPrimary
                font.pixelSize: 15
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Any values typed in this form will be lost."
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "Keep Editing"
                    isPrimary: false
                    onClicked: closeConfirmPopup.close()
                }

                AppButton {
                    text: "Discard"
                    isPrimary: true
                    accentColor: root.accentColor
                    onClicked: root.confirmAndClose()
                }
            }
        }
    }
}
