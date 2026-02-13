import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui
import "PostgresDdl.js" as PgDdl

Popup {
    id: root
    parent: Overlay.overlay
    width: {
        if (!parent) return 720
        var maxAllowed = Math.max(420, parent.width - (Theme.spacingXLarge * 2))
        return Math.min(820, maxAllowed)
    }
    height: {
        if (!parent) return 640
        return Math.min(720, parent.height - (Theme.spacingXLarge * 2))
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
    property color accentColor: Theme.accent
    property bool submitting: false
    property string errorMessage: ""

    // Context for PK handling / preview
    property string primaryKeyConstraintName: ""
    property var existingPkColumns: []

    // Mode + original values
    property bool editing: false
    property string originalName: ""
    property string originalType: ""
    property bool originalNullable: true
    property string originalDefaultExpr: ""
    property bool originalPrimaryKey: false

    // Draft values
    property string nameValue: ""
    property string typeValue: ""
    property bool nullableValue: true
    property string defaultExprValue: ""
    property bool primaryKeyValue: false

    signal submitRequested(var payload)

    function openForAdd(schema, table, context) {
        editing = false
        schemaName = schema || ""
        tableName = table || ""
        errorMessage = ""
        submitting = false

        primaryKeyConstraintName = (context && context.primaryKeyConstraintName) ? context.primaryKeyConstraintName : ""
        existingPkColumns = (context && context.existingPkColumns) ? context.existingPkColumns : []

        originalName = ""
        originalType = ""
        originalNullable = true
        originalDefaultExpr = ""
        originalPrimaryKey = false

        nameValue = ""
        typeValue = ""
        nullableValue = true
        defaultExprValue = ""
        primaryKeyValue = false
        open()
    }

    function openForEdit(schema, table, column, context) {
        editing = true
        schemaName = schema || ""
        tableName = table || ""
        errorMessage = ""
        submitting = false

        primaryKeyConstraintName = (context && context.primaryKeyConstraintName) ? context.primaryKeyConstraintName : ""
        existingPkColumns = (context && context.existingPkColumns) ? context.existingPkColumns : []

        originalName = (column && column.name) ? String(column.name) : ""
        originalType = (column && column.type) ? String(column.type) : ""
        originalNullable = column && column.isNullable === true
        originalDefaultExpr = (column && column.defaultValue) ? String(column.defaultValue) : ""
        originalPrimaryKey = column && column.isPrimaryKey === true

        nameValue = originalName
        typeValue = originalType
        nullableValue = originalPrimaryKey ? false : originalNullable
        defaultExprValue = originalDefaultExpr
        primaryKeyValue = originalPrimaryKey
        open()
    }

    function effectiveNullable() {
        return primaryKeyValue ? false : nullableValue
    }

    function buildPreviewStatements() {
        var payload = {
            schema: schemaName,
            table: tableName,
            primaryKeyConstraintName: primaryKeyConstraintName,
            existingPkColumns: existingPkColumns,
            name: nameValue,
            type: typeValue,
            nullable: effectiveNullable(),
            defaultExpr: defaultExprValue,
            primaryKey: primaryKeyValue,
            originalName: originalName,
            originalType: originalType,
            originalNullable: originalNullable,
            originalDefaultExpr: originalDefaultExpr,
            originalPrimaryKey: originalPrimaryKey
        }
        return editing ? PgDdl.buildEditColumnStatements(payload) : PgDdl.buildAddColumnStatements(payload)
    }

    function previewSqlText() {
        var stmts = buildPreviewStatements()
        if (!stmts || stmts.length === 0) return ""
        return stmts.map((s) => s + ";").join("\n")
    }

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: 10
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingLarge
                anchors.rightMargin: Theme.spacingLarge
                spacing: Theme.spacingMedium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: root.editing ? "Edit column" : "Add column"
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: (schemaName.length > 0 ? schemaName + "." : "") + tableName
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                AppButton {
                    text: "×"
                    isPrimary: false
                    isOutline: false
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    horizontalPadding: 0
                    verticalPadding: 0
                    enabled: !root.submitting
                    contentItem: Text {
                        text: "×"
                        color: Theme.textPrimary
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.close()
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Item {
                width: Math.max(parent.width, 1)
                implicitHeight: formContent.implicitHeight + (Theme.spacingLarge * 2)

                ColumnLayout {
                    id: formContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingLarge
                    anchors.topMargin: Theme.spacingLarge
                    spacing: Theme.spacingLarge

                    Rectangle {
                        Layout.fillWidth: true
                        color: Theme.tintColor(Theme.background, root.accentColor, 0.06)
                        border.color: Theme.tintColor(Theme.border, root.accentColor, 0.35)
                        border.width: 1
                        radius: Theme.radius
                        visible: root.errorMessage.length > 0

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingMedium
                            text: root.errorMessage
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Text {
                            text: "Column name"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        AppTextField {
                            Layout.fillWidth: true
                            accentColor: root.accentColor
                            enabled: !root.submitting
                            text: root.nameValue
                            onTextChanged: root.nameValue = text
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Text {
                            text: "Type"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        AppTextField {
                            Layout.fillWidth: true
                            accentColor: root.accentColor
                            enabled: !root.submitting
                            text: root.typeValue
                            placeholderText: "int4, text, uuid, numeric(10,2)..."
                            onTextChanged: root.typeValue = text
                        }
                    }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingLarge

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Text {
                            text: "Nullable"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        CheckBox {
                            enabled: !root.submitting && !root.primaryKeyValue
                            text: root.primaryKeyValue ? "false (primary key)" : (root.nullableValue ? "true" : "false")
                            checked: root.nullableValue
                            onToggled: root.nullableValue = checked
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Text {
                            text: "Primary key"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.bold: true
                        }

                        CheckBox {
                            enabled: !root.submitting
                            text: root.primaryKeyValue ? "true" : "false"
                            checked: root.primaryKeyValue
                            onToggled: {
                                root.primaryKeyValue = checked
                                if (checked) {
                                    root.nullableValue = false
                                }
                            }
                        }
                    }
                }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                    Text {
                        text: "Default value"
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.bold: true
                    }

                    AppTextField {
                        Layout.fillWidth: true
                        accentColor: root.accentColor
                        enabled: !root.submitting
                        text: root.defaultExprValue
                        placeholderText: "SQL expression (e.g. 0, 'abc', NOW())"
                        onTextChanged: root.defaultExprValue = text
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    Text {
                        text: "SQL preview"
                        color: Theme.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                    }

                    TextArea {
                        id: previewSql
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        text: root.previewSqlText()
                        color: Theme.textPrimary
                        selectionColor: root.accentColor
                        selectedTextColor: "#FFFFFF"
                        background: Rectangle { color: "transparent" }
                        font.pixelSize: 11
                        font.family: Qt.platform.os === "osx" ? "Menlo" : "Monospace"
                        implicitHeight: Math.max(54, contentHeight)
                    }

                    SqlSyntaxHighlighter {
                        document: previewSql.textDocument
                        keywordColor: root.accentColor
                        stringColor: Theme.tintColor(Theme.textPrimary, root.accentColor, 0.35)
                        numberColor: Theme.tintColor(Theme.textPrimary, root.accentColor, 0.55)
                        commentColor: Theme.textSecondary
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
            implicitHeight: footerRow.implicitHeight + (Theme.spacingMedium * 2)

            RowLayout {
                id: footerRow
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingLarge
                anchors.rightMargin: Theme.spacingLarge
                anchors.topMargin: Theme.spacingMedium
                anchors.bottomMargin: Theme.spacingMedium
                spacing: Theme.spacingMedium

                AppButton {
                    text: "Cancel"
                    isPrimary: false
                    enabled: !root.submitting
                    onClicked: root.close()
                }

                Item { Layout.fillWidth: true }

                AppButton {
                    text: root.submitting ? "Saving..." : "Save"
                    isPrimary: true
                    accentColor: root.accentColor
                    enabled: !root.submitting
                    onClicked: {
                        var payload = {
                            mode: root.editing ? "edit" : "add",
                            schema: root.schemaName,
                            table: root.tableName,
                            primaryKeyConstraintName: root.primaryKeyConstraintName,
                            existingPkColumns: root.existingPkColumns,
                            name: root.nameValue,
                            type: root.typeValue,
                            nullable: root.effectiveNullable(),
                            defaultExpr: root.defaultExprValue,
                            primaryKey: root.primaryKeyValue,
                            originalName: root.originalName,
                            originalType: root.originalType,
                            originalNullable: root.originalNullable,
                            originalDefaultExpr: root.originalDefaultExpr,
                            originalPrimaryKey: root.originalPrimaryKey
                        }
                        root.errorMessage = ""
                        root.submitting = true
                        root.submitRequested(payload)
                    }
                }
            }
        }
    }
}
