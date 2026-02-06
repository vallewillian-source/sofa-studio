import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: control
    property var tabsModel: null // ListModel
    property alias currentIndex: tabBar.currentIndex
    property alias count: tabBar.count
    property int dragIndex: -1
    property int dragThreshold: 10
    signal requestCloseTab(int index)
    signal requestCloseAllTabs()
    signal requestCloseOthers(int index)
    signal requestCloseTabsToRight(int index)
    signal newQueryClicked()
    readonly property var avatarColors: Theme.connectionAvatarColors
    property string activeConnectionName: {
        var currentId = App.activeConnectionId
        if (currentId === -1) {
            return ""
        }
        
        var conns = App.connections
        for (var i = 0; i < conns.length; i++) {
            if (conns[i].id === currentId) {
                return conns[i].name
            }
        }
        return ""
    }
    property string activeConnectionColor: {
        var currentId = App.activeConnectionId
        if (currentId === -1) {
            return ""
        }
        
        var conns = App.connections
        for (var i = 0; i < conns.length; i++) {
            if (conns[i].id === currentId) {
                return conns[i].color || ""
            }
        }
        return ""
    }
    readonly property color tabAccentColor: App.activeConnectionId === -1 ? Theme.accent : getAvatarColor(activeConnectionName, activeConnectionColor)

    function getAvatarColor(name, colorValue) {
        if (colorValue && colorValue.length > 0) return colorValue
        if (!name) return avatarColors[0]
        var hash = 0
        for (var i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash)
        }
        var index = Math.abs(hash % avatarColors.length)
        return avatarColors[index]
    }

    function moveTab(from, to) {
        if (!control.tabsModel) return from
        if (from === to) return from
        if (from < 0 || to < 0 || from >= control.tabsModel.count || to >= control.tabsModel.count) return from
        if (control.tabsModel.get(from).type === "home") return from

        var newIndex = to
        if (control.tabsModel.get(to).type === "home") {
            newIndex = 1
        }
        if (newIndex === from) return from

        var current = tabBar.currentIndex
        control.tabsModel.move(from, newIndex, 1)

        if (current === from) {
            tabBar.currentIndex = newIndex
        } else if (from < current && newIndex >= current) {
            tabBar.currentIndex = current - 1
        } else if (from > current && newIndex <= current) {
            tabBar.currentIndex = current + 1
        }

        return newIndex
    }

    function indexFromPosition(x) {
        if (!tabBar) return -1
        for (var i = 0; i < tabBar.count; i++) {
            var item = tabBar.itemAt(i)
            if (!item) continue
            var mid = item.x + item.width / 2
            if (x < mid) return i
        }
        return Math.max(0, tabBar.count - 1)
    }

    function boundaryBetween(index) {
        if (!tabBar) return null
        if (index < 0 || index >= tabBar.count - 1) return null
        var left = tabBar.itemAt(index)
        var right = tabBar.itemAt(index + 1)
        if (!left || !right) return null
        var leftEdge = left.x + left.width
        var rightEdge = right.x
        return (leftEdge + rightEdge) / 2
    }

    function indexWithHysteresis(currentIndex, x) {
        var targetIndex = indexFromPosition(x)
        if (targetIndex === -1 || targetIndex === currentIndex) return currentIndex

        if (targetIndex > currentIndex) {
            var rightBoundary = boundaryBetween(currentIndex)
            if (rightBoundary === null) return currentIndex
            if (x < rightBoundary + dragThreshold) return currentIndex
            return currentIndex + 1
        }

        var leftBoundary = boundaryBetween(targetIndex)
        if (leftBoundary === null) return currentIndex
        if (x > leftBoundary - dragThreshold) return currentIndex
        return currentIndex - 1
    }
    
    implicitHeight: Theme.tabBarHeight
    color: Theme.background
    border.color: Theme.border
    border.width: 1

    // Border only bottom
    Rectangle {
        width: parent.width
        height: 1
        color: Theme.border
        anchors.bottom: parent.bottom
        z: 2
    }

    AppMenu {
        id: contextMenu
        property int targetIndex: -1
        
        Controls.MenuItem {
            text: "Close Tab"
            visible: contextMenu.targetIndex !== -1 && control.tabsModel && control.tabsModel.get(contextMenu.targetIndex).type !== "home"
            height: visible ? implicitHeight : 0
            onTriggered: control.requestCloseTab(contextMenu.targetIndex)
        }

        Controls.MenuItem {
            text: "Close All Tabs"
            onTriggered: control.requestCloseAllTabs()
        }

        Controls.MenuItem {
            text: "Close Others"
            enabled: contextMenu.targetIndex !== -1
            onTriggered: control.requestCloseOthers(contextMenu.targetIndex)
        }

        Controls.MenuItem {
            text: "Close To the Right"
            enabled: contextMenu.targetIndex !== -1
            onTriggered: control.requestCloseTabsToRight(contextMenu.targetIndex)
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.targetIndex = -1
                contextMenu.popup()
            }
        }
        z: 0
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Controls.Button {
            id: scrollLeftBtn
            Layout.preferredWidth: tabScroll.contentWidth > tabScroll.width ? 24 : 0
            Layout.fillHeight: true
            flat: true
            visible: tabScroll.contentWidth > tabScroll.width
            contentItem: Text {
                text: "‹"
                font.pixelSize: 18
                color: scrollLeftBtn.hovered ? Theme.textPrimary : Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                var maxX = Math.max(0, tabScroll.contentWidth - tabScroll.width)
                tabScroll.contentX = Math.max(0, tabScroll.contentX - 120)
                if (tabScroll.contentX > maxX) tabScroll.contentX = maxX
            }
        }

        Flickable {
            id: tabScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: tabBar.contentWidth
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    var delta = 0
                    if (wheel.angleDelta.x !== 0) {
                        delta = -wheel.angleDelta.x
                    } else if (wheel.angleDelta.y !== 0) {
                        delta = -wheel.angleDelta.y
                    }
                    if (delta === 0) return
                    var maxX = Math.max(0, tabScroll.contentWidth - tabScroll.width)
                    var nextX = tabScroll.contentX + delta
                    if (nextX < 0) nextX = 0
                    if (nextX > maxX) nextX = maxX
                    tabScroll.contentX = nextX
                }
            }

            Controls.TabBar {
                id: tabBar
                width: contentWidth
                height: parent.height
                background: null // Transparent
                
                Repeater {
                    model: control.tabsModel
                    
                    Controls.TabButton {
                    id: tabBtn
                    width: implicitWidth + 20
                    property bool dragging: false
                    
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        drag.axis: Drag.XAxis
                        drag.target: null
                        preventStealing: true
                        onPressed: {
                            if (closeMouseArea.containsMouse) {
                                mouse.accepted = false
                                return
                            }
                            if (model.type === "home") return
                            tabBar.currentIndex = index
                            tabBtn.dragging = true
                            control.dragIndex = index
                        }
                        onClicked: {
                            if (closeMouseArea.containsMouse) {
                                mouse.accepted = false
                                return
                            }
                            tabBar.currentIndex = index
                        }
                        onPositionChanged: {
                            if (!tabBtn.dragging || control.dragIndex === -1) return
                            var pos = tabBtn.mapToItem(tabBar, mouse.x, mouse.y)
                            var nextIndex = control.indexWithHysteresis(control.dragIndex, pos.x)
                            if (nextIndex === control.dragIndex) return
                            var newIndex = control.moveTab(control.dragIndex, nextIndex)
                            control.dragIndex = newIndex
                        }
                        onReleased: {
                            tabBtn.dragging = false
                            if (control.dragIndex === index) {
                                control.dragIndex = -1
                            }
                        }
                        onCanceled: {
                            tabBtn.dragging = false
                            if (control.dragIndex === index) {
                                control.dragIndex = -1
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        cursorShape: Qt.ArrowCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                contextMenu.targetIndex = index
                                contextMenu.popup()
                            }
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 8
                        
                        Item {
                            Layout.preferredWidth: model.type === "table" ? 14 : 0
                            Layout.preferredHeight: model.type === "table" ? 14 : 0
                            visible: model.type === "table"

                            Image {
                                id: tableTabIcon
                                anchors.fill: parent
                                source: model.type === "table" ? "assets/table-list-solid-full.svg" : ""
                                sourceSize.width: 14
                                sourceSize.height: 14
                                visible: false
                                opacity: 1
                            }

                            ColorOverlay {
                                anchors.fill: tableTabIcon
                                source: tableTabIcon
                                visible: model.type === "table"
                                color: "#FFFFFF"
                                opacity: 0.7
                            }
                        }

                        Item {
                            Layout.preferredWidth: model.type === "sql" ? 14 : 0
                            Layout.preferredHeight: model.type === "sql" ? 14 : 0
                            visible: model.type === "sql"

                            Image {
                                id: sqlTabIcon
                                anchors.fill: parent
                                source: model.type === "sql" ? "assets/database-solid-full.svg" : ""
                                sourceSize.width: 14
                                sourceSize.height: 14
                                visible: false
                                opacity: 1
                            }

                            ColorOverlay {
                                anchors.fill: sqlTabIcon
                                source: sqlTabIcon
                                visible: model.type === "sql"
                                color: "#FFFFFF"
                                opacity: 0.7
                            }
                        }

                        Item {
                            Layout.preferredWidth: model.type === "connection_form" ? 14 : 0
                            Layout.preferredHeight: model.type === "connection_form" ? 14 : 0
                            visible: model.type === "connection_form"

                            Image {
                                id: connectionTabIcon
                                anchors.fill: parent
                                source: model.type === "connection_form" ? "assets/plug-solid-full.svg" : ""
                                sourceSize.width: 14
                                sourceSize.height: 14
                                visible: false
                                opacity: 1
                            }

                            ColorOverlay {
                                anchors.fill: connectionTabIcon
                                source: connectionTabIcon
                                visible: model.type === "connection_form"
                                color: "#FFFFFF"
                                opacity: 0.7
                            }
                        }

                        Text {
                            text: model.title
                            font: tabBtn.font
                            opacity: tabBtn.enabled ? 1.0 : 0.3
                            color: tabBtn.checked ? Theme.textPrimary : Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            Layout.maximumWidth: 200
                        }
                        
                        // Close Button
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 2
                            color: closeMouseArea.containsMouse ? Theme.surfaceHighlight : "transparent"
                            visible: model.type !== "home" // Home tab cannot be closed
                            
                            Text {
                                anchors.centerIn: parent
                                text: "×" // Multiplication sign looks better than X
                                color: tabBtn.checked ? Theme.textPrimary : Theme.textSecondary
                                font.pixelSize: 14
                            }
                            
                            MouseArea {
                                id: closeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    control.requestCloseTab(index)
                                }
                            }
                        }
                    }

                    background: Rectangle {
                        implicitHeight: Theme.tabBarHeight
                        color: tabBtn.checked ? Theme.background : "transparent"
                        
                        // Active Tab Indicator (Top Line)
                        Rectangle {
                            width: parent.width
                            height: 2
                            color: tabAccentColor
                            anchors.top: parent.top
                            visible: tabBtn.checked
                        }
                        
                        // Right separator for all tabs
                        Rectangle {
                            width: 1
                            height: parent.height - 12
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.border
                            opacity: 0.5
                            visible: !tabBtn.checked // Hide separator on active tab? Or keep it.
                        }
                    }
                    }
                }
            }
        }

        Controls.Button {
            id: scrollRightBtn
            Layout.preferredWidth: tabScroll.contentWidth > tabScroll.width ? 24 : 0
            Layout.fillHeight: true
            flat: true
            visible: tabScroll.contentWidth > tabScroll.width
            contentItem: Text {
                text: "›"
                font.pixelSize: 18
                color: scrollRightBtn.hovered ? Theme.textPrimary : Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                var maxX = Math.max(0, tabScroll.contentWidth - tabScroll.width)
                tabScroll.contentX = Math.min(maxX, tabScroll.contentX + 120)
            }
        }

        // Separator
        Rectangle {
            width: 1
            height: parent.height
            color: Theme.border
            Layout.fillHeight: true
            visible: App.activeConnectionId !== -1
        }

        // New Query Button (+)
        Controls.Button {
            id: newTabBtn
            Layout.preferredWidth: 38
            Layout.fillHeight: true
            flat: true
            visible: App.activeConnectionId !== -1
            
            contentItem: Text {
                text: "+"
                font.pixelSize: 20
                color: newTabBtn.hovered ? "#FFFFFF" : Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Item {
                Rectangle {
                    width: 28
                    height: 28
                    radius: 6
                    anchors.centerIn: parent
                    color: newTabBtn.down ? Theme.surfaceHighlight : (newTabBtn.hovered ? Theme.surfaceHighlight : "transparent")
                }
            }
            
            onClicked: control.newQueryClicked()
            
            Controls.ToolTip {
                id: btnToolTip
                visible: newTabBtn.hovered
                text: "New SQL Console"
                delay: 500
                timeout: 5000
                
                contentItem: Text {
                    text: btnToolTip.text
                    font.pixelSize: 12
                    color: Theme.textPrimary
                }
                
                background: Rectangle {
                    color: Theme.surfaceHighlight
                    border.color: Theme.border
                    border.width: 1
                    radius: 4
                }
            }
        }
    }
}
