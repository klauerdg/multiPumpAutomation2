import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    implicitWidth:  280
    implicitHeight: 120

    property int    pumpId:  0
    property bool   priming: false
    property bool   selected: false

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

    // Resolved colours — updated via onThemeColorsChanged so QML reliably
    // re-paints even when the whole themeColors object is replaced.
    property color _bg:              "#ffffff"
    property color _bgSel:           "#dce8f0"
    property color _border:          "#b0bec5"
    property color _borderSel:       "#455a64"
    property color _cardText:        "#000000"
    property color _timerClr:        "#1565c0"
    property color _pausedClr:       "#bf360c"
    property color _stepClr:         "#2e7d32"
    property color _primeActive:     "#ffccbc"
    property color _primeInactive:   "#eceff1"

    function _luma(hex) {
        if (!hex || hex.length < 7) return 0.5;
        var r = parseInt(hex.slice(1,3),16)/255;
        var g = parseInt(hex.slice(3,5),16)/255;
        var b = parseInt(hex.slice(5,7),16)/255;
        return 0.299*r + 0.587*g + 0.114*b;
    }
    function _contrast(hex) { return _luma(hex) > 0.5 ? "#000000" : "#ffffff"; }

    function _applyTheme() {
        _bg           = themeColors.cardBg             || "#ffffff";
        _bgSel        = themeColors.cardBgSelected      || "#dce8f0";
        _border       = themeColors.cardBorder          || "#b0bec5";
        _borderSel    = themeColors.cardBorderSelected  || "#455a64";
        _cardText     = _contrast(themeColors.cardBg    || "#ffffff");
        _timerClr     = themeColors.timerColor          || "#1565c0";
        _pausedClr    = themeColors.pausedColor         || "#bf360c";
        _stepClr      = themeColors.stepColor           || "#2e7d32";
        _primeActive  = themeColors.primeActive         || "#ffccbc";
        _primeInactive = themeColors.primeInactive      || "#eceff1";
    }

    onThemeColorsChanged: _applyTheme()
    Component.onCompleted: _applyTheme()

    property alias titleLabel:  titleLabel
    property alias flowField:   flowField
    property alias primeButton: primeButton

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
        anchors.margins: 10
        spacing: 4

        Label {
            id: titleLabel
            text:           "Pump 1"
            font.bold:      true
            font.pixelSize: 13
            color:          root._cardText
        }

        RowLayout {
            spacing: 8
            Label {
                text:  "Flow:"
                color: root._cardText
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
                color: Qt.alpha(root._cardText, 0.6)
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }
            Button {
                id: primeButton
                text:           root.priming ? "Priming…" : "Prime"
                font.pixelSize: 12
                Layout.preferredWidth: 90
                background: Rectangle {
                    radius: 4
                    color:  root.priming ? root._primeActive : root._primeInactive
                }
            }
            Item { Layout.fillWidth: true }
        }

        ColumnLayout {
            visible: root.advMode !== ""
            spacing: 2
            Layout.fillWidth: true

            Label {
                visible:        root.advMode === "Constant"
                text:           "Run: " + root.advTotalMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color:          Qt.alpha(root._cardText, 0.65)
            }
            Label {
                visible:        root.advMode === "Constant" && root.advStepEnabled
                text:           "→ " + root.advStepFlow.toFixed(2)
                                + " µL/min at " + root.advStepMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color:          root._timerClr
            }
            Label {
                visible:        root.advMode === "Pulsatile"
                text:           root.advShape + " • " + root.advPeriod.toFixed(1) + "s period"
                                + (root.advShape === "Square"
                                   ? " • " + root.advDuty.toFixed(0) + "% duty" : "")
                font.pixelSize: 11
                color:          Qt.alpha(root._cardText, 0.65)
            }
            Label {
                visible:        root.advMode === "Pulsatile"
                text:           "Min: " + root.advMinFlow.toFixed(2)
                                + "  Max: " + root.advMaxFlow.toFixed(2)
                                + " • " + root.advTotalMinutes.toFixed(1) + " min"
                font.pixelSize: 11
                color:          Qt.alpha(root._cardText, 0.65)
            }
        }

        Item { Layout.fillHeight: true }
    }
}
