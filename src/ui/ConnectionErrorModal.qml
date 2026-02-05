import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: root
    parent: Overlay.overlay
    width: 400
    height: Math.min(contentColumn.implicitHeight + 40, 500)
    x: Math.round((parent.width - width) / 2)
    y: Math.max(Theme.spacingXLarge, Math.round((parent.height - height) / 2))
    padding: 20
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string errorMessage: ""
    property int connectionId: -1

    signal editRequested(int id)
    signal closed()

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: 8
        layer.enabled: true
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: Theme.spacingLarge

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Text {
                text: "⚠️"
                font.pixelSize: 24
            }

            Text {
                text: "Connection Error"
                font.pixelSize: 18
                font.bold: true
                color: Theme.error
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(errorText.implicitHeight + 20, 200)
            color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)
            radius: 4
            border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2)

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                clip: true

                Text {
                    id: errorText
                    width: parent.width
                    text: root.errorMessage
                    color: Theme.textPrimary
                    font.family: "Monospace"
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingMedium
            spacing: Theme.spacingMedium

            Item { Layout.fillWidth: true }

            Button {
                text: "Cancel"
                onClicked: {
                    root.close()
                    root.closed()
                }
            }

            Button {
                text: "Edit Connection"
                highlighted: true
                onClicked: {
                    root.editRequested(root.connectionId)
                    root.close()
                }
            }
        }
    }
}
