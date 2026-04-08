import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15
import Qt.labs.settings 1.1
import QtQuick.VirtualKeyboard 2.4

ApplicationWindow {
    id: app
    visible: true
    width: 1280
    height: 800
    title: "Microfluidic Pump Controller"

    // Pumps chosen for automation (by pump index 1..9)
    property var automationPumpIds: []
    // Pumps currently paused (Run page)
    property var pausedPumpIds: []
    // Run-tab timer seconds
    property int elapsedSec: 0

    // Automation timing / step info for Run tab
    property double automationTotalMinutes: 0.0
    property bool automationFinished: false
    property bool automationHasStep: false
    property double automationStepMinutes: 0.0
    property bool automationStepTriggered: false

    property var autoIds:      []
    property var autoModes:    []
    property var autoShapes:   []
    property var autoMins:     []
    property var autoPeriods:  []
    property var autoDuties:   []
    property var autoMinFlows: []
    property var autoMaxFlows: []
    property bool automationPending: false
    /* ===================== Small helpers ===================== */

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function getPumpFlow(pumpCard) {
        if (!pumpCard || !pumpCard.flowField)
            return 0.0;
        var v = parseFloat(pumpCard.flowField.text);
        return isNaN(v) ? 0.0 : v;
    }

    function setPumpFlow(pumpCard, value) {
        if (pumpCard && pumpCard.flowField)
            pumpCard.flowField.text = value.toFixed(2);
    }

    function isPumpSelected(pumpCard) {
        if (!pumpCard)
            return false;
        return pumpCard.selected === true;
    }

    function applyGroupFlowToSelected() {
        var v = parseFloat(setup.groupFlowField.text);
        if (isNaN(v) || v < 0)
            return;

        var pumps = [
            setup.pump1, setup.pump2, setup.pump3,
            setup.pump4, setup.pump5, setup.pump6,
            setup.pump7, setup.pump8, setup.pump9
        ];

        for (var i = 0; i < pumps.length; ++i) {
            if (!isPumpSelected(pumps[i])) continue;
            setPumpFlow(pumps[i], v);
            // Revert to simple mode — clear any advanced settings
            pumps[i].advMode = "";
        }

        console.log("Apply to Selected ->", v, "µL/min");
    }

    function markAutomationCompleteOnRunCards() {
        var runCards = [run.r1, run.r2, run.r3, run.r4,
                        run.r5, run.r6, run.r7, run.r8, run.r9];

        for (var i = 0; i < runCards.length; ++i) {
            var c = runCards[i];
            if (!c || !c.visible)
                continue;

            c.opacity = 0.5;
            if (c.infoLabel && c.infoLabel.text.indexOf("Run complete") === -1)
                c.infoLabel.text += " \u2022 Run complete";
        }
    }

    // Run page helpers
    function pumpIdFromRunCard(c) {
        if (!c)
            return -1;
        if (c.objectName && c.objectName.indexOf("pumpId:") === 0)
            return parseInt(c.objectName.substring(7));
        if (c.titleLabel.text.indexOf("Pump ") === 0)
            return parseInt(c.titleLabel.text.substring(5));
        return -1;
    }

    function selectedRunPumpIds() {
        var ids = [];
        var runCards = [run.r1, run.r2, run.r3, run.r4, run.r5, run.r6, run.r7, run.r8, run.r9];
        for (var i = 0; i < runCards.length; ++i) {
            var c = runCards[i];
            if (!c || !c.visible || !c.selected)
                continue;
            var pid = pumpIdFromRunCard(c);
            if (pid > 0 && ids.indexOf(pid) === -1)
                ids.push(pid);
        }
        return ids;
    }

    /* ===================== Preset storage (Setup flows) ===================== */

    Settings {
        id: presetSettings
        fileName: "presets.ini"
        category: "Presets"
        property string presetStore: "{}"
    }

    property var presetMap: (function () {
        try { return JSON.parse(presetSettings.presetStore); }
        catch(e) { return {}; }
    })()

    function persistPresets() {
        presetSettings.presetStore = JSON.stringify(presetMap);
    }

    function readCurrentConfig() {
        var cards = [setup.pump1, setup.pump2, setup.pump3,
                     setup.pump4, setup.pump5, setup.pump6,
                     setup.pump7, setup.pump8, setup.pump9];
        var flows = [];
        for (var i = 0; i < cards.length; ++i)
            flows.push(cards[i].flowField.text);
        return { flows: flows };
    }

    function applyConfig(cfg) {
        if (!cfg || !cfg.flows || cfg.flows.length !== 9)
            return;
        var cards = [setup.pump1, setup.pump2, setup.pump3,
                     setup.pump4, setup.pump5, setup.pump6,
                     setup.pump7, setup.pump8, setup.pump9];
        for (var i = 0; i < 9; ++i)
            cards[i].flowField.text = cfg.flows[i];
    }

    ListModel { id: presetNamesModel }

    Dialog {
        id: savePresetDialog
        modal: true
        title: "Save Preset"
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8
            Label { text: "Preset name:" }
            TextField { id: presetNameField; Layout.preferredWidth: 260 }
        }

        onAccepted: {
            var name = presetNameField.text.trim();
            if (!name.length)
                return;
            presetMap[name] = readCurrentConfig();
            persistPresets();
            console.log("Saved preset:", name);
        }
    }

    Dialog {
        id: loadPresetDialog
        modal: true
        title: "Load Preset"
        standardButtons: Dialog.Ok | Dialog.Cancel
        property int selectedIndex: -1

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8

            ListView {
                id: presetList
                model: presetNamesModel
                Layout.preferredWidth: 260
                Layout.preferredHeight: 200
                delegate: ItemDelegate {
                    width: ListView.view.width
                    text: name
                    onClicked: {
                        loadPresetDialog.selectedIndex = index;
                        presetList.currentIndex = index;
                    }
                }
            }
        }

        function refresh() {
            presetNamesModel.clear();
            var keys = Object.keys(presetMap).sort();
            for (var i = 0; i < keys.length; ++i)
                presetNamesModel.append({ "name": keys[i] });
            selectedIndex = presetNamesModel.count ? 0 : -1;
            presetList.currentIndex = selectedIndex;
        }

        onOpened: refresh()

        onAccepted: {
            if (selectedIndex < 0 || selectedIndex >= presetNamesModel.count)
                return;
            var name = presetNamesModel.get(selectedIndex).name;
            console.log("Load preset:", name);
            applyConfig(presetMap[name]);
        }
    }

    function handleSavePreset() { presetNameField.text = ""; savePresetDialog.open(); }
    function handleLoadPreset() { loadPresetDialog.open(); }

    /* ===================== Calibration (per-pump µL/min per pps) ===================== */

    Settings {
        id: calibrationSettings
        fileName: "calibration.ini"
        category: "Calibration"
        property string perPumpJson: ""   // JSON: [c1, c2, ..., c9]
    }

    // runtime array of 9 factors
    property var pumpCalFactors: (function () {
        try {
            var arr = JSON.parse(calibrationSettings.perPumpJson);
            if (arr && arr.length === 9)
                return arr;
        } catch(e) {}
        var def = [];
        for (var i = 0; i < 9; ++i) def.push(1.0);
        return def;
    })()

    function savePumpCalibration() {
        calibrationSettings.perPumpJson = JSON.stringify(pumpCalFactors);
    }

    function calibrationForPumpId(pid) {
        if (!pumpCalFactors || pid <= 0)
            return 1.0;
        if (pid - 1 >= pumpCalFactors.length)
            return 1.0;
        var f = pumpCalFactors[pid - 1];
        if (!f || f <= 0)
            return 1.0;
        return f;
    }

    function refreshRunPpsFromCalibration() {
        var runCards = [run.r1, run.r2, run.r3, run.r4,
                        run.r5, run.r6, run.r7, run.r8, run.r9];

        for (var i = 0; i < runCards.length; ++i) {
            var c = runCards[i];
            if (!c || !c.visible)
                continue;

            var pid = pumpIdFromRunCard(c);
            if (pid <= 0)
                continue;

            var flowVal = parseFloat(c.setFlowValue.text);
            if (isNaN(flowVal) || flowVal <= 0)
                continue;

            var factor = calibrationForPumpId(pid);
            var pps = factor > 0 ? (flowVal / factor) : 0.0;
            c.ppsLabel.text = pps.toFixed(0);
        }
    }

    Dialog {
        id: calibrationDialog
        modal: true
        title: "Per-pump Calibration (µL/min per pps)"
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8

            Label {
                text: "Enter calibration factors for each pump (µL/min per 1 pps).\n" +
                      "Existing values are kept if you leave a field blank."
                wrapMode: Text.WordWrap
            }

            GridLayout {
                columns: 3
                rowSpacing: 4
                columnSpacing: 10

                Label { text: "Pump 1"; font.pixelSize: 11 }
                TextField {
                    id: cal1; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 2"; font.pixelSize: 11 }
                TextField {
                    id: cal2; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 3"; font.pixelSize: 11 }
                TextField {
                    id: cal3; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 4"; font.pixelSize: 11 }
                TextField {
                    id: cal4; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 5"; font.pixelSize: 11 }
                TextField {
                    id: cal5; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 6"; font.pixelSize: 11 }
                TextField {
                    id: cal6; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 7"; font.pixelSize: 11 }
                TextField {
                    id: cal7; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 8"; font.pixelSize: 11 }
                TextField {
                    id: cal8; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 9"; font.pixelSize: 11 }
                TextField {
                    id: cal9; Layout.preferredWidth: 80; font.pixelSize: 11
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}
            }
        }

        onOpened: {
            // populate fields with current values
            var arr = pumpCalFactors;
            cal1.text = "" + arr[0];
            cal2.text = "" + arr[1];
            cal3.text = "" + arr[2];
            cal4.text = "" + arr[3];
            cal5.text = "" + arr[4];
            cal6.text = "" + arr[5];
            cal7.text = "" + arr[6];
            cal8.text = "" + arr[7];
            cal9.text = "" + arr[8];
        }

        onAccepted: {
            // read back; keep old value if field is empty or invalid
            var old = pumpCalFactors;
            var next = [];

            function upd(fieldText, idx) {
                var t = fieldText.trim();
                if (t.length === 0) {
                    next.push(old[idx]);   // keep old
                    return;
                }
                var v = parseFloat(t);
                if (isNaN(v) || v <= 0)
                    next.push(old[idx]);
                else
                    next.push(v);
            }

            upd(cal1.text, 0);
            upd(cal2.text, 1);
            upd(cal3.text, 2);
            upd(cal4.text, 3);
            upd(cal5.text, 4);
            upd(cal6.text, 5);
            upd(cal7.text, 6);
            upd(cal8.text, 7);
            upd(cal9.text, 8);

            pumpCalFactors = next;
            savePumpCalibration();
            refreshRunPpsFromCalibration();
        }
    }

    function openCalibrationDialog() {
        calibrationDialog.open();
    }

    /* ===================== Automation helpers ===================== */

    // Build Run page directly from Setup card advanced settings
    function populateRunFromSetup() {
        var setupCards = [setup.pump1, setup.pump2, setup.pump3,
                          setup.pump4, setup.pump5, setup.pump6,
                          setup.pump7, setup.pump8, setup.pump9];
        var runCards   = [run.r1, run.r2, run.r3, run.r4,
                          run.r5, run.r6, run.r7, run.r8, run.r9];

        // Clear run cards
        for (var k = 0; k < runCards.length; ++k) {
            var rc0 = runCards[k];
            if (!rc0) continue;
            rc0.visible = false;
            rc0.selected = false;
            rc0.paused = false;
            rc0.setFlowValue.text = "0.00";
            rc0.ppsLabel.text = "0";
            if (rc0.infoLabel) rc0.infoLabel.text = "";
            rc0.objectName = "";
            rc0.pumpEndSec = 0;
            rc0.pumpStepSec = -1;
            rc0.pumpStopped = false;
        }

        automationPumpIds = [];
        autoIds = []; autoModes = []; autoShapes = [];
        autoMins = []; autoPeriods = []; autoDuties = [];
        autoMinFlows = []; autoMaxFlows = [];

        var slot = 0;
        var hasPulsatile = false;

        for (var i = 0; i < setupCards.length && slot < runCards.length; ++i) {
            var sc = setupCards[i];
            if (!sc || !sc.flowField) continue;

            var f = parseFloat(sc.flowField.text);
            if (isNaN(f) || f <= 0) continue;

            var rc = runCards[slot++];
            rc.visible = true;
            rc.titleLabel.text = sc.titleLabel.text;
            rc.setFlowValue.text = f.toFixed(2);
            rc.opacity = 1.0;

            var pumpId = i + 1;
            rc.objectName = "pumpId:" + pumpId;

            var factor = calibrationForPumpId(pumpId);
            rc.ppsLabel.text = (factor > 0 ? (f / factor) : 0.0).toFixed(0);

            var mode    = sc.advMode;
            var summary = "";

            if (mode === "Constant") {
                summary = "Constant \u2022 " + sc.advTotalMinutes.toFixed(1) + " min";
                if (sc.advStepEnabled && sc.advStepMinutes > 0) {
                    summary += " \u2022 Change to " + sc.advStepFlow.toFixed(2)
                               + " \u00b5L/min at " + sc.advStepMinutes.toFixed(1) + " min";
                }
                rc.pumpEndSec  = Math.round(sc.advTotalMinutes * 60);
                rc.pumpStepSec = sc.advStepEnabled ? Math.round(sc.advStepMinutes * 60) : -1;

            } else if (mode === "Pulsatile") {
                summary = sc.advShape + " pulsatile \u2022 "
                          + sc.advTotalMinutes.toFixed(1) + " min \u2022 "
                          + sc.advPeriod.toFixed(1) + " s period";
                if (sc.advShape === "Square")
                    summary += " \u2022 " + sc.advDuty.toFixed(1) + "% duty";
                rc.pumpEndSec  = Math.round(sc.advTotalMinutes * 60);
                rc.pumpStepSec = -1;
                hasPulsatile   = true;

            } else {
                summary = "Manual mode \u2022 No time limit";
                rc.pumpEndSec  = 0;
                rc.pumpStepSec = -1;
            }

            rc.infoLabel.text = summary;

            automationPumpIds.push(pumpId);
            autoIds.push(pumpId);
            autoModes.push(mode === "" ? "Constant" : mode);
            autoShapes.push(sc.advShape  || "Square");
            autoMins.push(sc.advTotalMinutes > 0 ? sc.advTotalMinutes : 5.0);
            autoPeriods.push(sc.advPeriod > 0 ? sc.advPeriod : 2.0);
            autoDuties.push((sc.advDuty  > 0 ? sc.advDuty : 50.0) / 100.0);
            autoMinFlows.push(sc.advMinFlow);
            autoMaxFlows.push(sc.advMaxFlow > 0 ? sc.advMaxFlow : f);
        }

        var maxMin = 0.0;
        for (var m = 0; m < autoMins.length; ++m)
            if (autoMins[m] > maxMin) maxMin = autoMins[m];
        automationTotalMinutes = maxMin;
        automationPending = hasPulsatile && autoIds.length > 0;

        console.log("Run pumps:", automationPumpIds);
    }

    /* ===================== Advanced Settings Dialog ===================== */

    Dialog {
        id: advancedDialog
        modal: true
        title: "Advanced Settings"
        width: 440
        standardButtons: Dialog.NoButton

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8

            RowLayout {
                spacing: 8
                Label { text: "Mode:"; font.pixelSize: 12 }
                ComboBox {
                    id: advModeCombo
                    model: ["Constant", "Pulsatile"]
                    font.pixelSize: 12
                    Layout.preferredWidth: 120
                    onCurrentTextChanged: {
                        if (currentText === "Pulsatile") {
                            var bf = parseFloat(advBaseFlowField.text);
                            if (!isNaN(bf) && bf > 0)
                                advMaxFlowField.text = bf.toFixed(2);
                        }
                    }
                }
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Pulsatile"
                Label { text: "Shape:"; font.pixelSize: 12 }
                ComboBox {
                    id: advShapeCombo
                    model: ["Square", "Sinusoidal"]
                    font.pixelSize: 12
                    Layout.preferredWidth: 120
                }
            }

            // Base flow (Constant) or Max flow (Pulsatile)
            RowLayout {
                spacing: 8
                Label {
                    text: advModeCombo.currentText === "Pulsatile" ? "Max flow (µL/min):" : "Base flow (µL/min):"
                    font.pixelSize: 12
                }
                TextField {
                    id: advBaseFlowField
                    visible: advModeCombo.currentText === "Constant"
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                TextField {
                    id: advMaxFlowField
                    visible: advModeCombo.currentText === "Pulsatile"
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Pulsatile"
                Label { text: "Period (s):"; font.pixelSize: 12 }
                TextField {
                    id: advPeriodField
                    text: "2.0"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Pulsatile" && advShapeCombo.currentText === "Square"
                Label { text: "Duty (%):"; font.pixelSize: 12 }
                TextField {
                    id: advDutyField
                    text: "50"
                    validator: DoubleValidator { bottom: 1; top: 99; decimals: 1 }
                    Layout.preferredWidth: 70
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Pulsatile"
                Label { text: "Min flow (µL/min):"; font.pixelSize: 12 }
                TextField {
                    id: advMinFlowField
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                Label { text: "Total run time (min):"; font.pixelSize: 12 }
                TextField {
                    id: advTotalMinutesField
                    text: "5.0"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            CheckBox {
                id: advStepCheck
                text: "Change flow after time"
                font.pixelSize: 12
                visible: advModeCombo.currentText === "Constant"
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Constant" && advStepCheck.checked
                Label { text: "After (min):"; font.pixelSize: 12 }
                TextField {
                    id: advStepMinField
                    text: "2.0"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 70
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Label { text: "New flow (µL/min):"; font.pixelSize: 12 }
                TextField {
                    id: advStepFlowField
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 12
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }
        }

        footer: RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: "Close"
                onClicked: advancedDialog.close()
            }
            Button {
                text: "Apply Advanced Settings"
                onClicked: {
                    var pumps = [setup.pump1, setup.pump2, setup.pump3,
                                 setup.pump4, setup.pump5, setup.pump6,
                                 setup.pump7, setup.pump8, setup.pump9];
                    var mode = advModeCombo.currentText;
                    for (var i = 0; i < pumps.length; ++i) {
                        var card = pumps[i];
                        if (!card || !card.selected) continue;
                        card.advMode         = mode;
                        card.advTotalMinutes = parseFloat(advTotalMinutesField.text) || 5.0;
                        if (mode === "Constant") {
                            var bf = parseFloat(advBaseFlowField.text);
                            if (!isNaN(bf) && bf >= 0) card.flowField.text = bf.toFixed(2);
                            card.advStepEnabled = advStepCheck.checked;
                            card.advStepMinutes = parseFloat(advStepMinField.text)  || 2.0;
                            card.advStepFlow    = parseFloat(advStepFlowField.text) || 0.0;
                        } else {
                            card.advShape   = advShapeCombo.currentText;
                            var mf = parseFloat(advMaxFlowField.text);
                            if (!isNaN(mf) && mf >= 0) card.flowField.text = mf.toFixed(2);
                            card.advMaxFlow = isNaN(mf) ? 0.0 : mf;
                            card.advPeriod  = parseFloat(advPeriodField.text)  || 2.0;
                            card.advDuty    = parseFloat(advDutyField.text)    || 50.0;
                            card.advMinFlow = parseFloat(advMinFlowField.text) || 0.0;
                        }
                    }
                    advancedDialog.close();
                }
            }
        }
    }

    /* ===================== Tabs & Pages ===================== */

    header: TabBar {
        id: tabs
        TabButton { text: "Set up" }
        TabButton { text: "Run" }
    }

    StackLayout {
        id: stack
        anchors.fill: parent
        currentIndex: tabs.currentIndex

        // ---- Setup page ----
        SetupPageForm {
            id: setup
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // ---- Run page ----
        RunPageForm {
            id: run
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    /* ===================== Run timer ===================== */

    Timer {
        id: runTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            // --- update big timer ---
            elapsedSec += 1;
            var h = Math.floor(elapsedSec / 3600);
            var m = Math.floor((elapsedSec % 3600) / 60);
            var s = elapsedSec % 60;
            run.runTimeLabel.text = pad(h) + ":" + pad(m) + ":" + pad(s);

            // --- per-pump step changes (constant mode) ---
            var runCards = [run.r1, run.r2, run.r3, run.r4,
                            run.r5, run.r6, run.r7, run.r8, run.r9];
            var marker = "Change to ";

            for (var i = 0; i < runCards.length; ++i) {
                var c = runCards[i];
                if (!c || !c.visible || !c.infoLabel)
                    continue;

                var text = c.infoLabel.text;

                var idxMarker = text.indexOf(marker);
                if (idxMarker === -1)
                    continue;

                if (text.indexOf("Flow changed to ") !== -1)
                    continue;

                var idxAt  = text.indexOf(" at ", idxMarker + marker.length);
                var idxMin = text.indexOf(" min", idxAt);
                if (idxAt === -1 || idxMin === -1)
                    continue;

                var flowStr = text.substring(idxMarker + marker.length, idxAt).trim();
                var timeStr = text.substring(idxAt + 4, idxMin).trim();

                var stepMinutes = parseFloat(timeStr);
                if (isNaN(stepMinutes) || stepMinutes <= 0)
                    continue;

                if (elapsedSec < stepMinutes * 60)
                    continue;

                var flowVal = parseFloat(flowStr);
                if (!isNaN(flowVal)) {
                    if (c.setFlowValue)
                        c.setFlowValue.text = flowVal.toFixed(2);

                    if (c.ppsLabel) {
                        var pid2_forPps = pumpIdFromRunCard(c);
                        var factor2 = calibrationForPumpId(pid2_forPps);
                        var pps2 = factor2 > 0 ? (flowVal / factor2) : 0.0;
                        c.ppsLabel.text = pps2.toFixed(0);
                    }

                    if (typeof backend !== "undefined" && backend.set_flow) {
                        var pid2 = pumpIdFromRunCard(c);
                        if (pid2 > 0)
                            backend.set_flow(pid2, flowVal);
                    }
                }

                var tag = "Flow changed to " + flowStr + " at " + stepMinutes.toFixed(1) + " min";
                c.infoLabel.text = text + " \u2022 " + tag;

                run.statusLabel.text = "Flow changed at " + stepMinutes.toFixed(1) + " min.";
            }
            // --- per-pump countdown & step-change labels ---
            for (var pi = 0; pi < runCards.length; ++pi) {
                var pc = runCards[pi];
                if (!pc || !pc.visible) continue;

                // Main countdown
                if (pc.pumpEndSec > 0) {
                    var remSec = Math.max(0, pc.pumpEndSec - elapsedSec);
                    if (remSec > 0) {
                        var remM = Math.floor(remSec / 60);
                        var remS = remSec % 60;
                        pc.timerLabel.text = remM + ":" + pad(remS) + " remaining";
                    } else if (!pc.pumpStopped) {
                        pc.pumpStopped = true;
                        pc.timerLabel.text = "Done";
                        var stopPid = pumpIdFromRunCard(pc);
                        if (stopPid > 0 && typeof backend !== "undefined" && backend.stop)
                            backend.stop(stopPid);
                    }
                }

                // Step-change countdown
                if (pc.pumpStepSec > 0) {
                    if (elapsedSec < pc.pumpStepSec) {
                        var stRem = pc.pumpStepSec - elapsedSec;
                        var stM = Math.floor(stRem / 60);
                        var stS = stRem % 60;
                        pc.stepLabel.text = "Step in " + stM + ":" + pad(stS);
                    } else {
                        pc.stepLabel.text = "";   // step already fired
                    }
                }
            }

            // --- Automation finished indicator (timed runs) ---
            if (!automationFinished &&
                automationTotalMinutes > 0 &&
                elapsedSec >= automationTotalMinutes * 60) {

                automationFinished = true;
                runTimer.stop();

                if (typeof backend !== "undefined" && backend.stopAll)
                    backend.stopAll();

                run.statusLabel.text = "Automation complete.";
                markAutomationCompleteOnRunCards();
            }
        }
    }

    // On-screen keyboard for touch use
    InputPanel {
        id: kb
        z: 9999
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: Qt.inputMethod.visible
    }

    onActiveFocusItemChanged: {
        if (activeFocusItem && activeFocusItem.inputMethodHints !== undefined)
            Qt.inputMethod.show();
    }

    /* ===================== Wiring on startup ===================== */

    Component.onCompleted: {
        console.log("Main loaded");

        if (typeof backend !== "undefined" && backend.refreshPorts)
            backend.refreshPorts();

        // Setup buttons
        setup.applyGroupButton.clicked.connect(app.applyGroupFlowToSelected);
        setup.readyToRunButton.clicked.connect(function () {
            app.populateRunFromSetup();
            automationFinished = false;
            elapsedSec = 0;
            run.runTimeLabel.text = "00:00:00";
            tabs.currentIndex = 1;   // go to Run tab
        });
        setup.advancedButton.clicked.connect(function () {
            // Pre-populate base flow from first selected pump
            var pumps = [setup.pump1, setup.pump2, setup.pump3,
                         setup.pump4, setup.pump5, setup.pump6,
                         setup.pump7, setup.pump8, setup.pump9];
            for (var i = 0; i < pumps.length; ++i) {
                if (pumps[i] && pumps[i].selected) {
                    advBaseFlowField.text = pumps[i].flowField.text;
                    advMaxFlowField.text  = pumps[i].flowField.text;
                    break;
                }
            }
            advancedDialog.open();
        });
        setup.savePresetButton.clicked.connect(app.handleSavePreset);
        setup.loadPresetButton.clicked.connect(app.handleLoadPreset);
        if (setup.calibrationButton)
            setup.calibrationButton.clicked.connect(app.openCalibrationDialog);

        // Prime buttons: toggle full-speed priming
        var setupCards = [setup.pump1, setup.pump2, setup.pump3,
                          setup.pump4, setup.pump5, setup.pump6,
                          setup.pump7, setup.pump8, setup.pump9];

        for (var i = 0; i < setupCards.length; ++i) {
            var card = setupCards[i];
            if (!card || !card.primeButton)
                continue;

            card.priming = false;

            card.primeButton.clicked.connect((function (c) {
                return function () {
                    var pid = c.pumpId;
                    if (pid <= 0)
                        return;

                    c.priming = !c.priming;
                    console.log("Prime toggle for pump", pid, "->", c.priming);

                    if (typeof backend === "undefined")
                        return;

                    if (c.priming) {
                        if (backend.prime)
                            backend.prime(pid);
                    } else {
                        if (backend.stop)
                            backend.stop(pid);
                    }
                }
            })(card));
        }

        // Run buttons
        run.startButton.clicked.connect(function () {
            var runCards = [run.r1, run.r2, run.r3, run.r4,
                            run.r5, run.r6, run.r7, run.r8, run.r9];

            if (automationPending && typeof backend !== "undefined" && backend.startAutomation) {
                automationFinished = false;
                backend.startAutomation(autoIds, autoModes, autoShapes, autoMins,
                                        autoPeriods, autoDuties, autoMinFlows, autoMaxFlows);
            }

            if (typeof backend !== "undefined" && backend.set_flow) {
                for (var i = 0; i < runCards.length; ++i) {
                    var c = runCards[i];
                    if (!c || !c.visible) continue;
                    var pid = pumpIdFromRunCard(c);
                    if (pid <= 0) continue;
                    var f = parseFloat(c.setFlowValue.text);
                    if (isNaN(f) || f <= 0) continue;
                    backend.set_flow(pid, f);
                }
            }

            if (!runTimer.running)
                runTimer.start();
        });

        run.pauseButton.clicked.connect(function () {
            runTimer.stop();
            if (typeof backend !== "undefined" && backend.pauseAll)
                backend.pauseAll();
        });

        run.stopButton.clicked.connect(function () {
            runTimer.stop();
            elapsedSec = 0;
            run.runTimeLabel.text = "00:00:00";
            pausedPumpIds = [];
            if (typeof backend !== "undefined" && backend.stopAll)
                backend.stopAll();

            var runCards = [run.r1, run.r2, run.r3, run.r4, run.r5, run.r6, run.r7, run.r8, run.r9];
            for (var j = 0; j < runCards.length; ++j) {
                var c2 = runCards[j];
                if (!c2) continue;
                c2.paused = false;
                if (c2.timerLabel) c2.timerLabel.text = "";
                if (c2.stepLabel)  c2.stepLabel.text  = "";
            }

            automationFinished = true;
            automationStepTriggered = false;
            run.statusLabel.text = (automationTotalMinutes === 0.0)
                    ? "Manual run stopped."
                    : "Automation stopped.";
        });
        //ToBeFixed pause button should pause individual automation timers
        // Pause selected
        run.pauseSelectedButton.clicked.connect(function () {
            var ids = selectedRunPumpIds();
            console.log("Pause selected pumps:", ids);

            var runCards = [run.r1, run.r2, run.r3, run.r4,
                            run.r5, run.r6, run.r7, run.r8, run.r9];
            for (var j = 0; j < runCards.length; ++j) {
                var c3 = runCards[j];
                if (!c3 || !c3.visible || !c3.selectCheck.checked)
                    continue;
                var pid = pumpIdFromRunCard(c3);
                if (ids.indexOf(pid) !== -1) {
                    c3.paused = true;
                    if (pausedPumpIds.indexOf(pid) === -1)
                        pausedPumpIds.push(pid);
                }
            }

            if (typeof backend !== "undefined" && backend.pausePumps)
                backend.pausePumps(ids);
        });

        // Resume selected
        run.resumeSelectedButton.clicked.connect(function () {
            var ids = selectedRunPumpIds();
            console.log("Resume selected pumps:", ids);

            var runCards = [run.r1, run.r2, run.r3, run.r4,
                            run.r5, run.r6, run.r7, run.r8, run.r9];
            for (var j = 0; j < runCards.length; ++j) {
                var c4 = runCards[j];
                if (!c4 || !c4.visible || !c4.selectCheck.checked)
                    continue;
                var pid = pumpIdFromRunCard(c4);
                if (ids.indexOf(pid) !== -1) {
                    c4.paused = false;
                    var idx = pausedPumpIds.indexOf(pid);
                    if (idx !== -1)
                        pausedPumpIds.splice(idx, 1);
                }
            }

            if (typeof backend !== "undefined" && backend.resumePumps)
                backend.resumePumps(ids);
        });

    }
}
