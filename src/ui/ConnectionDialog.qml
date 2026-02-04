import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Connection Details"
    modal: true
    standardButtons: Dialog.Save | Dialog.Cancel
    
    property int connectionId: -1
    
    // Reset fields
    function resetFields() {
        connectionId = -1
        nameField.text = ""
        hostField.text = "localhost"
        portField.text = "5432"
        dbField.text = "postgres"
        userField.text = "postgres"
        passField.text = ""
    }

    function load(conn) {
        connectionId = conn.id
        nameField.text = conn.name
        hostField.text = conn.host
        portField.text = conn.port
        dbField.text = conn.database
        userField.text = conn.user
        passField.text = "" // Password is not retrieved back
    }

    onAccepted: {
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
        } else {
            console.error("Failed to save connection")
        }
    }

    ColumnLayout {
        width: 400
        spacing: Theme.spacingMedium
        
        // Driver
        Label { text: "Driver" }
        ComboBox {
            id: driverCombo
            Layout.fillWidth: true
            textRole: "name"
            valueRole: "id"
            model: App.availableDrivers
        }

        // Name
        Label { text: "Name" }
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
                Label { text: "Host" }
                TextField {
                    id: hostField
                    Layout.fillWidth: true
                    placeholderText: "localhost"
                }
            }
            
            ColumnLayout {
                Layout.preferredWidth: 80
                Label { text: "Port" }
                TextField {
                    id: portField
                    Layout.fillWidth: true
                    text: "5432"
                    validator: IntValidator { bottom: 1; top: 65535 }
                }
            }
        }
        
        // Database
        Label { text: "Database" }
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
                Label { text: "User" }
                TextField {
                    id: userField
                    Layout.fillWidth: true
                    placeholderText: "postgres"
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                Label { text: "Password" }
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
    }
}
