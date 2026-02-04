import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui

ApplicationWindow {
    width: 1024
    height: 768
    visible: true
    title: qsTr("Sofa Studio")
    color: Theme.background

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left Sidebar
        AppSidebar {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.sidebarWidth
        }

        // Main Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Top Tabs
            AppTabs {
                Layout.fillWidth: true
            }

            // Content Area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.background
                
                Column {
                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        text: qsTr("Boot OK")
                        font.pixelSize: 24
                        color: Theme.textPrimary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    AppButton {
                        text: "Test Command"
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: {
                            App.executeCommand("test.hello")
                        }
                    }
                }
            }
        }
    }
}
