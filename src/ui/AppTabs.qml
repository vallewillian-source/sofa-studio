import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Rectangle {
    id: control
    property var tabsModel: null // ListModel
    property alias currentIndex: tabBar.currentIndex
    property alias count: tabBar.count
    signal requestCloseTab(int index)
    signal newQueryClicked()
    
    implicitHeight: Theme.tabBarHeight
    color: Theme.surface
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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Controls.TabBar {
            id: tabBar
            Layout.preferredWidth: contentWidth
            Layout.fillHeight: true
            background: null // Transparent
            
            Repeater {
                model: control.tabsModel
                
                Controls.TabButton {
                    id: tabBtn
                    width: implicitWidth + 20
                    
                    contentItem: RowLayout {
                        spacing: 8
                        
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
                        color: parent.checked ? Theme.background : "transparent"
                        
                        // Top highlight line for active tab
                        Rectangle {
                            width: parent.width
                            height: 2
                            color: Theme.accent
                            anchors.top: parent.top
                            visible: parent.parent.checked
                        }
                    }
                }
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
            Layout.preferredWidth: 40
            Layout.fillHeight: true
            flat: true
            visible: App.activeConnectionId !== -1
            
            contentItem: Text {
                text: "+"
                font.pixelSize: 20
                color: newTabBtn.hovered ? Theme.textPrimary : Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            background: Rectangle {
                color: newTabBtn.down ? Theme.surfaceHighlight : (newTabBtn.hovered ? Qt.lighter(Theme.surfaceHighlight, 1.2) : "transparent")
            }
            
            onClicked: control.newQueryClicked()
            
            Controls.ToolTip.visible: hovered
            Controls.ToolTip.text: "New SQL Console"
            Controls.ToolTip.delay: 500
        }

        // Spacer to push everything to the left
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
