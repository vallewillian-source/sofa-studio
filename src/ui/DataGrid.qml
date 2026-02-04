import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui
import sofa.datagrid 1.0

Rectangle {
    id: root
    color: Theme.background
    
    // Public API
    property alias engine: view.engine
    property bool controlsVisible: true
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Toolbar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.controlsVisible ? 40 : 0
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            visible: root.controlsVisible
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium
                spacing: Theme.spacingMedium
                
                AppButton {
                    text: "Refresh"
                    onClicked: {
                        // TODO: trigger refresh
                        console.log("Refresh clicked")
                    }
                }
                
                CheckBox {
                    text: "Wrap Text"
                    checked: false
                    // TODO: bind to engine/view property
                }
                
                Item { Layout.fillWidth: true } // Spacer
                
                Label {
                    text: "Rows: " + (view.engine ? view.engine.rowCount : 0)
                    color: Theme.textSecondary
                }
            }
        }
        
        // Grid Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1E1E1E"
            clip: true
            
            DataGridView {
                id: view
                anchors.fill: parent
                
                // Bind scrollbars
                contentY: vScroll.position * view.totalHeight
                contentX: hScroll.position * view.totalWidth
            }
            
            ScrollBar {
                id: vScroll
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: hScroll.top
                active: true
                orientation: Qt.Vertical
                size: view.height / Math.max(view.height, view.totalHeight)
                
                onPositionChanged: {
                    if (pressed) {
                        view.contentY = position * view.totalHeight
                    }
                }
            }
            
            ScrollBar {
                id: hScroll
                anchors.left: parent.left
                anchors.right: vScroll.left
                anchors.bottom: parent.bottom
                active: true
                orientation: Qt.Horizontal
                size: view.width / Math.max(view.width, view.totalWidth)
                
                onPositionChanged: {
                    if (pressed) {
                        view.contentX = position * view.totalWidth
                    }
                }
            }
            
            // Mouse Wheel Support
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y !== 0) {
                        var newY = view.contentY - wheel.angleDelta.y
                        if (newY < 0) newY = 0
                        if (newY > view.totalHeight - view.height) newY = view.totalHeight - view.height
                        view.contentY = newY
                        // Sync ScrollBar
                        if (view.totalHeight > 0)
                            vScroll.position = view.contentY / view.totalHeight
                    }
                    if (wheel.angleDelta.x !== 0) {
                        var newX = view.contentX - wheel.angleDelta.x
                        if (newX < 0) newX = 0
                        if (newX > view.totalWidth - view.width) newX = view.totalWidth - view.width
                        view.contentX = newX
                        if (view.totalWidth > 0)
                            hScroll.position = view.contentX / view.totalWidth
                    }
                }
            }
        }
    }
}
