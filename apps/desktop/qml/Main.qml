import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 640
    height: 480
    visible: true
    title: qsTr("Sofa Studio")

    Column {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: qsTr("Boot OK")
            font.pixelSize: 24
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Button {
            text: "Test Command"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: {
                App.executeCommand("test.hello")
            }
        }
    }
}
