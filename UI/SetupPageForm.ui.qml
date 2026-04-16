import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth:  1024
    implicitHeight: 600

    // ── Aliases ──────────────────────────────────────────────────────────────
    property alias groupFlowField:    groupFlowField
    property alias applyGroupButton:  applyGroupButton
    property alias advancedButton:    advancedButton
    property alias loadPresetButton:  loadPresetButton
    property alias savePresetButton:  savePresetButton
    property alias readyToRunButton:  readyToRunButton
    property alias calibrationButton: calibrationButton

    property alias pump1: pc1
    property alias pump2: pc2
    property alias pump3: pc3
    property alias pump4: pc4
    property alias pump5: pc5
    property alias pump6: pc6
    property alias pump7: pc7
    property alias pump8: pc8
    property alias pump9: pc9

    // ── Theme (set from Main.qml via Qt.binding) ─────────────────────────────
    property var themeColors: ({
        pageBg:             "#eef1f5",
        toolbarBg:          "#546e7a",
        cardBg:             "#ffffff",
        cardBgSelected:     "#dce8f0",
        cardBorder:         "#b0bec5",
        cardBorderSelected: "#455a64",
        buttonBg:           "#607d8b",
        buttonFlash:        "#37474f",
        timerColor:         "#1565c0",
        pausedColor:        "#bf360c",
        stepColor:          "#2e7d32",
        primeActive:        "#ffccbc",
        primeInactive:      "#eceff1"
    })

    // ── Page background ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: themeColors.pageBg || "#e3f2fd"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 10
        spacing: 8

        // ── Toolbar ───────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 58
            radius: 6
            color: themeColors.toolbarBg || "#1565c0"
            Behavior on color { ColorAnimation { duration: 200 } }

            RowLayout {
                anchors.fill:           parent
                anchors.leftMargin:     10
                anchors.rightMargin:    10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Label {
                    text:  "Flow"
                    font.pixelSize: 16
                    color: themeColors.toolbarText || "#ffffff"
                }

                TextField {
                    id: groupFlowField
                    text:  "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 96
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }

                Label {
                    text:  "µL/min"
                    font.pixelSize: 14
                    color: themeColors.toolbarText || "#ffffff"
                    opacity: 0.85
                }

                FlashButton {
                    id: advancedButton
                    text: "Advanced"
                    font.pixelSize: 14
                    Layout.preferredWidth: 108
                    themeColors: root.themeColors
                }

                FlashButton {
                    id: applyGroupButton
                    text: "Apply to Selected"
                    font.pixelSize: 14
                    Layout.preferredWidth: 144
                    themeColors: root.themeColors
                }

                FlashButton {
                    id: readyToRunButton
                    text: "Ready to Run"
                    font.pixelSize: 14
                    Layout.preferredWidth: 132
                    themeColors: root.themeColors
                }

                Item { Layout.fillWidth: true }

                FlashButton {
                    id: calibrationButton
                    text: "Calibration"
                    font.pixelSize: 14
                    Layout.preferredWidth: 108
                    themeColors: root.themeColors
                }

                FlashButton {
                    id: loadPresetButton
                    text: "Load Preset"
                    font.pixelSize: 14
                    Layout.preferredWidth: 108
                    themeColors: root.themeColors
                }

                FlashButton {
                    id: savePresetButton
                    text: "Save Preset"
                    font.pixelSize: 14
                    Layout.preferredWidth: 108
                    themeColors: root.themeColors
                }
            }
        }

        // ── Pump card grid ────────────────────────────────────────────────────
        GridLayout {
            columns:       3
            rowSpacing:    10
            columnSpacing: 10
            Layout.fillWidth:  true
            Layout.fillHeight: true

            PumpCardForm { id: pc6; pumpId: 6; titleLabel.text: "Pump 1"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc8; pumpId: 8; titleLabel.text: "Pump 2"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc1; pumpId: 1; titleLabel.text: "Pump 3"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc3; pumpId: 3; titleLabel.text: "Pump 4"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc2; pumpId: 2; titleLabel.text: "Pump 5"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc7; pumpId: 7; titleLabel.text: "Pump 6"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc9; pumpId: 9; titleLabel.text: "Pump 7"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc5; pumpId: 5; titleLabel.text: "Pump 8"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            PumpCardForm { id: pc4; pumpId: 4; titleLabel.text: "Pump 9"; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
