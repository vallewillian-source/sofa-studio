import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "transparent"
    
    property int connectionId: -1
    signal saved(int id)
    signal canceled()
    
    // Reset fields
    function resetFields() {
        connectionId = -1
        nameField.text = ""
        hostField.text = "localhost"
        portField.text = "5432"
        dbField.text = "postgres"
        userField.text = "postgres"
        passField.text = ""
        testStatus.text = ""
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
    }
    
    function save() {
         var data = {
            "id": connectionId,
            "name": nameField.text,
            "host": hostField.text,
            "port": parseInt(portField.text),
            "database": dbField.text,
            "user": userField.text,
            "password": passField.text
        }
        
        if (App.saveConnection(data)) {
            console.log("Connection saved!")
            root.saved(connectionId)
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
