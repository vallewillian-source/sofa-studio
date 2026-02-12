import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui

Popup {
    id: root
    parent: Overlay.overlay
    width: 560
    height: Math.min(contentColumn.implicitHeight + 24, 620)
    x: Math.round((parent.width - width) / 2)
    y: Math.max(Theme.spacingXLarge, Math.round((parent.height - height) / 2))
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string schemaName: ""
    property string tableName: ""
    property bool submitting: false
    property string errorMessage: ""

    signal submitRequested(var entries)

    function openForAdd(schema, table, columns) {
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
    }

    function collectEntries() {
        var entries = []
        for (var i = 0; i < fieldsModel.count; i++) {
            var row = fieldsModel.get(i)
            entries.push({ "name": row.name, "value": row.value })
        }
        return entries
    }

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: 8
    }

    ListModel {
        id: fieldsModel
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingMedium

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Add Row"
                color: Theme.textPrimary
                font.pixelSize: 18
                font.bold: true
            }

            AppButton {
                text: "Close"
                isPrimary: false
                enabled: !root.submitting
                onClicked: root.close()
            }
        }

        Text {
            Layout.fillWidth: true
            color: Theme.textSecondary
            font.pixelSize: 12
            text: (root.schemaName.length > 0 ? root.schemaName + "." : "") + root.tableName
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: Math.max(parent.width, 1)
                spacing: Theme.spacingMedium

                Repeater {
                    model: fieldsModel

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: model.name
                                color: Theme.textPrimary
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                text: model.type || ""
                                visible: text.length > 0
                                color: Theme.textSecondary
                                opacity: 0.9
                                font.pixelSize: 11
                                font.bold: false
                            }
                        }

                        AppTextField {
                            Layout.fillWidth: true
                            accentColor: Theme.accent
                            enabled: !root.submitting
                            placeholderText: "Value (empty = DB default, NULL = null)"
                            text: model.value
                            onTextChanged: {
                                fieldsModel.setProperty(index, "value", text)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.errorMessage.length > 0 ? errorText.implicitHeight + 16 : 0
            visible: root.errorMessage.length > 0
            radius: Theme.radius
            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)
            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.35)
            border.width: 1

            Text {
                id: errorText
                anchors.fill: parent
                anchors.margins: Theme.spacingMedium
                wrapMode: Text.Wrap
                text: root.errorMessage
                color: Theme.error
                font.pixelSize: 12
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Item { Layout.fillWidth: true }

            AppButton {
                text: "Cancel"
                isPrimary: false
                enabled: !root.submitting
                onClicked: root.close()
            }

            AppButton {
                text: root.submitting ? "Submitting..." : "Submit"
                isPrimary: true
                enabled: !root.submitting
                onClicked: {
                    root.errorMessage = ""
                    root.submitRequested(root.collectEntries())
                }
            }
        }
    }
}
