import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15
import Qt.labs.settings 1.1
import QtQuick.VirtualKeyboard 2.4

ApplicationWindow {
    id: app
    visible: true
    width:  1024
    height: 600
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

    /* ===================== Theme system ===================== */

    // Built-in theme presets
    readonly property var _bluesLight: ({
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

    readonly property var _dark: ({
        pageBg:             "#0d1b2a",
        toolbarBg:          "#0a1225",
        cardBg:             "#1a2a3a",
        cardBgSelected:     "#1a3a5c",
        cardBorder:         "#2a4060",
        cardBorderSelected: "#42a5f5",
        buttonBg:           "#2a3a4a",
        buttonFlash:        "#1a2535",
        timerColor:         "#ffffff",
        pausedColor:        "#ffffff",
        stepColor:          "#ffffff",
        primeActive:        "#7f2a20",
        primeInactive:      "#2a3a4a"
    })

    // Currently active theme object
    property var theme: _bluesLight

    // User-saved custom themes (name → color object), loaded from file on start
    property var savedThemes: ({})

    function switchTheme(t) {
        theme = t;
        // Push directly to every card — property-var binding chains are
        // unreliable across multiple component boundaries in Qt 5/6.
        var sc = [setup.pump1, setup.pump2, setup.pump3,
                  setup.pump4, setup.pump5, setup.pump6,
                  setup.pump7, setup.pump8, setup.pump9];
        for (var i = 0; i < sc.length; i++)
            if (sc[i]) sc[i].themeColors = t;
        var rc = [run.r1, run.r2, run.r3, run.r4,
                  run.r5, run.r6, run.r7, run.r8, run.r9];
        for (var j = 0; j < rc.length; j++)
            if (rc[j]) rc[j].themeColors = t;
        setup.themeColors = t;
        run.themeColors   = t;
    }

    function persistTheme() {
        var payload = JSON.stringify({
            saved: savedThemes,
            current: theme
        });
        if (typeof backend !== "undefined" && backend.save_theme)
            backend.save_theme(payload);
    }

    // Auto-compute black or white text to contrast against a hex background colour
    function contrastColor(hex) {
        if (!hex || hex.length < 7) return "#000000";
        var r = parseInt(hex.slice(1, 3), 16) / 255;
        var g = parseInt(hex.slice(3, 5), 16) / 255;
        var b = parseInt(hex.slice(5, 7), 16) / 255;
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.5 ? "#000000" : "#ffffff";
    }

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

    /* ===================== Preset storage ===================== */

    property var presetMap: ({})

    function persistPresets() {
        var json = JSON.stringify(presetMap);
        console.log("persistPresets: keys=" + Object.keys(presetMap).length + " len=" + json.length);
        if (typeof backend !== "undefined" && backend.save_presets) {
            backend.save_presets(json);
        } else {
            console.log("persistPresets: backend.save_presets not available");
        }
    }

    function readCurrentConfig() {
        var cards = [setup.pump1, setup.pump2, setup.pump3,
                     setup.pump4, setup.pump5, setup.pump6,
                     setup.pump7, setup.pump8, setup.pump9];
        var flows = [], modes = [], shapes = [], periods = [], duties = [];
        var minFlows = [], maxFlows = [], totalMins = [];
        var stepEnabled = [], stepMins = [], stepFlows = [];
        for (var i = 0; i < cards.length; ++i) {
            var c = cards[i];
            flows.push(c.flowField.text);
            modes.push(c.advMode);
            shapes.push(c.advShape);
            periods.push(c.advPeriod);
            duties.push(c.advDuty);
            minFlows.push(c.advMinFlow);
            maxFlows.push(c.advMaxFlow);
            totalMins.push(c.advTotalMinutes);
            stepEnabled.push(c.advStepEnabled);
            stepMins.push(c.advStepMinutes);
            stepFlows.push(c.advStepFlow);
        }
        return { flows: flows, modes: modes, shapes: shapes, periods: periods,
                 duties: duties, minFlows: minFlows, maxFlows: maxFlows,
                 totalMins: totalMins, stepEnabled: stepEnabled,
                 stepMins: stepMins, stepFlows: stepFlows };
    }

    function applyConfig(cfg) {
        if (!cfg || !cfg.flows || cfg.flows.length !== 9)
            return;
        var cards = [setup.pump1, setup.pump2, setup.pump3,
                     setup.pump4, setup.pump5, setup.pump6,
                     setup.pump7, setup.pump8, setup.pump9];
        for (var i = 0; i < 9; ++i) {
            cards[i].flowField.text = cfg.flows[i];
            if (cfg.modes) {
                cards[i].advMode         = cfg.modes[i]       || "";
                cards[i].advShape        = cfg.shapes[i]      || "Square";
                cards[i].advPeriod       = cfg.periods[i]     || 2.0;
                cards[i].advDuty         = cfg.duties[i]      || 50.0;
                cards[i].advMinFlow      = cfg.minFlows[i]    || 0.0;
                cards[i].advMaxFlow      = cfg.maxFlows[i]    || 0.0;
                cards[i].advTotalMinutes = cfg.totalMins[i]   || 5.0;
                cards[i].advStepEnabled  = cfg.stepEnabled[i] || false;
                cards[i].advStepMinutes  = cfg.stepMins[i]    || 2.0;
                cards[i].advStepFlow     = cfg.stepFlows[i]   || 0.0;
            }
        }
    }

    ListModel { id: presetNamesModel }

    Dialog {
        id: savePresetDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
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
            var updated = presetMap;
            updated[name] = readCurrentConfig();
            presetMap = updated;   // reassign so QML detects the change
            persistPresets();
            console.log("Saved preset:", name);
        }
    }

    Dialog {
        id: loadPresetDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        title: "Load Preset"
        standardButtons: Dialog.NoButton
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

        footer: RowLayout {
            spacing: 8
            Button {
                text: "Delete Preset"
                font.pixelSize: 11
                enabled: loadPresetDialog.selectedIndex >= 0
                onClicked: {
                    if (loadPresetDialog.selectedIndex < 0) return;
                    var name = presetNamesModel.get(loadPresetDialog.selectedIndex).name;
                    var updated = JSON.parse(JSON.stringify(presetMap));
                    delete updated[name];
                    presetMap = updated;
                    persistPresets();
                    loadPresetDialog.refresh();
                }
                background: Rectangle { radius: 4; color: "#c62828" }
                contentItem: Text {
                    text: parent.text; font: parent.font; color: "#fff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                font.pixelSize: 12
                onClicked: loadPresetDialog.close()
            }
            Button {
                text: "Load"
                font.pixelSize: 12
                enabled: loadPresetDialog.selectedIndex >= 0
                onClicked: {
                    if (loadPresetDialog.selectedIndex < 0 ||
                        loadPresetDialog.selectedIndex >= presetNamesModel.count) return;
                    var name = presetNamesModel.get(loadPresetDialog.selectedIndex).name;
                    console.log("Load preset:", name);
                    applyConfig(presetMap[name]);
                    loadPresetDialog.close();
                }
            }
        }
    }

    function handleSavePreset() { presetNameField.text = ""; savePresetDialog.open(); }
    function handleLoadPreset() { loadPresetDialog.open(); }

    /* ===================== Theme Settings Dialog ===================== */

    // Helper to build a color-row: label + swatch + hex field
    // (Declared as a Component so we can reuse it inside the dialog's GridLayout)

    Dialog {
        id: themeDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        title: "Theme Settings"
        width: 575

        property var editColors: ({})   // working copy while dialog is open

        function loadEditor(src) {
            // Deep-copy the source into editColors so we can cancel without side-effects
            editColors = JSON.parse(JSON.stringify(src));
            // Refresh all the TextField bindings (they read editColors[key])
            editColorRepeater.model = 0;
            editColorRepeater.model = colorKeys.length;
        }

        onOpened: loadEditor(app.theme)

        // Ordered list of (key, label) pairs shown in the dialog
        property var colorKeys: [
            ["pageBg",             "Page background"],
            ["toolbarBg",          "Toolbar"],
            ["cardBg",             "Card background"],
            ["cardBgSelected",     "Card selected bg"],
            ["cardBorder",         "Card border"],
            ["cardBorderSelected", "Card selected border"],
            ["buttonBg",           "Button"],
            ["buttonFlash",        "Button flash"],
            ["timerColor",         "Timer text"],
            ["pausedColor",        "Paused badge"],
            ["stepColor",          "Step-change text"],
            ["primeActive",        "Prime (active)"],
            ["primeInactive",      "Prime (idle)"]
        ]

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 10

            // ── Preset row ────────────────────────────────────────────────────
            RowLayout {
                spacing: 8
                Label { text: "Preset:"; font.pixelSize: 13 }
                Button {
                    text: "Blues Light"
                    font.pixelSize: 12
                    Layout.preferredWidth: 110
                    onClicked: themeDialog.loadEditor(app._bluesLight)
                    background: Rectangle {
                        radius: 4; color: "#1976d2"
                    }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#fff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                }
                Button {
                    text: "Dark"
                    font.pixelSize: 12
                    Layout.preferredWidth: 80
                    onClicked: themeDialog.loadEditor(app._dark)
                    background: Rectangle {
                        radius: 4; color: "#0a1225"
                    }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#e0f0ff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                }
                Item { Layout.fillWidth: true }
                // Saved custom themes
                ComboBox {
                    id: savedThemeCombo
                    model: Object.keys(app.savedThemes)
                    Layout.preferredWidth: 120
                    visible: count > 0
                    onActivated: {
                        var t = app.savedThemes[currentText];
                        if (t) themeDialog.loadEditor(t);
                    }
                }
                Button {
                    text: "Delete"
                    font.pixelSize: 11
                    Layout.preferredWidth: 65
                    visible: savedThemeCombo.count > 0
                    onClicked: {
                        var name = savedThemeCombo.currentText;
                        if (!name) return;
                        var updated = JSON.parse(JSON.stringify(app.savedThemes));
                        delete updated[name];
                        app.savedThemes = updated;
                        savedThemeCombo.model = Object.keys(app.savedThemes);
                        app.persistTheme();
                    }
                    background: Rectangle { radius: 4; color: "#c62828" }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#fff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                }
            }

            // ── Color fields ──────────────────────────────────────────────────
            GridLayout {
                columns: 2
                rowSpacing:    6
                columnSpacing: 16
                Layout.fillWidth: true

                Repeater {
                    id: editColorRepeater
                    model: themeDialog.colorKeys.length

                    delegate: RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        property string colorKey:   themeDialog.colorKeys[index][0]
                        property string colorLabel: themeDialog.colorKeys[index][1]

                        Label {
                            text:  colorLabel
                            font.pixelSize: 11
                            Layout.preferredWidth: 130
                        }

                        // Colour swatch — tap to open color wheel picker
                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: themeDialog.editColors[colorKey] || "#888888"
                            border.color: swatchArea.containsMouse ? "#fff" : "#555"
                            border.width: swatchArea.containsMouse ? 2 : 1
                            MouseArea {
                                id: swatchArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    colorPicker.activeKey    = colorKey;
                                    colorPicker.initialColor = themeDialog.editColors[colorKey] || "#888888";
                                    colorPicker.open();
                                }
                            }
                        }

                        // Hex text field
                        TextField {
                            id: hexField
                            text: themeDialog.editColors[colorKey] || ""
                            font.pixelSize: 11
                            Layout.preferredWidth: 80
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            onEditingFinished: {
                                var v = text.trim();
                                if (/^#[0-9a-fA-F]{3,8}$/.test(v)) {
                                    var tmp = JSON.parse(JSON.stringify(themeDialog.editColors));
                                    tmp[colorKey] = v;
                                    themeDialog.editColors = tmp;
                                    // reset model to refresh swatches
                                    editColorRepeater.model = 0;
                                    editColorRepeater.model = themeDialog.colorKeys.length;
                                }
                            }
                        }
                    }
                }
            }

            // ── Save custom theme row ─────────────────────────────────────────
            RowLayout {
                spacing: 8
                Label { text: "Save as:"; font.pixelSize: 12 }
                TextField {
                    id: customThemeNameField
                    placeholderText: "My Theme"
                    font.pixelSize: 12
                    Layout.preferredWidth: 160
                }
                Button {
                    text: "Save Theme"
                    font.pixelSize: 12
                    Layout.preferredWidth: 100
                    onClicked: {
                        var n = customThemeNameField.text.trim();
                        if (!n.length) return;
                        var updated = JSON.parse(JSON.stringify(app.savedThemes));
                        updated[n] = JSON.parse(JSON.stringify(themeDialog.editColors));
                        app.savedThemes = updated;
                        savedThemeCombo.model = Object.keys(app.savedThemes);
                        app.persistTheme();
                        customThemeNameField.text = "";
                    }
                }
            }
        }

        footer: RowLayout {
            spacing: 8
            Button {
                text: "Delete Theme"
                font.pixelSize: 11
                visible: savedThemeCombo.count > 0
                onClicked: {
                    var name = savedThemeCombo.currentText;
                    if (!name) return;
                    var updated = JSON.parse(JSON.stringify(app.savedThemes));
                    delete updated[name];
                    app.savedThemes = updated;
                    savedThemeCombo.model = Object.keys(app.savedThemes);
                    app.persistTheme();
                }
                background: Rectangle { radius: 4; color: "#c62828" }
                contentItem: Text {
                    text: parent.text; font: parent.font; color: "#fff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                font.pixelSize: 12
                onClicked: themeDialog.close()
            }
            Button {
                text: "Apply"
                font.pixelSize: 12
                onClicked: {
                    app.switchTheme(JSON.parse(JSON.stringify(themeDialog.editColors)));
                    app.persistTheme();
                    themeDialog.close();
                }
            }
        }
    }

    // Color wheel picker — opened from theme dialog swatches
    ColorPickerDialog {
        id: colorPicker
        property string activeKey: ""
        onColorAccepted: function(hex) {
            var tmp = JSON.parse(JSON.stringify(themeDialog.editColors));
            tmp[activeKey] = hex;
            themeDialog.editColors = tmp;
            editColorRepeater.model = 0;
            editColorRepeater.model = themeDialog.colorKeys.length;
        }
    }

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
        closePolicy: Popup.CloseOnEscape
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
            rc0.rawFlow = 0.0;
            rc0.setFlowValue.text = "0.00";
            rc0.ppsLabel.text = "0";
            if (rc0.infoLabel) rc0.infoLabel.text = "";
            rc0.objectName = "";
            rc0.pumpEndSec = 0;
            rc0.pumpStepSec = -1;
            rc0.pumpStopped = false;
            rc0.pumpPausedAt = -1;
            rc0.pumpPausedAccum = 0;
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
            rc.rawFlow = f;
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
                rc.setFlowValue.text = sc.advMinFlow.toFixed(2) + " - " + sc.advMaxFlow.toFixed(2);
                summary = sc.advShape + " pulsatile \u2022 "
                          + sc.advTotalMinutes.toFixed(1) + " min \u2022 "
                          + sc.advPeriod.toFixed(1) + " s period";
                if (sc.advShape === "Square")
                    summary += " \u2022 " + sc.advDuty.toFixed(1) + "% duty";
                rc.pumpEndSec  = Math.round(sc.advTotalMinutes * 60);
                rc.pumpStepSec = -1;
                hasPulsatile   = true;

            } else {
                rc.setFlowValue.text = f.toFixed(2);
                summary = "Manual mode \u2022 No time limit";
                rc.pumpEndSec  = 0;
                rc.pumpStepSec = -1;
            }

            if (mode === "Constant")
                rc.setFlowValue.text = f.toFixed(2);

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
        closePolicy: Popup.CloseOnEscape
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

    header: Rectangle {
        width:  parent.width
        height: 42
        color:  app.theme.toolbarBg || "#1565c0"
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            TabBar {
                id: tabs
                Layout.fillWidth: true
                background: Rectangle { color: "transparent" }

                TabButton {
                    text: "Set up"
                    font.pixelSize: 13
                    contentItem: Text {
                        text:  parent.text
                        font:  parent.font
                        color: parent.checked
                               ? (app.theme.toolbarBg    || "#1565c0")
                               : (app.theme.toolbarText  || "#ffffff")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked
                               ? (app.theme.pageBg    || "#e3f2fd")
                               : "transparent"
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                TabButton {
                    text: "Run"
                    font.pixelSize: 13
                    contentItem: Text {
                        text:  parent.text
                        font:  parent.font
                        color: parent.checked
                               ? (app.theme.toolbarBg   || "#1565c0")
                               : (app.theme.toolbarText || "#ffffff")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked
                               ? (app.theme.pageBg   || "#e3f2fd")
                               : "transparent"
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }
            }

            // Gear / theme-settings button
            Button {
                id: themeSettingsBtn
                text: "⚙"
                font.pixelSize: 18
                Layout.preferredWidth:  42
                Layout.preferredHeight: 42
                flat: true
                onClicked: themeDialog.open()
                contentItem: Text {
                    text:  parent.text
                    font:  parent.font
                    color: app.theme.toolbarText || "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(app.theme.toolbarBg || "#1565c0", 1.3)
                                          : "transparent"
                }
            }
        }
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

                if (c.paused) continue;   // don't fire step changes while paused

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

                // Effective elapsed: freeze at the moment this pump was paused
                var pcEff = pc.paused
                    ? Math.max(0, pc.pumpPausedAt - pc.pumpPausedAccum)
                    : (elapsedSec - pc.pumpPausedAccum);

                // Main countdown
                if (pc.pumpEndSec > 0) {
                    var remSec = Math.max(0, pc.pumpEndSec - pcEff);
                    if (remSec > 0) {
                        var remM = Math.floor(remSec / 60);
                        var remS = remSec % 60;
                        pc.timerLabel.text = remM + ":" + pad(remS) + " remaining";
                    } else if (!pc.pumpStopped && !pc.paused) {
                        pc.pumpStopped = true;
                        pc.timerLabel.text = "Done";
                        var stopPid = pumpIdFromRunCard(pc);
                        if (stopPid > 0 && typeof backend !== "undefined" && backend.stop)
                            backend.stop(stopPid);
                    }
                }

                // Step-change countdown (skip if paused)
                if (pc.pumpStepSec > 0 && !pc.paused) {
                    if (pcEff < pc.pumpStepSec) {
                        var stRem = pc.pumpStepSec - pcEff;
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

        // Load presets from file via backend
        if (typeof backend !== "undefined" && backend.load_presets) {
            try {
                var saved = JSON.parse(backend.load_presets());
                if (saved && typeof saved === "object")
                    presetMap = saved;
            } catch(e) {}
        }

        // Load saved themes from file via backend
        if (typeof backend !== "undefined" && backend.load_theme) {
            try {
                var td = JSON.parse(backend.load_theme());
                if (td && td.saved && typeof td.saved === "object")
                    savedThemes = td.saved;
                if (td && td.current && typeof td.current === "object")
                    theme = td.current;
            } catch(e) {}
        }

        // Push initial theme to all cards
        switchTheme(theme);

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
                    // Pulsatile flow is handled by startAutomation; skip set_flow
                    if (c.infoLabel && c.infoLabel.text.indexOf("pulsatile") !== -1) continue;
                    var pid = pumpIdFromRunCard(c);
                    if (pid <= 0) continue;
                    var f = c.rawFlow;
                    if (f <= 0) continue;
                    backend.set_flow(pid, f);
                }
            }

            if (!runTimer.running)
                runTimer.start();
        });

        run.pauseButton.clicked.connect(function () {
            runTimer.stop();
            var allCards = [run.r1, run.r2, run.r3, run.r4,
                            run.r5, run.r6, run.r7, run.r8, run.r9];
            for (var i = 0; i < allCards.length; ++i) {
                var ac = allCards[i];
                if (!ac || !ac.visible) continue;
                ac.paused = true;
                ac.pumpPausedAt = elapsedSec;
            }
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
                c2.pumpPausedAt = -1;
                c2.pumpPausedAccum = 0;
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
                if (!c3 || !c3.visible || !c3.selected)
                    continue;
                var pid = pumpIdFromRunCard(c3);
                if (ids.indexOf(pid) !== -1) {
                    c3.paused = true;
                    c3.pumpPausedAt = elapsedSec;
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
                if (!c4 || !c4.visible || !c4.selected)
                    continue;
                var pid = pumpIdFromRunCard(c4);
                if (ids.indexOf(pid) !== -1) {
                    if (c4.pumpPausedAt >= 0)
                        c4.pumpPausedAccum += elapsedSec - c4.pumpPausedAt;
                    c4.pumpPausedAt = -1;
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
