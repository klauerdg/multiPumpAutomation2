import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth:  240
    implicitHeight: 120

    property alias titleLabel:   titleLabel
    property alias setFlowValue: setFlowValue
    property alias ppsLabel:     ppsLabel
    property alias infoLabel:    infoLabel
    property alias timerLabel:   timerLabel
    property alias stepLabel:    stepLabel

    property bool   selected: false
    property bool   paused:   false
    property double rawFlow:  0.0

    property int  pumpEndSec:      0
    property int  pumpStepSec:    -1
    property bool pumpStopped:  false
    property int  pumpPausedAt:   -1
    property int  pumpPausedAccum: 0
    property int  pumpDurationSec: 0

    property var themeColors: ({
        cardBg:             "#ffffff",
        cardBgSelected:     "#dce8f0",
        cardBorder:         "#b0bec5",
        cardBorderSelected: "#455a64",
        timerColor:         "#1565c0",
        pausedColor:        "#bf360c",
        stepColor:          "#2e7d32",
        inputBg:            "#ffffff"
    })

    property color _bg:        "#ffffff"
    property color _bgSel:     "#dce8f0"
    property color _border:    "#b0bec5"
    property color _borderSel: "#455a64"
    property color _cardText:  "#000000"
    property color _timerClr:  "#1565c0"
    property color _pausedClr: "#bf360c"
    property color _stepClr:   "#2e7d32"

    function _luma(hex) {
        if (!hex || hex.length < 7) return 0.5;
        var r = parseInt(hex.slice(1,3),16)/255;
        var g = parseInt(hex.slice(3,5),16)/255;
        var b = parseInt(hex.slice(5,7),16)/255;
        return 0.299*r + 0.587*g + 0.114*b;
    }
    function _contrast(hex) { return _luma(hex) > 0.5 ? "#000000" : "#ffffff"; }

    function _applyTheme() {
        _bg        = themeColors.cardBg             || "#ffffff";
        _bgSel     = themeColors.cardBgSelected      || "#dce8f0";
        _border    = themeColors.cardBorder          || "#b0bec5";
        _borderSel = themeColors.cardBorderSelected  || "#455a64";
        _cardText  = _contrast(themeColors.cardBg    || "#ffffff");
        _timerClr  = themeColors.timerColor          || "#1565c0";
        _pausedClr = themeColors.pausedColor         || "#bf360c";
        _stepClr   = themeColors.stepColor           || "#2e7d32";
    }

    onThemeColorsChanged: _applyTheme()
    Component.onCompleted: _applyTheme()

    Rectangle {
        anchors.fill: parent
        radius: 8
        color:        root.selected ? root._bgSel     : root._bg
        border.color: root.selected ? root._borderSel : root._border
        border.width: root.selected ? 2 : 1
        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        MouseArea { anchors.fill: parent; onClicked: root.selected = !root.selected }
    }

    ColumnLayout {
        anchors.fill:    parent
        anchors.margins: 6
        spacing: 2

        Label {
            id:             titleLabel
            text:           "Pump"
            font.bold:      true
            font.pixelSize: 14
            color:          root._cardText
        }

        RowLayout {
            spacing: 4
            Label { text: "Set:";    font.pixelSize: 13; color: root._cardText }
            Label {
                id:             setFlowValue
                text:           "0.00"
                font.bold:      true
                font.pixelSize: 13
                color:          root._cardText
            }
            Label { text: "µL/min"; font.pixelSize: 13; color: Qt.alpha(root._cardText, 0.6) }
            Label { text: "•";      font.pixelSize: 13; color: Qt.alpha(root._cardText, 0.4) }
            Label { text: "pps:";   font.pixelSize: 13; color: root._cardText }
            Label {
                id:             ppsLabel
                text:           "0"
                font.bold:      true
                font.pixelSize: 13
                color:          root._cardText
            }
            Item { Layout.fillWidth: true }
        }

        Label {
            id:             infoLabel
            text:           ""
            font.pixelSize: 13
            color:          Qt.alpha(root._cardText, 0.65)
            Layout.fillWidth: true
            wrapMode:       Text.WordWrap
        }

        RowLayout {
            spacing: 6
            visible: timerLabel.text !== "" || root.paused

            Label {
                id:             timerLabel
                text:           ""
                font.pixelSize: 14
                font.bold:      true
                color:          root._timerClr
                visible:        text !== ""
            }
            Label {
                text:           "Paused"
                font.pixelSize: 13
                font.bold:      true
                color:          root._pausedClr
                visible:        root.paused
            }
        }

        Label {
            id:             stepLabel
            text:           ""
            font.pixelSize: 13
            color:          root._stepClr
            Layout.fillWidth: true
            visible:        text !== ""
        }
    }
}
