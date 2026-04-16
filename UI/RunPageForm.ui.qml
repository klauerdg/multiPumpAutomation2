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

    // ── Theme (set from Main.qml via Qt.binding) ──────────────────────────────
    property var themeColors: ({
        pageBg:             "#e3f2fd",
        toolbarBg:          "#1565c0",
        toolbarText:        "#ffffff",
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
        pausedColor:        "#e65100",
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
            font.pointSize: 18 * scaleFactor
            font.bold: true
            color: themeColors.timerColor || "#1565c0"
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment:    Qt.AlignHCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Small status line
        Label {
            id: statusLabel
            text: ""
            font.pixelSize: 11 * scaleFactor
            color: themeColors.textSecondary || "#546e7a"
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
                font.pixelSize: 12 * scaleFactor
                Layout.preferredWidth: 80 * scaleFactor
                themeColors: root.themeColors
            }
            FlashButton {
                id: pauseButton
                text: "Pause All"
                font.pixelSize: 12 * scaleFactor
                Layout.preferredWidth: 90 * scaleFactor
                themeColors: root.themeColors
            }
            FlashButton {
                id: stopButton
                text: "Stop All"
                font.pixelSize: 12 * scaleFactor
                Layout.preferredWidth: 90 * scaleFactor
                themeColors: root.themeColors
            }

            Item { Layout.preferredWidth: 16 * scaleFactor }

            FlashButton {
                id: pauseSelectedButton
                text: "Pause Selected"
                font.pixelSize: 11 * scaleFactor
                Layout.preferredWidth: 110 * scaleFactor
                themeColors: root.themeColors
            }
            FlashButton {
                id: resumeSelectedButton
                text: "Resume Selected"
                font.pixelSize: 11 * scaleFactor
                Layout.preferredWidth: 120 * scaleFactor
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

            RunPumpCardForm { id: r6; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r8; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r1; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r3; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r2; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r7; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r9; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r5; visible: false; scale: scaleFactor; themeColors: themeColors }
            RunPumpCardForm { id: r4; visible: false; scale: scaleFactor; themeColors: themeColors }
        }
    }
}
