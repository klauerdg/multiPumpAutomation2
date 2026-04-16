import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth:  260
    implicitHeight: 130

    property alias titleLabel:   titleLabel
    property alias setFlowValue: setFlowValue
    property alias ppsLabel:     ppsLabel
    property alias infoLabel:    infoLabel
    property alias timerLabel:   timerLabel
    property alias stepLabel:    stepLabel

    property bool   selected: false
    property bool   paused:   false
    property double rawFlow:  0.0   // actual numeric flow for backend calls

    property int pumpEndSec:      0
    property int pumpStepSec:    -1
    property bool pumpStopped:  false
    property int pumpPausedAt:   -1   // elapsedSec when last paused (-1 = not paused)
    property int pumpPausedAccum: 0   // total seconds paused

    // Theme – set from RunPageForm
    property var themeColors: ({
        cardBg:             "#ffffff",
        cardBgSelected:     "#bbdefb",
        cardBorder:         "#90caf9",
        cardBorderSelected: "#1565c0",
        textPrimary:        "#212121",
        textSecondary:      "#546e7a",
        timerColor:         "#1565c0",
        pausedColor:        "#e65100",
        stepColor:          "#2e7d32"
    })

    Rectangle {
        anchors.fill: parent
        radius: 8
        color:        root.themeColors.cardBg             || "#ffffff"
        border.color: root.selected
                      ? (root.themeColors.cardBorderSelected || "#1565c0")
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
        anchors.margins: 6
        spacing: 2

        Label {
            id: titleLabel
            text:      "Pump"
            font.bold: true
            font.pixelSize: 12
            color: root.themeColors.textPrimary || "#212121"
        }

        RowLayout {
            spacing: 4
            Label { text: "Set:";    font.pixelSize: 11; color: root.themeColors.textPrimary || "#212121" }
            Label {
                id: setFlowValue
                text:      "0.00"
                font.bold: true
                font.pixelSize: 11
                color: root.themeColors.textPrimary || "#212121"
            }
            Label { text: "µL/min"; font.pixelSize: 11; color: root.themeColors.textSecondary || "#546e7a" }
            Label { text: "•";      font.pixelSize: 11; color: root.themeColors.textSecondary || "#546e7a" }
            Label { text: "pps:";   font.pixelSize: 11; color: root.themeColors.textPrimary   || "#212121" }
            Label {
                id: ppsLabel
                text:      "0"
                font.bold: true
                font.pixelSize: 11
                color: root.themeColors.textPrimary || "#212121"
            }
            Item { Layout.fillWidth: true }
        }

        Label {
            id: infoLabel
            text: ""
            font.pixelSize: 11
            color: root.themeColors.textSecondary || "#546e7a"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // Timer row: countdown + "Paused" badge
        RowLayout {
            spacing: 6
            visible: timerLabel.text !== "" || root.paused

            Label {
                id: timerLabel
                text:      ""
                font.pixelSize: 12
                font.bold: true
                color:   root.themeColors.timerColor || "#1565c0"
                visible: text !== ""
            }

            Label {
                text:      "Paused"
                font.pixelSize: 11
                font.bold: true
                color:   root.themeColors.pausedColor || "#e65100"
                visible: root.paused
            }
        }

        Label {
            id: stepLabel
            text:  ""
            font.pixelSize: 11
            color: root.themeColors.stepColor || "#2e7d32"
            Layout.fillWidth: true
            visible: text !== ""
        }
    }
}
