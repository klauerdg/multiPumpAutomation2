import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth: 320
    implicitHeight: advMode !== "" ? 185 : 140

    property int pumpId: 0
    property bool priming: false
    property bool selected: false

    // Advanced automation settings; advMode === "" means none applied
    property string advMode: ""
    property string advShape: "Square"
    property double advPeriod: 2.0
    property double advDuty: 50.0
    property double advMinFlow: 0.0
    property double advMaxFlow: 0.0
    property double advTotalMinutes: 5.0
    property bool   advStepEnabled: false
    property double advStepMinutes: 2.0
    property double advStepFlow: 0.0

    property alias titleLabel:  titleLabel
    property alias flowField:   flowField
    property alias primeButton: primeButton

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.selected ? "#bbdefb" : "#ffffff"
        border.color: root.selected ? "#1565c0" : "#cfd8dc"
        border.width: root.selected ? 2 : 1

        MouseArea {
            anchors.fill: parent
            onClicked: root.selected = !root.selected
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Label {
            id: titleLabel
            text: "Pump 1"
            font.bold: true
        }

        RowLayout {
            spacing: 10

            Label {
                text: "Flow:"
                Layout.alignment: Qt.AlignVCenter
            }

            TextField {
                id: flowField
                placeholderText: "0.00"
                text: "0.00"
                validator: DoubleValidator { bottom: 0; decimals: 2 }
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
                inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
            }

            Label {
                text: "µL/min"
                color: "#555"
                Layout.alignment: Qt.AlignVCenter
            }

            Button {
                id: primeButton
                text: root.priming ? "Priming…" : "Prime"
                Layout.preferredWidth: 100

                background: Rectangle {
                    radius: 4
                    color: root.priming ? "#ffcdd2" : "#e0e0e0"
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Advanced settings summary — only shown when advMode is set
        ColumnLayout {
            visible: root.advMode !== ""
            spacing: 2
            Layout.fillWidth: true

            // Constant mode summary
            Label {
                visible: root.advMode === "Constant"
                text: "Run: " + root.advTotalMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color: "#555"
            }
            Label {
                visible: root.advMode === "Constant" && root.advStepEnabled
                text: "→ " + root.advStepFlow.toFixed(2) + " µL/min at " + root.advStepMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color: "#1565c0"
            }

            // Pulsatile mode summary
            Label {
                visible: root.advMode === "Pulsatile"
                text: root.advShape + " • " + root.advPeriod.toFixed(1) + "s period"
                      + (root.advShape === "Square" ? " • " + root.advDuty.toFixed(0) + "% duty" : "")
                font.pixelSize: 11
                color: "#555"
            }
            Label {
                visible: root.advMode === "Pulsatile"
                text: "Min: " + root.advMinFlow.toFixed(2)
                      + "  Max: " + root.advMaxFlow.toFixed(2)
                      + " • " + root.advTotalMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color: "#555"
            }
        }

        Item { Layout.fillHeight: true }
    }
}
