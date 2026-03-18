import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth: 260
    implicitHeight: 160

    property alias selectCheck: selectCheck
    property alias titleLabel: titleLabel
    property alias setFlowValue: setFlowValue
    property alias ppsLabel: ppsLabel
    property alias infoLabel: infoLabel
    property alias timerLabel: timerLabel
    property alias stepLabel: stepLabel

    property int pumpEndSec: 0       // seconds from run-start when this pump finishes (0 = no limit)
    property int pumpStepSec: -1     // seconds from run-start when step change fires (-1 = none)

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: "#ffffff"
        border.color: "#cfd8dc"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        RowLayout {
            spacing: 4
            CheckBox { id: selectCheck }
            Label {
                id: titleLabel
                text: "Pump"
                font.bold: true
                font.pixelSize: 12
            }
            Item { Layout.fillWidth: true }
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

            Label {
                text: "µL/min"
                font.pixelSize: 11
                color: "#555"
            }

            Label {
                text: "•"
                font.pixelSize: 11
                color: "#999"
            }

            Label {
                text: "pps:"
                font.pixelSize: 11
            }

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
            text: ""      // e.g. "Constant • 5.0 min • Change to 22.00 µL/min at 1.0 min"
            font.pixelSize: 11
            color: "#666"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }

        // Per-pump countdown timer (shown only during automation)
        Label {
            id: timerLabel
            text: ""
            font.pixelSize: 12
            font.bold: true
            color: "#1565c0"           // blue
            Layout.fillWidth: true
            visible: text !== ""
        }

        // Step-change countdown (shown only when step is configured)
        Label {
            id: stepLabel
            text: ""
            font.pixelSize: 11
            color: "#e65100"           // orange
            Layout.fillWidth: true
            visible: text !== ""
        }
    }
}






