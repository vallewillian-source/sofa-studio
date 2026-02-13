import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import sofa.ui
import "PostgresDdl.js" as PgDdl

Item {
    id: root
    focus: true

    property string schema: "public"
    property string tableName: ""
    property color accentColor: {
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

    property bool loading: false
    property bool ddlRunning: false
    property string errorMessage: ""
    property string requestTag: ""
    property string ddlBaseTag: ""
    property string ddlActiveTag: ""
    property var ddlStatements: []
    property int ddlIndex: -1
    property var ddlOnSuccess: null
    property var ddlOnError: null
    property string primaryKeyConstraintName: ""

    signal requestReloadTableData(string schema, string tableName)

    ListModel { id: columnsModel }

    function existingPkColumns() {
        var cols = []
        for (var i = 0; i < columnsModel.count; i++) {
            var row = columnsModel.get(i)
            if (row && row.isPrimaryKey === true) {
                cols.push(String(row.name))
            }
        }
        return cols
    }

    function loadStructure() {
        if (!schema || !tableName) return
        loading = true
        errorMessage = ""
        requestTag = "schema:" + schema + "." + tableName + ":" + Date.now()
        var ok = App.getTableSchemaAsync(schema, tableName, requestTag)
        if (!ok) {
            loading = false
            errorMessage = App.lastError
        }
    }

    function refreshAfterDDL() {
        loadStructure()
        requestReloadTableData(schema, tableName)
    }

    function runNextDdlStatement() {
        if (ddlIndex < 0 || ddlIndex >= ddlStatements.length) {
            ddlRunning = false
            ddlActiveTag = ""
            var cb = ddlOnSuccess
            ddlOnSuccess = null
            ddlOnError = null
            ddlStatements = []
            ddlIndex = -1
            if (cb) cb()
            return
        }

        ddlActiveTag = ddlBaseTag + ":" + ddlIndex
        var ok = App.runQueryAsync(String(ddlStatements[ddlIndex]), ddlActiveTag)
        if (!ok) {
            ddlRunning = false
            var err = App.lastError
            var ecb = ddlOnError
            ddlOnSuccess = null
            ddlOnError = null
            ddlStatements = []
            ddlIndex = -1
            ddlActiveTag = ""
            if (ecb) ecb(err)
        }
    }

    function runStatementsSequentially(statements, onSuccess, onError) {
        if (!statements || statements.length === 0) {
            if (onSuccess) onSuccess()
            return
        }
        ddlRunning = true
        errorMessage = ""
        ddlStatements = statements
        ddlIndex = 0
        ddlBaseTag = "ddl:" + schema + "." + tableName + ":" + Date.now()
        ddlOnSuccess = onSuccess
        ddlOnError = onError
        runNextDdlStatement()
    }

    function openAddColumnModal() {
        columnEditorModal.accentColor = root.accentColor
        columnEditorModal.openForAdd(schema, tableName, {
            "primaryKeyConstraintName": root.primaryKeyConstraintName,
            "existingPkColumns": root.existingPkColumns()
        })
    }

    function openEditColumnModal(columnRow) {
        columnEditorModal.accentColor = root.accentColor
        columnEditorModal.openForEdit(schema, tableName, columnRow, {
            "primaryKeyConstraintName": root.primaryKeyConstraintName,
            "existingPkColumns": root.existingPkColumns()
        })
    }

    function confirmDropColumn(columnRow) {
        if (!columnRow) return
        pendingDropColumnName = String(columnRow.name || "")
        pendingDropIsPrimaryKey = columnRow.isPrimaryKey === true
        dropConfirmError = ""
        dropConfirmPopup.open()
    }

    property string pendingDropColumnName: ""
    property bool pendingDropIsPrimaryKey: false
    property string dropConfirmError: ""

    ColumnEditorModal {
        id: columnEditorModal
        accentColor: root.accentColor

        onSubmitRequested: (payload) => {
            var statements = []
            if (payload.mode === "add") {
                statements = PgDdl.buildAddColumnStatements({
                    "schema": payload.schema,
                    "table": payload.table,
                    "primaryKeyConstraintName": root.primaryKeyConstraintName,
                    "existingPkColumns": root.existingPkColumns(),
                    "name": payload.name,
                    "type": payload.type,
                    "nullable": payload.nullable,
                    "defaultExpr": payload.defaultExpr,
                    "primaryKey": payload.primaryKey
                })
            } else {
                statements = PgDdl.buildEditColumnStatements({
                    "schema": payload.schema,
                    "table": payload.table,
                    "primaryKeyConstraintName": root.primaryKeyConstraintName,
                    "existingPkColumns": root.existingPkColumns(),
                    "originalName": payload.originalName,
                    "originalType": payload.originalType,
                    "originalNullable": payload.originalNullable,
                    "originalDefaultExpr": payload.originalDefaultExpr,
                    "originalPrimaryKey": payload.originalPrimaryKey,
                    "name": payload.name,
                    "type": payload.type,
                    "nullable": payload.nullable,
                    "defaultExpr": payload.defaultExpr,
                    "primaryKey": payload.primaryKey
                })
            }

            if (!statements || statements.length === 0) {
                columnEditorModal.submitting = false
                columnEditorModal.errorMessage = "Nothing to apply. Check column name/type."
                return
            }

            runStatementsSequentially(
                statements,
                () => {
                    columnEditorModal.submitting = false
                    columnEditorModal.errorMessage = ""
                    columnEditorModal.close()
                    refreshAfterDDL()
                },
                (err) => {
                    columnEditorModal.submitting = false
                    columnEditorModal.errorMessage = err
                }
            )
        }
    }

    Popup {
        id: dropConfirmPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        width: 420
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: Theme.spacingLarge
        implicitHeight: dropConfirmContent.implicitHeight + topPadding + bottomPadding

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 8
        }

        contentItem: ColumnLayout {
            id: dropConfirmContent
            width: dropConfirmPopup.availableWidth
            spacing: Theme.spacingMedium

            Text {
                Layout.fillWidth: true
                text: "Drop column?"
                color: Theme.textPrimary
                font.pixelSize: 15
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Drop column \"" + pendingDropColumnName + "\" from " + schema + "." + tableName + "?"
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: pendingDropIsPrimaryKey
                text: "This column is part of the primary key. The primary key will be updated."
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                visible: dropConfirmError.length > 0
                color: Theme.tintColor(Theme.background, Theme.error, 0.10)
                border.color: Theme.tintColor(Theme.border, Theme.error, 0.55)
                border.width: 1
                radius: Theme.radius

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingMedium
                    text: dropConfirmError
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "Cancel"
                    isPrimary: false
                    enabled: !ddlRunning
                    onClicked: dropConfirmPopup.close()
                }

                AppButton {
                    text: ddlRunning ? "Dropping..." : "Drop"
                    isPrimary: true
                    accentColor: Theme.error
                    enabled: !ddlRunning
                    onClicked: {
                        var statements = PgDdl.buildDropColumnStatements({
                            "schema": schema,
                            "table": tableName,
                            "primaryKeyConstraintName": root.primaryKeyConstraintName,
                            "existingPkColumns": root.existingPkColumns(),
                            "columnName": pendingDropColumnName,
                            "isPrimaryKey": pendingDropIsPrimaryKey
                        })
                        runStatementsSequentially(
                            statements,
                            () => {
                                dropConfirmPopup.close()
                                refreshAfterDDL()
                            },
                            (err) => {
                                dropConfirmError = err
                            }
                        )
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingLarge
                anchors.rightMargin: Theme.spacingLarge
                spacing: Theme.spacingMedium

                RowLayout {
                    spacing: 10

                    ColumnLayout {
                        spacing: 1

                        Text {
                            text: "Structure"
                            color: Theme.textPrimary
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: schema + "." + tableName
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    AppButton {
                        text: ""
                        icon.source: "qrc:/qt/qml/sofa/ui/assets/rotate-right-solid-full.svg"
                        isPrimary: false
                        isOutline: true
                        accentColor: root.accentColor
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 24
                        horizontalPadding: 0
                        verticalPadding: 0
                        iconSize: 12
                        enabled: !loading && !ddlRunning
                        tooltip: "Refresh structure"
                        onClicked: loadStructure()
                    }
                }

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "Add column"
                    icon.source: "qrc:/qt/qml/sofa/ui/assets/plus-solid-full.svg"
                    isPrimary: true
                    accentColor: root.accentColor
                    Layout.preferredHeight: 28
                    iconSize: 12
                    spacing: 5
                    enabled: !loading && !ddlRunning
                    onClicked: openAddColumnModal()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                visible: loading || errorMessage.length > 0
                color: "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingMedium

                    Text {
                        text: loading ? "Loading structure..." : "Error loading structure"
                        color: Theme.textPrimary
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Text {
                        visible: !loading && errorMessage.length > 0
                        text: errorMessage
                        color: Theme.textSecondary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.maximumWidth: 520
                    }

                    AppButton {
                        visible: !loading
                        text: "Try again"
                        isPrimary: true
                        accentColor: root.accentColor
                        onClicked: loadStructure()
                    }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                visible: !loading && errorMessage.length === 0
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingLarge
                        anchors.rightMargin: Theme.spacingLarge
                        spacing: Theme.spacingMedium

                        Text { text: "Name"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 220 }
                        Text { text: "Type"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 140 }
                        Text { text: "Nullable"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 90 }
                        Text { text: "Default value"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                        Text { text: "Primary key"; color: Theme.textSecondary; font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 100 }
                        Item { Layout.preferredWidth: 72 }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: columnsModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 44
                        color: index % 2 === 0 ? "transparent" : Theme.tintColor(Theme.background, root.accentColor, 0.03)
                        border.color: Theme.border
                        border.width: 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingLarge
                            anchors.rightMargin: Theme.spacingLarge
                            spacing: Theme.spacingMedium

                            Text {
                                text: String(model.name || "")
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.preferredWidth: 220
                            }

                            Text {
                                text: String(model.type || "")
                                color: Theme.textPrimary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.preferredWidth: 140
                            }

                            Text {
                                text: model.isNullable === true ? "true" : "false"
                                color: model.isNullable === true ? Theme.textSecondary : Theme.textPrimary
                                font.pixelSize: 12
                                Layout.preferredWidth: 90
                            }

                            Item {
                                Layout.fillWidth: true
                                height: parent.height

                                Text {
                                    id: defaultText
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    text: String(model.defaultValue || "")
                                    color: Theme.textSecondary
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }

                                ToolTip {
                                    visible: defaultMouse.containsMouse && String(model.defaultValue || "").length > 0
                                    text: String(model.defaultValue || "")
                                    delay: 400
                                    contentItem: Text { text: String(model.defaultValue || ""); color: Theme.textPrimary; font.pixelSize: 12 }
                                    background: Rectangle { color: Theme.surfaceHighlight; border.color: Theme.border; border.width: 1; radius: 4 }
                                }

                                MouseArea {
                                    id: defaultMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }

                            Text {
                                text: model.isPrimaryKey === true ? "true" : "false"
                                color: model.isPrimaryKey === true ? root.accentColor : Theme.textSecondary
                                font.pixelSize: 12
                                Layout.preferredWidth: 100
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.preferredWidth: 72
                                spacing: 6

                                Controls.Button {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    padding: 0
                                    enabled: !ddlRunning
                                    onClicked: root.openEditColumnModal(model)
                                    background: Rectangle { radius: 4; color: parent.hovered ? Theme.surfaceHighlight : "transparent" }
                                    contentItem: Text {
                                        text: "✎"
                                        color: parent.hovered ? Theme.textPrimary : Theme.textSecondary
                                        font.pixelSize: 14
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    ToolTip.visible: parent.hovered
                                    ToolTip.text: "Edit column"
                                }

                                Controls.Button {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    padding: 0
                                    enabled: !ddlRunning
                                    onClicked: root.confirmDropColumn(model)
                                    background: Rectangle { radius: 4; color: parent.hovered ? Theme.surfaceHighlight : "transparent" }
                                    contentItem: Text {
                                        text: "✕"
                                        color: parent.hovered ? Theme.error : Theme.textSecondary
                                        font.pixelSize: 14
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    ToolTip.visible: parent.hovered
                                    ToolTip.text: "Drop column"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: App

        function onTableSchemaFinished(tag, result) {
            if (tag !== root.requestTag) return
            root.loading = false
            root.errorMessage = ""
            columnsModel.clear()
            root.primaryKeyConstraintName = String(result.primaryKeyConstraintName || "")

            var cols = result.columns || []
            for (var i = 0; i < cols.length; i++) {
                var c = cols[i]
                columnsModel.append({
                    "name": c.name || "",
                    "type": c.type || "",
                    "isNullable": c.isNullable !== false,
                    "defaultValue": c.defaultValue || "",
                    "isPrimaryKey": c.isPrimaryKey === true
                })
            }
        }

        function onTableSchemaError(tag, error) {
            if (tag !== root.requestTag && root.requestTag.length > 0) return
            root.loading = false
            columnsModel.clear()
            root.errorMessage = error
        }

        function onSqlFinished(tag, result) {
            if (tag !== root.ddlActiveTag) return
            root.ddlIndex += 1
            root.runNextDdlStatement()
        }

        function onSqlError(tag, error) {
            if (tag !== root.ddlActiveTag) return
            root.ddlRunning = false
            var ecb = root.ddlOnError
            root.ddlOnSuccess = null
            root.ddlOnError = null
            root.ddlStatements = []
            root.ddlIndex = -1
            root.ddlActiveTag = ""
            if (ecb) ecb(error)
        }
    }
}
