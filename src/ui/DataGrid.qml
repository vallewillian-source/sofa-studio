import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui
import sofa.datagrid 1.0

Rectangle {
    id: root
    color: "transparent"
    
    // Public API
    property alias engine: view.engine
    property int pageSize: 100
    property int currentPage: 1
    property bool canPrevious: false
    property bool canNext: false
    property color addRowAccentColor: Theme.accent
    signal addRowClicked()
    signal previousClicked()
    signal nextClicked()
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        
        // Grid Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true
            
            DataGridView {
                id: view
                anchors.fill: parent

                // Colors
                // Header darker than background
                headerColor: "#050505" 
                
                onTotalWidthChanged: console.log("DataGrid TotalWidth:", totalWidth, "ViewWidth:", width)
                
                // Zebra striping with connection tint
                alternateRowColor: {
                    var id = App.activeConnectionId
                    var activeColor = Theme.accent
                    
                    if (id !== -1) {
                        var conns = App.connections
                        for (var i = 0; i < conns.length; i++) {
                            if (conns[i].id === id) {
                                activeColor = Theme.getConnectionColor(conns[i].name, conns[i].color)
                                break
                            }
                        }
                    }
                    
                    // Mix Theme.background with activeColor (25% opacity)
                    return Theme.tintColor(Theme.background, activeColor, 0.25)
                }
                
                // Selection with connection tint (10% opacity)
                selectionColor: {
                    var id = App.activeConnectionId
                    var activeColor = Theme.accent
                    
                    if (id !== -1) {
                        var conns = App.connections
                        for (var i = 0; i < conns.length; i++) {
                            if (conns[i].id === id) {
                                activeColor = Theme.getConnectionColor(conns[i].name, conns[i].color)
                                break
                            }
                        }
                    }
                    
                    return Theme.tintColor(Theme.background, activeColor, 0.1)
                }

                gridLineColor: "transparent"
                textColor: Theme.textPrimary
                
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
        
        // Footer / Status Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            visible: true
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingMedium
                anchors.rightMargin: Theme.spacingMedium
                spacing: Theme.spacingMedium
                
                AppButton {
                    text: "Add Row"
                    icon.source: "qrc:/qt/qml/sofa/ui/assets/plus-solid-full.svg"
                    isPrimary: true
                    accentColor: root.addRowAccentColor
                    Layout.preferredHeight: 24
                    iconSize: 12
                    spacing: 4
                    opacity: 0.8
                    font.weight: Font.DemiBold
                    onClicked: root.addRowClicked()
                }

                Label {
                    text: "Rows: " + (view.engine ? view.engine.rowCount : 0)
                    color: Theme.textSecondary
                    font.pixelSize: 11
                }
                
                Item { Layout.fillWidth: true }

                // Pagination
                RowLayout {
                    spacing: 8
                    
                    AppButton {
                        text: "Previous"
                        Layout.preferredHeight: 24
                        font.pixelSize: 11
                        isPrimary: false
                        enabled: root.canPrevious
                        opacity: root.canPrevious ? 1.0 : 0.5
                        onClicked: root.previousClicked()
                    }
                    
                    Label {
                        text: "Page " + root.currentPage
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                    
                    AppButton {
                        text: "Next"
                        Layout.preferredHeight: 24
                        font.pixelSize: 11
                        isPrimary: false
                        enabled: root.canNext
                        opacity: root.canNext ? 1.0 : 0.5
                        onClicked: root.nextClicked()
                    }
                }
            }
        }
    }
}
