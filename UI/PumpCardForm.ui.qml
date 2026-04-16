import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth:  320
    implicitHeight: 140

    property int    pumpId:  0
    property bool   priming: false
    property bool   selected: false

    // Advanced automation settings; advMode === "" means none applied
    property string advMode:         ""
    property string advShape:        "Square"
    property double advPeriod:       2.0
    property double advDuty:         50.0
    property double advMinFlow:      0.0
    property double advMaxFlow:      0.0
    property double advTotalMinutes: 5.0
    property bool   advStepEnabled:  false
    property double advStepMinutes:  2.0
    property double advStepFlow:     0.0

    // Theme – set from SetupPageForm (which receives it from Main.qml)
    property var themeColors: ({
        cardBg:             "#ffffff",
        cardBgSelected:     "#bbdefb",
        cardBorder:         "#90caf9",
        cardBorderSelected: "#1565c0",
        buttonBg:           "#1976d2",
        buttonFlash:        "#0d47a1",
        buttonText:         "#ffffff",
        textPrimary:        "#212121",
        textSecondary:      "#546e7a",
        timerColor:         "#1565c0",
        primeActive:        "#ffcdd2",
        primeInactive:      "#e0e0e0"
    })

    property alias titleLabel:  titleLabel
    property alias flowField:   flowField
    property alias primeButton: primeButton

    // Card background & selection highlight
    Rectangle {
        anchors.fill: parent
        radius: 8
        color:        root.selected ? (root.themeColors.cardBgSelected     || "#bbdefb")
                                    : (root.themeColors.cardBg             || "#ffffff")
        border.color: root.selected ? (root.themeColors.cardBorderSelected || "#1565c0")
                                    : (root.themeColors.cardBorder         || "#90caf9")
        border.width: root.selected ? 2 : 1

        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.selected = !root.selected
        }
    }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 10
        spacing: 5

        Label {
            id: titleLabel
            text:      "Pump 1"
            font.bold: true
            font.pixelSize: 13
            color: root.themeColors.textPrimary || "#212121"
        }

        RowLayout {
            spacing: 8

            Label {
                text:  "Flow:"
                color: root.themeColors.textPrimary || "#212121"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            TextField {
                id: flowField
                placeholderText: "0.00"
                text:            "0.00"
                validator: DoubleValidator { bottom: 0; decimals: 2 }
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 80
                font.pixelSize: 12
                inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
            }

            Label {
                text:  "µL/min"
                color: root.themeColors.textSecondary || "#546e7a"
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            // Prime button keeps its own distinct style (not FlashButton)
            Button {
                id: primeButton
                text: root.priming ? "Priming…" : "Prime"
                font.pixelSize: 12
                Layout.preferredWidth: 90

                background: Rectangle {
                    radius: 4
                    color:  root.priming
                            ? (root.themeColors.primeActive   || "#ffcdd2")
                            : (root.themeColors.primeInactive || "#e0e0e0")
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Advanced settings summary — only visible when advMode is set
        ColumnLayout {
            visible: root.advMode !== ""
            spacing: 2
            Layout.fillWidth: true

            Label {
                visible: root.advMode === "Constant"
                text:    "Run: " + root.advTotalMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color: root.themeColors.textSecondary || "#546e7a"
            }
            Label {
                visible: root.advMode === "Constant" && root.advStepEnabled
                text:    "→ " + root.advStepFlow.toFixed(2)
                         + " µL/min at " + root.advStepMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color: root.themeColors.timerColor || "#1565c0"
            }
            Label {
                visible: root.advMode === "Pulsatile"
                text:    root.advShape + " • " + root.advPeriod.toFixed(1) + "s period"
                         + (root.advShape === "Square"
                            ? " • " + root.advDuty.toFixed(0) + "% duty" : "")
                font.pixelSize: 11
                color: root.themeColors.textSecondary || "#546e7a"
            }
            Label {
                visible: root.advMode === "Pulsatile"
                text:    "Min: " + root.advMinFlow.toFixed(2)
                         + "  Max: " + root.advMaxFlow.toFixed(2)
                         + " • " + root.advTotalMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color: root.themeColors.textSecondary || "#546e7a"
            }
        }

        Item { Layout.fillHeight: true }
    }
}
