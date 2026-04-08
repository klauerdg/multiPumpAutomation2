import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth: 260
    implicitHeight: 130

    property alias titleLabel:  titleLabel
    property alias setFlowValue: setFlowValue
    property alias ppsLabel:    ppsLabel
    property alias infoLabel:   infoLabel
    property alias timerLabel:  timerLabel
    property alias stepLabel:   stepLabel

    property bool selected: false
    property bool paused: false
    property double rawFlow: 0.0   // actual numeric flow for backend calls (pulsatile uses max flow)

    property int pumpEndSec: 0
    property int pumpStepSec: -1
    property bool pumpStopped: false

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#ffffff"
        border.color: root.selected ? "#1565c0" : "#cfd8dc"
        border.width: root.selected ? 2 : 1

        MouseArea {
            anchors.fill: parent
            onClicked: root.selected = !root.selected
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 2

        Label {
            id: titleLabel
            text: "Pump"
            font.bold: true
            font.pixelSize: 12
        }

        RowLayout {
            spacing: 4
            Label { text: "Set:"; font.pixelSize: 11 }
            Label {
                id: setFlowValue
                text: "0.00"
                font.bold: true
                font.pixelSize: 11
            }
            Label { text: "µL/min"; font.pixelSize: 11; color: "#555" }
            Label { text: "•"; font.pixelSize: 11; color: "#999" }
            Label { text: "pps:"; font.pixelSize: 11 }
            Label {
                id: ppsLabel
                text: "0"
                font.bold: true
                font.pixelSize: 11
            }
            Item { Layout.fillWidth: true }
        }

        Label {
            id: infoLabel
            text: ""
            font.pixelSize: 11
            color: "#666"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // Timer row: countdown + "Paused" badge side by side
        RowLayout {
            spacing: 6
            visible: timerLabel.text !== "" || root.paused

            Label {
                id: timerLabel
                text: ""
                font.pixelSize: 12
                font.bold: true
                color: "#1565c0"
                visible: text !== ""
            }

            Label {
                text: "Paused"
                font.pixelSize: 11
                font.bold: true
                color: "#e65100"
                visible: root.paused
            }
        }

        Label {
            id: stepLabel
            text: ""
            font.pixelSize: 11
            color: "#e65100"
            Layout.fillWidth: true
            visible: text !== ""
        }
    }
}
