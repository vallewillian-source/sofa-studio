import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui
import sofa.datagrid 1.0

ApplicationWindow {
    width: 1024
    height: 768
    visible: true
    title: qsTr("Sofa Studio")
    color: Theme.background
    
    ListModel {
        id: tabModel
        ListElement { title: "Home"; type: "home" }
    }
    
    function openTable(tableName) {
        // Check if already open
        for (var i = 0; i < tabModel.count; i++) {
            if (tabModel.get(i).title === "Table: " + tableName) {
                appTabs.currentIndex = i
                return
            }
        }
        tabModel.append({ "title": "Table: " + tableName, "type": "table", "tableName": tableName })
        appTabs.currentIndex = tabModel.count - 1
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left Sidebar
        AppSidebar {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.sidebarWidth
        }

        // Database Explorer
        DatabaseExplorer {
            Layout.fillHeight: true
            Layout.preferredWidth: 250
            visible: App.activeConnectionId !== -1
            onTableClicked: function(tableName) {
                openTable(tableName)
            }
        }

        // Main Content Area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Top Tabs
            AppTabs {
                id: appTabs
                Layout.fillWidth: true
                tabsModel: tabModel
            }
            
            // Content Area
            StackLayout {
                currentIndex: appTabs.currentIndex
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Repeater {
                    model: tabModel
                    
                    Loader {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        sourceComponent: model.type === "home" ? homeComponent : tableComponent
                        
                        // Pass properties to loaded item if needed
                        property string tableName: model.tableName || ""
                    }
                }
            }
        }
    }
    
    Component {
        id: homeComponent
        Rectangle {
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
    
    Component {
        id: tableComponent
        Rectangle {
            color: Theme.background
            
            DataGridEngine {
                id: gridEngine
                Component.onCompleted: loadMockData()
            }

            DataGrid {
                anchors.fill: parent
                engine: gridEngine
            }
        }
    }
}
