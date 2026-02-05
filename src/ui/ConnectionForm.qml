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
        return isColorDark(colorValue) ? "#FFFFFF" : Theme.background
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
        anchors.margins: Theme.spacingLarge
        
        ColumnLayout {
            width: Math.min(parent.width, 600)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingMedium
            
            Text {
                text: root.connectionId === -1 ? "New Connection" : "Edit Connection"
                font.pixelSize: 24
                color: Theme.textPrimary
                Layout.bottomMargin: Theme.spacingMedium
            }
            
            // Driver
            Label { text: "Driver"; color: Theme.textPrimary }
            ComboBox {
                id: driverCombo
                Layout.fillWidth: true
                textRole: "name"
                valueRole: "id"
                model: App.availableDrivers
            }

            // Name
            Label { text: "Name"; color: Theme.textPrimary }
            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "My Local DB"
            }

            Label { text: "Color"; color: Theme.textPrimary }
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: colorOptions
                    delegate: Rectangle {
                        width: 26
                        height: 26
                        radius: Math.round(width * 0.28)
                        color: modelData
                        border.width: selectedColor === modelData ? 2 : 1
                        border.color: selectedColor === modelData ? Theme.textPrimary : Theme.border

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectedColor = modelData
                        }

                        Text {
                            anchors.centerIn: parent
                            text: selectedColor === modelData ? "✓" : ""
                            color: getSelectionTextColor(modelData)
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }
            
            // Host & Port
            RowLayout {
                Layout.fillWidth: true
                
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: "Host"; color: Theme.textPrimary }
                    TextField {
                        id: hostField
                        Layout.fillWidth: true
                        placeholderText: "localhost"
                    }
                }
                
                ColumnLayout {
                    Layout.preferredWidth: 80
                    Label { text: "Port"; color: Theme.textPrimary }
                    TextField {
                        id: portField
                        Layout.fillWidth: true
                        text: "5432"
                        validator: IntValidator { bottom: 1; top: 65535 }
                    }
                }
            }
            
            // Database
            Label { text: "Database"; color: Theme.textPrimary }
            TextField {
                id: dbField
                Layout.fillWidth: true
                placeholderText: "postgres"
            }
            
            // User & Password
            RowLayout {
                Layout.fillWidth: true
                
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: "User"; color: Theme.textPrimary }
                    TextField {
                        id: userField
                        Layout.fillWidth: true
                        placeholderText: "postgres"
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: "Password"; color: Theme.textPrimary }
                    TextField {
                        id: passField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: "Optional"
                    }
                }
            }
            
            // Test Connection
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingMedium
                
                Label {
                    id: testStatus
                    Layout.fillWidth: true
                    font.pixelSize: 12
                }
                
                Button {
                    text: "Test Connection"
                    onClicked: {
                        var data = {
                            "host": hostField.text,
                            "port": parseInt(portField.text),
                            "database": dbField.text,
                            "user": userField.text,
                            "password": passField.text
                        }
                        if (App.testConnection(data)) {
                            testStatus.text = "Connection Successful!"
                            testStatus.color = "green"
                        } else {
                            testStatus.text = App.lastError.length > 0 ? App.lastError : "Connection Failed!"
                            testStatus.color = "red"
                        }
                    }
                }
            }
            
            // Actions
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacingLarge
                spacing: Theme.spacingMedium
                
                Item { Layout.fillWidth: true } // Spacer
                
                Button {
                    text: "Cancel"
                    onClicked: root.canceled()
                }
                
                Button {
                    text: "Save"
                    highlighted: true
                    onClicked: root.save()
                }
            }
        }
    }
}
