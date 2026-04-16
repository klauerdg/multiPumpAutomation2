import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth:  1024
    implicitHeight: 600

    // ── Aliases ───────────────────────────────────────────────────────────────
    property alias runTimeLabel:       runTimeLabel
    property alias startButton:        startButton
    property alias pauseButton:        pauseButton
    property alias stopButton:         stopButton
    property alias pauseSelectedButton:  pauseSelectedButton
    property alias resumeSelectedButton: resumeSelectedButton
    property alias statusLabel:        statusLabel

    property alias r1: r1
    property alias r2: r2
    property alias r3: r3
    property alias r4: r4
    property alias r5: r5
    property alias r6: r6
    property alias r7: r7
    property alias r8: r8
    property alias r9: r9

    property real scaleFactor: (height < 520 ? 0.85 : 1.0)

    // Auto-compute page text colour from page background luminance
    property color _pageText: "#000000"
    property color _timerClr: "#1565c0"

    function _applyTheme() {
        var hex = themeColors.pageBg || "#eef1f5";
        if (hex.length >= 7) {
            var r = parseInt(hex.slice(1,3),16)/255;
            var g = parseInt(hex.slice(3,5),16)/255;
            var b = parseInt(hex.slice(5,7),16)/255;
            _pageText = (0.299*r + 0.587*g + 0.114*b) > 0.5 ? "#000000" : "#ffffff";
        }
        _timerClr = themeColors.timerColor || "#1565c0";
    }
    onThemeColorsChanged: _applyTheme()
    Component.onCompleted: _applyTheme()

    // ── Theme (set from Main.qml via Qt.binding) ──────────────────────────────
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
        stepColor:          "#2e7d32"
    })

    // ── Page background ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: themeColors.pageBg || "#e3f2fd"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 6 * scaleFactor
        spacing: 4 * scaleFactor

        // Big timer
        Label {
            id: runTimeLabel
            text: "00:00:00"
            font.pointSize: 22 * scaleFactor
            font.bold: true
            color: root._timerClr
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment:    Qt.AlignHCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Small status line
        Label {
            id: statusLabel
            text: ""
            font.pixelSize: 13 * scaleFactor
            color: Qt.alpha(_pageText, 0.6)
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        // ── Controls row ──────────────────────────────────────────────────────
        RowLayout {
            spacing: 8 * scaleFactor
            Layout.alignment: Qt.AlignHCenter

            FlashButton {
                id: startButton
                text: "Start"
                font.pixelSize: 14 * scaleFactor
                Layout.preferredWidth: 96 * scaleFactor
                themeColors: root.themeColors
            }
            FlashButton {
                id: pauseButton
                text: "Pause All"
                font.pixelSize: 14 * scaleFactor
                Layout.preferredWidth: 108 * scaleFactor
                themeColors: root.themeColors
            }
            FlashButton {
                id: stopButton
                text: "Stop All"
                font.pixelSize: 14 * scaleFactor
                Layout.preferredWidth: 108 * scaleFactor
                themeColors: root.themeColors
            }

            Item { Layout.preferredWidth: 19 * scaleFactor }

            FlashButton {
                id: pauseSelectedButton
                text: "Pause Selected"
                font.pixelSize: 13 * scaleFactor
                Layout.preferredWidth: 132 * scaleFactor
                themeColors: root.themeColors
            }
            FlashButton {
                id: resumeSelectedButton
                text: "Resume Selected"
                font.pixelSize: 13 * scaleFactor
                Layout.preferredWidth: 144 * scaleFactor
                themeColors: root.themeColors
            }
        }

        // ── Pump grid ─────────────────────────────────────────────────────────
        GridLayout {
            columns:       3
            rowSpacing:    5 * scaleFactor
            columnSpacing: 8 * scaleFactor
            Layout.fillWidth:  true
            Layout.fillHeight: true

            RunPumpCardForm { id: r6; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r8; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r1; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r3; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r2; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r7; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r9; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r5; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
            RunPumpCardForm { id: r4; visible: false; scale: scaleFactor; themeColors: themeColors; Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
