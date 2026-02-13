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
        return Math.min(680, maxAllowed)
    }
    height: {
        if (!parent) return 640
        return Math.min(600, parent.height - (Theme.spacingXLarge * 2))
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
        if (!stmts || stmts.length === 0) return "-- No changes detected"
        return stmts.map((s) => s + ";").join("\n")
    }

    function resetDraftValues() {
        if (editing) {
            nameValue = originalName
            typeValue = originalType
            primaryKeyValue = originalPrimaryKey
            nullableValue = originalPrimaryKey ? false : originalNullable
            defaultExprValue = originalDefaultExpr
        } else {
            nameValue = ""
            typeValue = ""
            primaryKeyValue = false
            nullableValue = true
            defaultExprValue = ""
        }
    }

    function requestSubmit() {
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
                                text: root.editing ? "Edit Column on " : "Add Column to "
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
                                  ? "Adjust the column definition and save the schema changes."
                                  : "Configure the new column details before applying changes."
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
                            id: previewSql
                            Layout.fillWidth: true
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            text: {
                                // Keep explicit dependencies so preview always updates in both add/edit modes.
                                root.editing
                                root.schemaName
                                root.tableName
                                root.nameValue
                                root.typeValue
                                root.nullableValue
                                root.defaultExprValue
                                root.primaryKeyValue
                                root.originalName
                                root.originalType
                                root.originalNullable
                                root.originalDefaultExpr
                                root.originalPrimaryKey
                                root.primaryKeyConstraintName
                                root.existingPkColumns
                                return root.previewSqlText()
                            }
                            color: Theme.textPrimary
                            selectionColor: Theme.accent
                            selectedTextColor: "#FFFFFF"
                            background: Rectangle { color: "transparent" }
                            font.pixelSize: 11
                            font.family: Qt.platform.os === "osx" ? "Menlo" : "Monospace"
                            implicitHeight: Math.max(40, contentHeight)
                        }

                        SqlSyntaxHighlighter {
                            document: previewSql.textDocument
                            keywordColor: Theme.accentSecondary
                            stringColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[3], 0.55)
                            numberColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[8], 0.65)
                            commentColor: Theme.textSecondary
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.width >= 680 ? 2 : 1
                        columnSpacing: Theme.spacingMedium
                        rowSpacing: Theme.spacingMedium

                        Rectangle {
                            Layout.fillWidth: true
                            radius: Theme.radius
                            color: Theme.surface
                            border.width: 0
                            implicitHeight: nameCardContent.implicitHeight + (Theme.spacingMedium * 2)

                            ColumnLayout {
                                id: nameCardContent
                                anchors.fill: parent
                                anchors.margins: Theme.spacingMedium
                                spacing: Theme.spacingSmall

                                Text {
                                    text: "Name"
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                AppTextField {
                                    Layout.fillWidth: true
                                    accentColor: root.accentColor
                                    enabled: !root.submitting
                                    text: root.nameValue
                                    placeholderText: "column_name"
                                    onTextChanged: root.nameValue = text
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            radius: Theme.radius
                            color: Theme.surface
                            border.width: 0
                            implicitHeight: typeCardContent.implicitHeight + (Theme.spacingMedium * 2)

                            ColumnLayout {
                                id: typeCardContent
                                anchors.fill: parent
                                anchors.margins: Theme.spacingMedium
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
                                    placeholderText: "int4, text, uuid..."
                                    onTextChanged: root.typeValue = text
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.columnSpan: columns
                            radius: Theme.radius
                            color: Theme.surface
                            border.width: 0
                            implicitHeight: defaultCardContent.implicitHeight + (Theme.spacingMedium * 2)

                            ColumnLayout {
                                id: defaultCardContent
                                anchors.fill: parent
                                anchors.margins: Theme.spacingMedium
                                spacing: Theme.spacingSmall

                                Text {
                                    text: "Default Value (Expression)"
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                AppTextField {
                                    Layout.fillWidth: true
                                    accentColor: root.accentColor
                                    enabled: !root.submitting
                                    text: root.defaultExprValue
                                    placeholderText: "e.g. 0, 'active', now()"
                                    onTextChanged: root.defaultExprValue = text
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.columnSpan: columns
                            radius: Theme.radius
                            color: Theme.surface
                            border.width: 0
                            implicitHeight: constraintCardContent.implicitHeight + (Theme.spacingMedium * 2)

                            ColumnLayout {
                                id: constraintCardContent
                                anchors.fill: parent
                                anchors.margins: Theme.spacingMedium
                                spacing: Theme.spacingSmall

                                Text {
                                    text: "Constraints"
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                RowLayout {
                                    spacing: Theme.spacingXLarge

                                    CheckBox {
                                        enabled: !root.submitting && !root.primaryKeyValue
                                        text: "Nullable"
                                        checked: root.nullableValue
                                        onToggled: root.nullableValue = checked

                                        contentItem: Text {
                                            text: parent.text
                                            font.pixelSize: 13
                                            color: parent.enabled ? Theme.textPrimary : Theme.textSecondary
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: parent.indicator.width + parent.spacing
                                        }
                                    }

                                    CheckBox {
                                        enabled: !root.submitting
                                        text: "Primary Key"
                                        checked: root.primaryKeyValue
                                        onToggled: {
                                            root.primaryKeyValue = checked
                                            if (checked) {
                                                root.nullableValue = false
                                            }
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font.pixelSize: 13
                                            color: parent.enabled ? Theme.textPrimary : Theme.textSecondary
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: parent.indicator.width + parent.spacing
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
                spacing: Theme.spacingLarge

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.errorMessage.length > 0
                    Layout.preferredHeight: root.errorMessage.length > 0 ? footerErrorText.implicitHeight + (Theme.spacingMedium * 2) : 0
                    radius: Theme.radius
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.38)
                    border.width: 1

                    Text {
                        id: footerErrorText
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
                        text: "Reset Values"
                        isOutline: true
                        accentColor: root.accentColor
                        enabled: !root.submitting
                        onClicked: root.resetDraftValues()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Tip: Default value is treated as a raw SQL expression."
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
                              ? (root.editing ? "Saving..." : "Creating...")
                              : (root.editing ? "Save Changes" : "Add Column")
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
