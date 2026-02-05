import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"
    
    property int connectionId: -1
    property var colorOptions: Theme.connectionAvatarColors
    property string selectedColor: Theme.connectionAvatarColors[0]
    signal saved(int id)
    signal canceled()
    
    function colorToRgb(colorValue) {
        if (typeof colorValue === "string") {
            var hex = colorValue.replace("#", "")
            if (hex.length === 3) {
                hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
            }
            if (hex.length !== 6) return { "r": 0, "g": 0, "b": 0 }
            return {
                "r": parseInt(hex.slice(0, 2), 16) / 255,
                "g": parseInt(hex.slice(2, 4), 16) / 255,
                "b": parseInt(hex.slice(4, 6), 16) / 255
            }
        }
        if (colorValue && colorValue.r !== undefined) {
            return { "r": colorValue.r, "g": colorValue.g, "b": colorValue.b }
        }
        return { "r": 0, "g": 0, "b": 0 }
    }

    function relativeLuminance(colorValue) {
        var rgb = colorToRgb(colorValue)
        var toLinear = function(value) {
            return value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4)
        }
        var r = toLinear(rgb.r)
        var g = toLinear(rgb.g)
        var b = toLinear(rgb.b)
        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }

    function isColorDark(colorValue) {
        return relativeLuminance(colorValue) < 0.5
    }

    function getSelectionTextColor(colorValue) {
        return isColorDark(colorValue) ? Theme.textPrimary : Theme.background
    }

    function resetFields() {
        connectionId = -1
        nameField.text = ""
        hostField.text = "localhost"
        portField.text = "5432"
        dbField.text = "postgres"
        userField.text = "postgres"
        passField.text = ""
        testStatus.text = ""
        selectedColor = colorOptions[0]
    }

    function load(conn) {
        connectionId = conn.id
        nameField.text = conn.name
        hostField.text = conn.host
        portField.text = conn.port
        dbField.text = conn.database
        userField.text = conn.user
        passField.text = "" // Password is not retrieved back
        testStatus.text = ""
        selectedColor = conn.color && conn.color.length > 0 ? conn.color : colorOptions[0]
    }
    
    function save() {
         var data = {
            "id": connectionId,
            "name": nameField.text,
            "host": hostField.text,
            "port": parseInt(portField.text),
            "database": dbField.text,
            "user": userField.text,
            "password": passField.text,
            "color": selectedColor
        }
        
        var savedId = App.saveConnection(data)
        if (savedId !== -1) {
            console.log("Connection saved!", savedId)
            root.saved(savedId)
            return true
        } else {
            console.error("Failed to save connection")
            return false
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 0
        
        ColumnLayout {
            id: mainColumn
            width: Math.min(parent.width - 40, 500)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingLarge
            
            Item { Layout.preferredHeight: 20 }

            // Header
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                
                Text {
                    text: root.connectionId === -1 ? "New Connection" : "Edit Connection"
                    font.pixelSize: 24
                    font.bold: true
                    color: Theme.textPrimary
                }
                Text {
                    text: "Fill in the details to connect to the database."
                    font.pixelSize: 13
                    color: Theme.textSecondary
                }
            }

            Item { Layout.preferredHeight: 10 }

            // Section: Identidade
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                Text {
                    text: "IDENTITY"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    color: Theme.accent
                }
                
                // Driver + Name
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium
                    
                    ColumnLayout {
                        Layout.preferredWidth: 140
                        spacing: 6
                        Label { text: "Driver"; color: Theme.textSecondary; font.pixelSize: 12 }
                        ComboBox {
                            id: driverCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.buttonHeight
                            textRole: "name"
                            valueRole: "id"
                            model: App.availableDrivers
                            
                            background: Rectangle {
                                implicitWidth: 120
                                implicitHeight: Theme.buttonHeight
                                color: Theme.surface
                                border.color: parent.activeFocus ? Theme.accent : Theme.border
                                border.width: 1
                                radius: Theme.radius
                            }
                            
                            contentItem: Text {
                                leftPadding: 10
                                rightPadding: 10
                                text: driverCombo.displayText
                                font.pixelSize: 14
                                color: Theme.textPrimary
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            
                            delegate: ItemDelegate {
                                width: driverCombo.width
                                contentItem: Text {
                                    text: model.name
                                    color: Theme.textPrimary
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: highlighted ? Theme.surfaceHighlight : "transparent"
                                }
                                highlighted: driverCombo.highlightedIndex === index
                            }
                            
                            popup: Popup {
                                y: driverCombo.height - 1
                                width: driverCombo.width
                                implicitHeight: contentItem.implicitHeight
                                padding: 1

                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: driverCombo.popup.visible ? driverCombo.delegateModel : null
                                    currentIndex: driverCombo.highlightedIndex

                                    ScrollIndicator.vertical: ScrollIndicator { }
                                }

                                background: Rectangle {
                                    border.color: Theme.border
                                    color: Theme.surface
                                    radius: Theme.radius
                                }
                            }
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: "Connection Name"; color: Theme.textSecondary; font.pixelSize: 12 }
                        AppTextField {
                            id: nameField
                            Layout.fillWidth: true
                            placeholderText: "Ex: Production, Local..."
                        }
                    }
                }
                
                // Color Picker
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label { text: "Identification Color"; color: Theme.textSecondary; font.pixelSize: 12 }
                    
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: colorOptions
                            delegate: Rectangle {
                                width: 28
                                height: 28
                                radius: width / 2
                                color: modelData
                                border.width: selectedColor === modelData ? 2 : 0
                                border.color: Theme.textPrimary
                                
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Theme.background
                                    visible: selectedColor === modelData
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: selectedColor = modelData
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: getSelectionTextColor(modelData)
                                    font.pixelSize: 14
                                    font.bold: true
                                    visible: selectedColor === modelData
                                }
                            }
                        }
                    }
                }
            }
            
            Item { Layout.preferredHeight: 10 }
            
            // Section: Servidor
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                Text {
                    text: "SERVER"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    color: Theme.accent
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: "Host"; color: Theme.textSecondary; font.pixelSize: 12 }
                        AppTextField {
                            id: hostField
                            Layout.fillWidth: true
                            placeholderText: "localhost or IP"
                        }
                    }
                    
                    ColumnLayout {
                        Layout.preferredWidth: 80
                        spacing: 6
                        Label { text: "Port"; color: Theme.textSecondary; font.pixelSize: 12 }
                        AppTextField {
                            id: portField
                            Layout.fillWidth: true
                            text: "5432"
                            validator: IntValidator { bottom: 1; top: 65535 }
                        }
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label { text: "Database"; color: Theme.textSecondary; font.pixelSize: 12 }
                    AppTextField {
                        id: dbField
                        Layout.fillWidth: true
                        placeholderText: "postgres"
                    }
                }
            }
            
            Item { Layout.preferredHeight: 10 }
            
            // Section: Credenciais
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                Text {
                    text: "CREDENTIALS"
                    font.pixelSize: 11
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    color: Theme.accent
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: "Username"; color: Theme.textSecondary; font.pixelSize: 12 }
                        AppTextField {
                            id: userField
                            Layout.fillWidth: true
                            placeholderText: "postgres"
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label { text: "Password"; color: Theme.textSecondary; font.pixelSize: 12 }
                        AppTextField {
                            id: passField
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            placeholderText: "Optional"
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }

            // Actions & Test
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                // Status Message
                RowLayout {
                    Layout.fillWidth: true
                    visible: testStatus.text !== ""
                    spacing: 8
                    
                    Text {
                        text: testStatus.color == "green" ? "✓" : "!"
                        color: testStatus.color
                        font.bold: true
                        font.pixelSize: 14
                    }
                    
                    Text {
                        id: testStatus
                        text: ""
                        color: Theme.textPrimary
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium
                    
                    AppButton {
                        text: "Test Connection"
                        Layout.preferredWidth: 140
                        onClicked: {
                            var data = {
                                "host": hostField.text,
                                "port": parseInt(portField.text),
                                "database": dbField.text,
                                "user": userField.text,
                                "password": passField.text
                            }
                            if (App.testConnection(data)) {
                                testStatus.text = "Connection established successfully!"
                                testStatus.color = "green"
                            } else {
                                testStatus.text = App.lastError.length > 0 ? App.lastError : "Connection failed!"
                                testStatus.color = "red"
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    AppButton {
                        text: "Cancel"
                        onClicked: root.canceled()
                    }
                    
                    AppButton {
                        text: "Save Connection"
                        isPrimary: true
                        textColor: Theme.background
                        onClicked: root.save()
                    }
                }
            }
            
            Item { Layout.preferredHeight: 40 }
        }
    }
}
