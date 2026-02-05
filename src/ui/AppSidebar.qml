import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"
    property bool maximized: false
    property int radius: maximized ? 0 : 10
    
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: root.radius
        z: -1 // Ensure behind content
        
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.radius
            color: Theme.surface
            visible: parent.radius > 0
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.radius
            height: parent.radius
            color: Theme.surface
            visible: parent.radius > 0
        }
    }

    property int panelWidth: Theme.sidebarWidth
    readonly property int totalWidth: Theme.sidebarRailWidth + (panelOpen ? panelWidth : 0)
    width: totalWidth
    implicitWidth: totalWidth
    Layout.preferredWidth: totalWidth
    Layout.minimumWidth: Theme.sidebarRailWidth + (panelOpen ? Theme.sidebarMinWidth : 0)
    Layout.maximumWidth: Theme.sidebarRailWidth + (panelOpen ? Theme.sidebarMaxWidth : 0)
    signal tableClicked(string schema, string table)
    signal newQueryClicked()
    property string activeMenuId: "explorer"
    property bool panelOpen: false
    property var activeMenu: null
    property var primaryMenuModel: []
    property var secondaryMenuModel: []

    function registerMenu(menu, position) {
        if (position === "secondary") {
            secondaryMenuModel = secondaryMenuModel.concat([menu])
        } else {
            primaryMenuModel = primaryMenuModel.concat([menu])
        }
        updatePanelState()
    }

    function getMenuById(id) {
        for (var i = 0; i < primaryMenuModel.length; i++) {
            if (primaryMenuModel[i].id === id) return primaryMenuModel[i]
        }
        for (var j = 0; j < secondaryMenuModel.length; j++) {
            if (secondaryMenuModel[j].id === id) return secondaryMenuModel[j]
        }
        return null
    }

    function toggleMenu(menuId) {
        if (activeMenuId === menuId) {
            panelOpen = !panelOpen
        } else {
            activeMenuId = menuId
            panelOpen = true
        }
    }

    function updatePanelState() {
        activeMenu = getMenuById(activeMenuId)
        if (!activeMenu || !activeMenu.hasPanel) {
            panelOpen = false
        }
    }

    onActiveMenuIdChanged: {
        updatePanelState()
        if (activeMenu && activeMenu.hasPanel) {
            panelOpen = true
        }
    }

    Connections {
        target: App
        function onConnectionOpened(id) {
            root.activeMenuId = "explorer"
            root.panelOpen = true
        }
    }

    Component.onCompleted: {
        registerMenu({
            "id": "explorer",
            "title": "Explorer",
            "icon": "🗂",
            "hasPanel": true,
            "component": explorerComponent
        }, "primary")
        registerMenu({
            "id": "settings",
            "title": "Settings",
            "icon": "⚙",
            "hasPanel": false,
            "component": null
        }, "secondary")
        activeMenuId = "explorer"
        updatePanelState()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: Theme.sidebarRailWidth
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Repeater {
                    model: primaryMenuModel
                    delegate: Rectangle {
                        width: Theme.sidebarRailWidth
                        height: Theme.sidebarRailWidth
                        color: primaryMouseArea.containsMouse || root.activeMenuId === modelData.id ? Theme.surfaceHighlight : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: Theme.sidebarIconSize
                            color: root.activeMenuId === modelData.id ? Theme.textPrimary : Theme.textSecondary
                        }

                        MouseArea {
                            id: primaryMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.hasPanel) {
                                    root.toggleMenu(modelData.id)
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Repeater {
                    model: secondaryMenuModel
                    delegate: Rectangle {
                        width: Theme.sidebarRailWidth
                        height: Theme.sidebarRailWidth
                        color: secondaryMouseArea.containsMouse ? Theme.surfaceHighlight : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            font.pixelSize: Theme.sidebarIconSize
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: secondaryMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.ArrowCursor
                            onClicked: {}
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: panelOpen ? panelWidth : 0
            Layout.fillHeight: true
            color: "transparent"
            visible: panelOpen
            clip: true

            Loader {
                anchors.fill: parent
                sourceComponent: activeMenu && activeMenu.component ? activeMenu.component : null
            }
        }
    }

    Rectangle {
        width: 1
        height: parent.height
        color: Theme.border
        anchors.left: parent.left
        anchors.leftMargin: Theme.sidebarRailWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: panelOpen
    }

    Rectangle {
        width: 6
        height: parent.height
        color: "transparent"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: panelOpen

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            property real startGlobalX: 0
            property real startWidth: 0

            onPressed: (mouse) => {
                var point = mapToItem(null, mouse.x, mouse.y)
                startGlobalX = point.x
                startWidth = root.panelWidth
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return
                var point = mapToItem(null, mouse.x, mouse.y)
                var delta = point.x - startGlobalX
                var nextWidth = startWidth + delta
                
                if (nextWidth < Theme.sidebarMinWidth) {
                    nextWidth = Theme.sidebarMinWidth
                }
                if (nextWidth > Theme.sidebarMaxWidth) {
                    nextWidth = Theme.sidebarMaxWidth
                }
                root.panelWidth = nextWidth
            }
        }
    }

    Rectangle {
        width: 1
        height: parent.height
        color: Theme.border
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    Component {
        id: explorerComponent
        DatabaseExplorer {
            anchors.fill: parent
            onTableClicked: (schema, table) => root.tableClicked(schema, table)
            onNewQueryClicked: root.newQueryClicked()
        }
    }
}
