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

    // ── Run History ───────────────────────────────────────────────────────────
    property var runHistory: []   // array of plain strings, one per event

    function logEvent(type, pumpsStr, details) {
        var h = Math.floor(elapsedSec / 3600);
        var m = Math.floor((elapsedSec % 3600) / 60);
        var s = elapsedSec % 60;
        var t = pad(h) + ":" + pad(m) + ":" + pad(s);
        var line = t + "  |  " + type
                 + (pumpsStr ? "  — Pump " + pumpsStr : "")
                 + (details  ? "  (" + details + ")" : "");
        runHistory.push(line);
        runHistoryModel.append({ entry: line });
    }

    ListModel { id: runHistoryModel }

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
        primeInactive:      "#eceff1",
        inputBg:            "#ffffff"
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
        primeInactive:      "#2a3a4a",
        inputBg:            "#0a1520"
    })

    // 🌈 Rainbow theme — unlocked by clicking Nyan Cat in Fun Mode
    readonly property var _rainbow: ({
        name:               "rainbow",
        pageBg:             "#fff0f5",
        toolbarBg:          "#e53935",
        cardBg:             "#ffffff",
        cardBgSelected:     "#b9f6ca",
        cardBorder:         "#ff4081",
        cardBorderSelected: "#00e5ff",
        buttonBg:           "#d500f9",
        buttonFlash:        "#00e5ff",
        timerColor:         "#ff1744",
        pausedColor:        "#ff6d00",
        stepColor:          "#00e676",
        primeActive:        "#ffff00",
        primeInactive:      "#e040fb",
        inputBg:            "#ffffff"
    })

    // ── Secret themes (unlocked via easter eggs) ──────────────────────────────
    readonly property var _northeastern: ({
        name:               "northeastern",
        pageBg:             "#00000000",   // transparent — husky photo shows through
        toolbarBg:          "#c8102e",     // NU Red
        cardBg:             "#CC000000",   // 80% black glass
        cardBgSelected:     "#CC3a0000",   // dark blood-red glass when selected
        cardBorder:         "#666666",
        cardBorderSelected: "#c8102e",
        buttonBg:           "#c8102e",
        buttonFlash:        "#7a0000",
        timerColor:         "#ff8888",
        pausedColor:        "#ffaa44",
        stepColor:          "#88ff99",
        primeActive:        "#CC550000",
        primeInactive:      "#88000000",
        inputBg:            "#CC111111",
        bgImage:            "husky.jpg"
    })

    readonly property var _transparent: ({
        name:               "transparent",
        pageBg:             "#00000000",   // transparent — electronics photo shows through
        toolbarBg:          "#AA000000",   // dark glass toolbar
        cardBg:             "#66000000",   // 40% black glass
        cardBgSelected:     "#88003355",   // blue-tinted glass when selected
        cardBorder:         "#88ffffff",
        cardBorderSelected: "#CCffffff",
        buttonBg:           "#AA1a1a2e",
        buttonFlash:        "#CC1a1a2e",
        timerColor:         "#88ddff",
        pausedColor:        "#ffaa44",
        stepColor:          "#88ff88",
        primeActive:        "#66002244",
        primeInactive:      "#44000000",
        inputBg:            "#55000000",
        bgImage:            "electronics.jpg"
    })

    // Currently active theme object
    property var theme: _bluesLight

    // ── Fun Mode ──────────────────────────────────────────────────────────────
    property bool funMode:               false
    property bool rainbowUnlocked:      false   // unlocked by clicking Nyan Cat
    property bool northeasternUnlocked: false   // unlocked by typing 1898 in any flow field
    property bool transparentUnlocked:  false   // unlocked by checkbox in Advanced dialog
    property bool showConfetti:         false
    property bool _isRainbow:           false
    property real lastPressY:           300

    // Animated toolbar colour that cycles through the rainbow
    property color _rainbowToolbarColor: "#e53935"
    SequentialAnimation on _rainbowToolbarColor {
        running: _isRainbow
        loops:   Animation.Infinite
        ColorAnimation { to: "#e53935"; duration: 700 }   // red
        ColorAnimation { to: "#fb8c00"; duration: 700 }   // orange
        ColorAnimation { to: "#fdd835"; duration: 700 }   // yellow
        ColorAnimation { to: "#43a047"; duration: 700 }   // green
        ColorAnimation { to: "#1e88e5"; duration: 700 }   // blue
        ColorAnimation { to: "#8e24aa"; duration: 700 }   // violet
    }

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
        // Rainbow: animated toolbar
        app._isRainbow = (t.name === "rainbow");
        setup.rainbowToolbar = app._isRainbow;
        if (app._isRainbow)
            setup.rainbowToolbarColor = Qt.binding(function() { return app._rainbowToolbarColor; });
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

    function _doStopAll() {
        runTimer.stop();
        logEvent("Stop All", "All", "run reset");   // log BEFORE resetting elapsedSec
        elapsedSec = 0;
        run.runTimeLabel.text = "00:00:00";
        run.runStarted      = false;
        run.allPumpsStarted = false;
        pausedPumpIds = [];
        automationFinished = true;
        automationTotalMinutes = 0;
        automationPending = false;

        if (typeof backend !== "undefined" && backend.stopAll)
            backend.stopAll();

        // Also stop any priming setup cards
        var setupCards2 = [setup.pump1, setup.pump2, setup.pump3,
                           setup.pump4, setup.pump5, setup.pump6,
                           setup.pump7, setup.pump8, setup.pump9];
        for (var si2 = 0; si2 < setupCards2.length; ++si2) {
            if (setupCards2[si2] && setupCards2[si2].priming) {
                setupCards2[si2].priming = false;
                if (typeof backend !== "undefined" && backend.stop)
                    backend.stop(setupCards2[si2].pumpId);
            }
        }

        // Reset and hide all run cards
        var rc2 = [run.r1, run.r2, run.r3, run.r4,
                   run.r5, run.r6, run.r7, run.r8, run.r9];
        for (var j2 = 0; j2 < rc2.length; ++j2) {
            var cd = rc2[j2];
            if (!cd) continue;
            cd.visible         = false;
            cd.paused          = false;
            cd.selected        = false;
            cd.pumpStarted     = false;
            cd.pumpStartedAt   = 0;
            cd.pumpPausedAt    = -1;
            cd.pumpPausedAccum = 0;
            cd.pumpStopped     = false;
            cd.pumpEndSec      = 0;
            cd.pumpDurationSec = 0;
            cd.pumpStepSec     = -1;
            cd.rawFlow         = 0.0;
            cd.opacity         = 1.0;
            if (cd.timerLabel) cd.timerLabel.text = "";
            if (cd.stepLabel)  cd.stepLabel.text  = "";
            if (cd.infoLabel)  cd.infoLabel.text  = "";
            if (cd.setFlowValue) cd.setFlowValue.text = "0.00";
            if (cd.ppsLabel)   cd.ppsLabel.text   = "0";
        }

        run.statusLabel.text = "All pumps stopped. Press Ready to Run to start a new run.";
    }

    function _resetPumpCard(c) {
        c.pumpStopped     = false;
        c.pumpStartedAt   = 0;
        c.pumpPausedAccum = 0;
        c.pumpPausedAt    = -1;
        c.opacity         = 1.0;
        if (c.pumpDurationSec > 0)
            c.pumpEndSec = elapsedSec + c.pumpDurationSec;
        if (c.timerLabel) c.timerLabel.text = "";
    }

    function _startCards(cards) {
        var pulsatileAutoIds      = [];
        var pulsatileAutoModes    = [];
        var pulsatileAutoShapes   = [];
        var pulsatileAutoMins     = [];
        var pulsatileAutoPeriods  = [];
        var pulsatileAutoDuties   = [];
        var pulsatileAutoMinFlows = [];
        var pulsatileAutoMaxFlows = [];

        for (var i = 0; i < cards.length; ++i) {
            var c = cards[i];
            if (!c || !c.visible) continue;

            // Skip completed pumps — they stay grey/locked until Stop All + Ready to Run
            if (c.pumpStopped) continue;

            // If the pump was already running and got paused, accumulate pause time.
            // If it was paused before being started (e.g. Pause All hit an unstarted pump),
            // just clear the paused flag — no accum to add since it never ran.
            // Capture resume state BEFORE clearing paused, so pulsatile logic can use it.
            var wasResuming = c.paused && c.pumpStarted;
            var resumeRemMins = 0;
            if (wasResuming && c.pumpEndSec > 0) {
                var prePcEff = Math.max(0, (c.pumpPausedAt - c.pumpStartedAt) - c.pumpPausedAccum);
                resumeRemMins = Math.max(0, c.pumpEndSec - prePcEff) / 60.0;
            }

            if (c.paused) {
                if (c.pumpStarted && c.pumpPausedAt >= 0)
                    c.pumpPausedAccum += elapsedSec - c.pumpPausedAt;
                c.pumpPausedAt = -1;
                c.paused = false;
            }

            // Mark this pump as started and record the universal timer offset
            if (!c.pumpStarted) {
                c.pumpStarted   = true;
                c.pumpStartedAt = elapsedSec;   // countdown is relative to this moment
            }

            // Stop any setup-page priming for this pump
            var setupCards3 = [setup.pump1, setup.pump2, setup.pump3,
                               setup.pump4, setup.pump5, setup.pump6,
                               setup.pump7, setup.pump8, setup.pump9];
            var pid = pumpIdFromRunCard(c);
            for (var si3 = 0; si3 < setupCards3.length; ++si3) {
                var sc3 = setupCards3[si3];
                if (sc3 && sc3.priming && sc3.pumpId === pid) {
                    sc3.priming = false;
                    if (typeof backend !== "undefined" && backend.stop)
                        backend.stop(sc3.pumpId);
                }
            }
            if (c.stepLabel && c.stepLabel.text.indexOf("Priming") !== -1)
                c.stepLabel.text = "";

            // Collect pulsatile pumps for startAutomation call
            var isPulsatile = c.infoLabel && c.infoLabel.text.indexOf("pulsatile") !== -1;
            if (isPulsatile) {
                // Find this pump in the global auto arrays
                for (var ai = 0; ai < autoIds.length; ++ai) {
                    if (autoIds[ai] === pid) {
                        pulsatileAutoIds.push(autoIds[ai]);
                        pulsatileAutoModes.push(autoModes[ai]);
                        pulsatileAutoShapes.push(autoShapes[ai]);
                        // Resume: use remaining time (or 0 for no-limit).
                        // Fresh start: use original configured duration.
                        var pulMinToUse = wasResuming
                            ? (c.pumpEndSec > 0 ? resumeRemMins : 0)
                            : autoMins[ai];
                        pulsatileAutoMins.push(pulMinToUse);
                        pulsatileAutoPeriods.push(autoPeriods[ai]);
                        pulsatileAutoDuties.push(autoDuties[ai]);
                        var pulCal = calibrationForPumpId(autoIds[ai]);
                        pulsatileAutoMinFlows.push(autoMinFlows[ai] * pulCal);
                        pulsatileAutoMaxFlows.push(autoMaxFlows[ai] * pulCal);
                        break;
                    }
                }
            } else {
                // Constant / manual: convert µL/min → pps via calibration multiplier
                if (typeof backend !== "undefined" && backend.set_flow) {
                    if (pid > 0 && c.rawFlow > 0) {
                        var calFactor = calibrationForPumpId(pid);
                        backend.set_flow(pid, c.rawFlow * calFactor);
                    }
                }
            }
        }

        // Fire pulsatile automation if any pulsatile pumps in this set
        if (pulsatileAutoIds.length > 0 &&
            typeof backend !== "undefined" && backend.startAutomation) {
            automationFinished = false;
            backend.startAutomation(pulsatileAutoIds, pulsatileAutoModes,
                                    pulsatileAutoShapes, pulsatileAutoMins,
                                    pulsatileAutoPeriods, pulsatileAutoDuties,
                                    pulsatileAutoMinFlows, pulsatileAutoMaxFlows);
        }

        if (!runTimer.running) runTimer.start();

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
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"
            radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")
        palette.text:       app.contrastColor(app.theme.inputBg || "#ffffff")
        palette.base:       app.theme.inputBg  || "#ffffff"
        palette.button:     app.theme.buttonBg || "#607d8b"
        palette.buttonText: app.contrastColor(app.theme.buttonBg || "#607d8b")

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8
            Label { text: "Preset name:"; font.pixelSize: 14 }
            TextField {
                id: presetNameField
                Layout.preferredWidth: 260
                font.pixelSize: 14
                color: app.contrastColor(app.theme.inputBg || "#ffffff")
                background: Rectangle {
                    radius: 4
                    color: app.theme.inputBg || "#ffffff"
                    border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
                }
            }
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
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"
            radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")
        palette.text:       app.contrastColor(app.theme.inputBg || "#ffffff")
        palette.base:       app.theme.inputBg  || "#ffffff"
        palette.button:     app.theme.buttonBg || "#607d8b"
        palette.buttonText: app.contrastColor(app.theme.buttonBg || "#607d8b")
        palette.highlight:           app.theme.cardBgSelected || "#dce8f0"
        palette.highlightedText:     app.contrastColor(app.theme.cardBgSelected || "#dce8f0")

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
                font.pixelSize: 16
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
                font.pixelSize: 14
                onClicked: loadPresetDialog.close()
            }
            Button {
                text: "Load"
                font.pixelSize: 14
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
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"
            radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")
        palette.text:       app.contrastColor(app.theme.inputBg || "#ffffff")
        palette.base:       app.theme.inputBg  || "#ffffff"
        palette.button:     app.theme.buttonBg || "#607d8b"
        palette.buttonText: app.contrastColor(app.theme.buttonBg || "#607d8b")

        property var editColors: ({})   // working copy while dialog is open
        property string editorMode: "Simple"   // "Simple" or "Advanced"

        // ── Color helpers for simple-mode auto-derivation ─────────────────────
        function _darken(hex, factor) {
            if (!hex || hex.length < 7) return hex;
            var r = Math.round(Math.max(0, parseInt(hex.slice(1,3),16) * (1-factor)));
            var g = Math.round(Math.max(0, parseInt(hex.slice(3,5),16) * (1-factor)));
            var b = Math.round(Math.max(0, parseInt(hex.slice(5,7),16) * (1-factor)));
            return "#" + ("0"+r.toString(16)).slice(-2)
                       + ("0"+g.toString(16)).slice(-2)
                       + ("0"+b.toString(16)).slice(-2);
        }
        function _lighten(hex, factor) {
            if (!hex || hex.length < 7) return hex;
            var r = parseInt(hex.slice(1,3),16); r = Math.round(r + (255-r)*factor);
            var g = parseInt(hex.slice(3,5),16); g = Math.round(g + (255-g)*factor);
            var b = parseInt(hex.slice(5,7),16); b = Math.round(b + (255-b)*factor);
            return "#" + ("0"+Math.min(255,r).toString(16)).slice(-2)
                       + ("0"+Math.min(255,g).toString(16)).slice(-2)
                       + ("0"+Math.min(255,b).toString(16)).slice(-2);
        }

        function loadEditor(src) {
            editColors = JSON.parse(JSON.stringify(src));
            _refreshRepeaters();
        }

        function _refreshRepeaters() {
            editColorRepeater.model = 0;
            editColorRepeater.model = colorKeys.length;
            simpleRepeater.model = 0;
            simpleRepeater.model = simpleKeys.length;
        }

        onEditorModeChanged: _refreshRepeaters()
        onOpened: loadEditor(app.theme)

        // ── Advanced: all 14 keys ─────────────────────────────────────────────
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
            ["primeInactive",      "Prime (idle)"],
            ["inputBg",            "Flow rate field"]
        ]

        // ── Simple: 8 representative keys with auto-derivation ────────────────
        // Each entry: [key, label, [[derivedKey, "darken"|"lighten"|"copy", amount], ...]]
        property var simpleKeys: [
            ["pageBg",         "Page Background",  []],
            ["toolbarBg",      "Toolbar",           []],
            ["cardBg",         "Card Background",   [["cardBgSelected","lighten",0.30],
                                                     ["cardBorder",    "lighten",-0.10],
                                                     ["cardBorderSelected","darken",0.15]]],
            ["buttonBg",       "Buttons",           [["buttonFlash",   "darken", 0.25]]],
            ["timerColor",     "Accent / Timers",   [["pausedColor",   "copy",   0],
                                                     ["stepColor",     "copy",   0]]],
            ["inputBg",        "Input Fields",      []],
            ["primeActive",    "Prime (active)",    [["primeInactive", "lighten",0.40]]]
        ]

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 10

            // ── Preset row ────────────────────────────────────────────────────
            RowLayout {
                spacing: 8
                Label { text: "Preset:"; font.pixelSize: 16 }
                Button {
                    text: "Default"
                    font.pixelSize: 14
                    Layout.preferredWidth: 110
                    onClicked: themeDialog.loadEditor(app._bluesLight)
                    background: Rectangle { radius: 4; color: "#546e7a" }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#fff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    text: "Dark"
                    font.pixelSize: 14
                    Layout.preferredWidth: 80
                    onClicked: themeDialog.loadEditor(app._dark)
                    background: Rectangle { radius: 4; color: "#0a1225" }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#e0f0ff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    text: "🌈 Rainbow"
                    font.pixelSize: 14
                    Layout.preferredWidth: 110
                    visible: app.rainbowUnlocked
                    onClicked: themeDialog.loadEditor(app._rainbow)
                    background: Rectangle {
                        radius: 4
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0;  color: "#ff4444" }
                            GradientStop { position: 0.33; color: "#ffee00" }
                            GradientStop { position: 0.66; color: "#44cc44" }
                            GradientStop { position: 1.0;  color: "#9933ff" }
                        }
                    }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        style: Text.Outline; styleColor: "#00000055"
                    }
                }
                Button {
                    text: "🐺 Northeastern"
                    font.pixelSize: 14
                    Layout.preferredWidth: 140
                    visible: app.northeasternUnlocked
                    onClicked: app.switchTheme(app._northeastern)
                    background: Rectangle {
                        radius: 4
                        color: "#c8102e"
                    }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        font.bold: true
                    }
                }
                Button {
                    text: "📷 Transparent"
                    font.pixelSize: 14
                    Layout.preferredWidth: 130
                    visible: app.transparentUnlocked
                    onClicked: app.switchTheme(app._transparent)
                    background: Rectangle {
                        radius: 4
                        color: "#333355"
                        border.color: "#aaaacc"; border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#ccccff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }
                Item { Layout.fillWidth: true }
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
            }

            // ── Simple / Advanced selector ────────────────────────────────────
            RowLayout {
                spacing: 8
                Label { text: "Editor:"; font.pixelSize: 14 }
                ComboBox {
                    id: editorModeCombo
                    model: ["Simple", "Advanced"]
                    font.pixelSize: 14
                    Layout.preferredWidth: 120
                    currentIndex: themeDialog.editorMode === "Advanced" ? 1 : 0
                    onActivated: themeDialog.editorMode = currentText
                    background: Rectangle {
                        radius: 4
                        color:  app.theme.inputBg || "#ffffff"
                        border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
                    }
                    contentItem: Text {
                        leftPadding: 8
                        text: editorModeCombo.displayText
                        font: editorModeCombo.font
                        color: app.contrastColor(app.theme.inputBg || "#ffffff")
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // ── Simple editor ─────────────────────────────────────────────────
            GridLayout {
                visible: themeDialog.editorMode === "Simple"
                columns: 2
                rowSpacing: 6; columnSpacing: 16
                Layout.fillWidth: true

                Repeater {
                    id: simpleRepeater
                    model: themeDialog.simpleKeys.length

                    delegate: RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        property string colorKey:   themeDialog.simpleKeys[index][0]
                        property string colorLabel: themeDialog.simpleKeys[index][1]
                        property var    derivedRules: themeDialog.simpleKeys[index][2]

                        Label { text: colorLabel; font.pixelSize: 16; Layout.preferredWidth: 140 }

                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: themeDialog.editColors[colorKey] || "#888888"
                            border.color: "#555"; border.width: 1
                        }

                        TextField {
                            text: themeDialog.editColors[colorKey] || ""
                            font.pixelSize: 16
                            Layout.preferredWidth: 84
                            color: app.contrastColor(app.theme.inputBg || "#ffffff")
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            background: Rectangle {
                                radius: 4
                                color: app.theme.inputBg || "#ffffff"
                                border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
                            }
                            onEditingFinished: {
                                var v = text.trim();
                                if (!/^#[0-9a-fA-F]{3,8}$/.test(v)) return;
                                var tmp = JSON.parse(JSON.stringify(themeDialog.editColors));
                                tmp[colorKey] = v;
                                // Auto-derive related colors
                                var rules = derivedRules;
                                for (var d = 0; d < rules.length; d++) {
                                    var dKey = rules[d][0];
                                    var dOp  = rules[d][1];
                                    var dAmt = rules[d][2];
                                    if (dOp === "copy")    tmp[dKey] = v;
                                    else if (dOp === "darken")  tmp[dKey] = themeDialog._darken(v, dAmt);
                                    else if (dOp === "lighten") tmp[dKey] = dAmt >= 0
                                                                           ? themeDialog._lighten(v, dAmt)
                                                                           : themeDialog._darken(v, -dAmt);
                                }
                                themeDialog.editColors = tmp;
                                themeDialog._refreshRepeaters();
                            }
                        }
                    }
                }
            }

            // ── Advanced editor ───────────────────────────────────────────────
            GridLayout {
                visible: themeDialog.editorMode === "Advanced"
                columns: 2
                rowSpacing: 6; columnSpacing: 16
                Layout.fillWidth: true

                Repeater {
                    id: editColorRepeater
                    model: themeDialog.colorKeys.length

                    delegate: RowLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        property string colorKey:   themeDialog.colorKeys[index][0]
                        property string colorLabel: themeDialog.colorKeys[index][1]

                        Label { text: colorLabel; font.pixelSize: 16; Layout.preferredWidth: 140 }

                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: themeDialog.editColors[colorKey] || "#888888"
                            border.color: "#555"; border.width: 1
                        }

                        TextField {
                            id: hexField
                            text: themeDialog.editColors[colorKey] || ""
                            font.pixelSize: 16
                            Layout.preferredWidth: 84
                            color: app.contrastColor(app.theme.inputBg || "#ffffff")
                            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            background: Rectangle {
                                radius: 4
                                color: app.theme.inputBg || "#ffffff"
                                border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
                            }
                            onEditingFinished: {
                                var v = text.trim();
                                if (/^#[0-9a-fA-F]{3,8}$/.test(v)) {
                                    var tmp = JSON.parse(JSON.stringify(themeDialog.editColors));
                                    tmp[colorKey] = v;
                                    themeDialog.editColors = tmp;
                                    themeDialog._refreshRepeaters();
                                }
                            }
                        }
                    }
                }
            }

            // ── Save custom theme row ─────────────────────────────────────────
            RowLayout {
                spacing: 8
                Label { text: "Save as:"; font.pixelSize: 14 }
                TextField {
                    id: customThemeNameField
                    placeholderText: "My Theme"
                    font.pixelSize: 14
                    Layout.preferredWidth: 160
                    color: app.contrastColor(app.theme.inputBg || "#ffffff")
                    background: Rectangle {
                        radius: 4
                        color: app.theme.inputBg || "#ffffff"
                        border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
                    }
                }
                Button {
                    text: "Save Theme"
                    font.pixelSize: 14
                    Layout.preferredWidth: 100
                    background: Rectangle { radius: 4; color: app.theme.buttonBg || "#607d8b" }
                    contentItem: Text {
                        text: parent.text; font: parent.font
                        color: app.contrastColor(app.theme.buttonBg || "#607d8b")
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
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
                Button {
                    text: "Delete Saved"
                    font.pixelSize: 14
                    Layout.preferredWidth: 110
                    visible: savedThemeCombo.count > 0
                    background: Rectangle { radius: 4; color: "#c62828" }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#fff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        var name = savedThemeCombo.currentText;
                        if (!name) return;
                        var updated = JSON.parse(JSON.stringify(app.savedThemes));
                        delete updated[name];
                        app.savedThemes = updated;
                        savedThemeCombo.model = Object.keys(app.savedThemes);
                        app.persistTheme();
                    }
                }
            }
        }

        footer: RowLayout {
            spacing: 8
            // Fun Mode toggle lives here so it's always visible in settings
            CheckBox {
                id: funModeCheck
                text: "Fun Mode 🎉"
                checked: app.funMode
                font.pixelSize: 14
                leftPadding: 8
                onCheckedChanged: {
                    app.funMode = checked;
                }
                contentItem: Text {
                    text:            funModeCheck.text
                    font:            funModeCheck.font
                    color:           app.contrastColor(app.theme.cardBg || "#ffffff")
                    leftPadding:     funModeCheck.indicator.width + 6
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                font.pixelSize: 14
                onClicked: themeDialog.close()
                background: Rectangle { radius: 4; color: app.theme.buttonBg || "#607d8b" }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: app.contrastColor(app.theme.buttonBg || "#607d8b")
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                text: "Apply"
                font.pixelSize: 14
                onClicked: {
                    app.switchTheme(JSON.parse(JSON.stringify(themeDialog.editColors)));
                    app.persistTheme();
                    themeDialog.close();
                }
                background: Rectangle { radius: 4; color: "#2e7d32" }
                contentItem: Text {
                    text: parent.text; font: parent.font; color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    /* ===================== Confirm-Close Dialog ===================== */

    // Intercept the OS close button — ask before quitting
    onClosing: function(close) {
        close.accepted = false;
        confirmCloseDialog.open();
    }

    Dialog {
        id: confirmCloseDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        title: "Close Application?"
        standardButtons: Dialog.NoButton
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"
            radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")

        contentItem: ColumnLayout {
            anchors.margins: 16
            spacing: 10
            Label {
                text: "Are you sure you want to close the application?\nThis will stop all running pumps."
                font.pixelSize: 15
                wrapMode: Text.WordWrap
                color: app.contrastColor(app.theme.cardBg || "#ffffff")
            }
        }

        footer: RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                font.pixelSize: 14
                onClicked: confirmCloseDialog.close()
                background: Rectangle { radius: 4; color: app.theme.buttonBg || "#607d8b" }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: app.contrastColor(app.theme.buttonBg || "#607d8b")
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                text: "Close Application"
                font.pixelSize: 14
                onClicked: {
                    if (typeof backend !== "undefined" && backend.stopAll)
                        backend.stopAll();
                    Qt.quit();
                }
                background: Rectangle { radius: 4; color: "#c62828" }
                contentItem: Text {
                    text: parent.text; font: parent.font; color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    Dialog {
        id: stopAllDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        title: "Stop All Pumps?"
        standardButtons: Dialog.NoButton
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"; radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")

        contentItem: ColumnLayout {
            anchors.margins: 16; spacing: 10
            Label {
                text: "Are you sure you want to stop all pumps?\n" +
                      "This will also reset the run page.\n" +
                      "Setup page values are preserved."
                wrapMode: Text.WordWrap; font.pixelSize: 15
                color: app.contrastColor(app.theme.cardBg || "#ffffff")
            }
        }

        footer: RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"; font.pixelSize: 14
                onClicked: stopAllDialog.close()
                background: Rectangle { radius: 4; color: app.theme.buttonBg || "#607d8b" }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: app.contrastColor(app.theme.buttonBg || "#607d8b")
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                text: "Stop All Pumps"; font.pixelSize: 14
                background: Rectangle { radius: 4; color: "#c62828" }
                contentItem: Text {
                    text: parent.text; font: parent.font; color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    stopAllDialog.close();
                    app._doStopAll();
                }
            }
        }
    }

    Dialog {
        id: historyDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        title: "Run History"
        width: 680
        height: 460
        standardButtons: Dialog.NoButton
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"; radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")

        contentItem: ColumnLayout {
            anchors.margins: 12; spacing: 8

            // Save row — at TOP so it remains visible when the virtual keyboard is open
            RowLayout {
                spacing: 8
                Label { text: "Save as:"; font.pixelSize: 14 }
                TextField {
                    id: historyFilenameField
                    placeholderText: "run_log"
                    font.pixelSize: 14
                    Layout.preferredWidth: 200
                    color: app.contrastColor(app.theme.inputBg || "#ffffff")
                    background: Rectangle {
                        radius: 4; color: app.theme.inputBg || "#ffffff"
                        border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
                    }
                }
                Label { text: ".txt"; font.pixelSize: 14 }
                Button {
                    text: "Save to File"; font.pixelSize: 14
                    background: Rectangle { radius: 4; color: "#2e7d32" }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (typeof backend === "undefined" || !backend.save_run_log) return;
                        var name = historyFilenameField.text.trim() || "run_log";
                        var lines = [];
                        for (var i = 0; i < runHistoryModel.count; i++)
                            lines.push(runHistoryModel.get(i).entry);
                        backend.save_run_log(name, lines.join("\n") + "\n");
                        run.statusLabel.text = "History saved as " + name + ".txt";
                    }
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Clear History"; font.pixelSize: 14
                    background: Rectangle { radius: 4; color: "#c62828" }
                    contentItem: Text {
                        text: parent.text; font: parent.font; color: "#fff"
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        runHistory = [];
                        runHistoryModel.clear();
                    }
                }
            }

            // Scrollable log list
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 260
                color: app.theme.inputBg || "#ffffff"
                radius: 4
                border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
                clip: true

                ListView {
                    id: historyListView
                    anchors.fill: parent
                    anchors.margins: 6
                    model: runHistoryModel
                    spacing: 2

                    delegate: Text {
                        width: historyListView.width
                        text: model.entry
                        font.pixelSize: 13
                        font.family: "Monospace"
                        color: app.contrastColor(app.theme.inputBg || "#ffffff")
                        wrapMode: Text.WordWrap
                    }

                    // Auto-scroll to bottom when new entries arrive
                    onCountChanged: positionViewAtEnd()
                }
            }
        }

        footer: RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: "Close"; font.pixelSize: 14
                onClicked: historyDialog.close()
                background: Rectangle { radius: 4; color: app.theme.buttonBg || "#607d8b" }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: app.contrastColor(app.theme.buttonBg || "#607d8b")
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
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
            c.ppsLabel.text = (flowVal * factor).toFixed(0);
        }
    }

    Dialog {
        id: calibrationDialog
        modal: true
        closePolicy: Popup.CloseOnEscape
        title: "Per-pump Calibration (pps per µL/min)"
        standardButtons: Dialog.Ok | Dialog.Cancel
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"
            radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")
        palette.text:       app.contrastColor(app.theme.inputBg || "#ffffff")
        palette.base:       app.theme.inputBg  || "#ffffff"
        palette.button:     app.theme.buttonBg || "#607d8b"
        palette.buttonText: app.contrastColor(app.theme.buttonBg || "#607d8b")

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8

            Label {
                text: "Enter calibration factors (pps per µL/min) for each pump.\n" +
                      "pps = flow × factor.  Existing values kept if field left blank."
                wrapMode: Text.WordWrap
            }

            GridLayout {
                columns: 3
                rowSpacing: 4
                columnSpacing: 10

                Label { text: "Pump 1"; font.pixelSize: 16 }
                TextField {
                    id: cal1; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 2"; font.pixelSize: 16 }
                TextField {
                    id: cal2; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 3"; font.pixelSize: 16 }
                TextField {
                    id: cal3; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 4"; font.pixelSize: 16 }
                TextField {
                    id: cal4; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 5"; font.pixelSize: 16 }
                TextField {
                    id: cal5; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 6"; font.pixelSize: 16 }
                TextField {
                    id: cal6; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 7"; font.pixelSize: 16 }
                TextField {
                    id: cal7; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 8"; font.pixelSize: 16 }
                TextField {
                    id: cal8; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}

                Label { text: "Pump 9"; font.pixelSize: 16 }
                TextField {
                    id: cal9; Layout.preferredWidth: 80; font.pixelSize: 16
                    validator: DoubleValidator { bottom: 0; decimals: 5 }
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Item {}
            }
        }

        onOpened: {
            // Load fields in display order (matches SetupPageForm grid).
            // Each cal field maps to the pumpId shown in that grid position:
            //   display Pump 1 → pumpId 9 → index 8
            //   display Pump 2 → pumpId 8 → index 7
            //   display Pump 3 → pumpId 7 → index 6
            //   display Pump 4 → pumpId 2 → index 1
            //   display Pump 5 → pumpId 3 → index 2
            //   display Pump 6 → pumpId 1 → index 0
            //   display Pump 7 → pumpId 6 → index 5
            //   display Pump 8 → pumpId 5 → index 4
            //   display Pump 9 → pumpId 4 → index 3
            var arr = pumpCalFactors;
            cal1.text = "" + arr[8];
            cal2.text = "" + arr[7];
            cal3.text = "" + arr[6];
            cal4.text = "" + arr[1];
            cal5.text = "" + arr[2];
            cal6.text = "" + arr[0];
            cal7.text = "" + arr[5];
            cal8.text = "" + arr[4];
            cal9.text = "" + arr[3];
        }

        onAccepted: {
            // Start from the current values so blank fields keep their old value.
            // Write each field to its pumpId-indexed slot (same mapping as onOpened).
            var next = pumpCalFactors.slice();

            function upd(fieldText, idx) {
                var t = fieldText.trim();
                if (t.length === 0) return;       // blank → keep old
                var v = parseFloat(t);
                if (!isNaN(v) && v > 0) next[idx] = v;
            }

            upd(cal1.text, 8);   // display Pump 1 → pumpId 9 → index 8
            upd(cal2.text, 7);   // display Pump 2 → pumpId 8 → index 7
            upd(cal3.text, 6);   // display Pump 3 → pumpId 7 → index 6
            upd(cal4.text, 1);   // display Pump 4 → pumpId 2 → index 1
            upd(cal5.text, 2);   // display Pump 5 → pumpId 3 → index 2
            upd(cal6.text, 0);   // display Pump 6 → pumpId 1 → index 0
            upd(cal7.text, 5);   // display Pump 7 → pumpId 6 → index 5
            upd(cal8.text, 4);   // display Pump 8 → pumpId 5 → index 4
            upd(cal9.text, 3);   // display Pump 9 → pumpId 4 → index 3

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
            rc0.pumpStarted = false;
            rc0.pumpStartedAt = 0;
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
            rc.ppsLabel.text = (f * factor).toFixed(0);

            var mode    = sc.advMode;
            var summary = "";

            if (mode === "Constant") {
                summary = "Constant" + (sc.advTotalMinutes > 0
                          ? " \u2022 " + sc.advTotalMinutes.toFixed(1) + " min"
                          : " \u2022 no time limit");
                if (sc.advStepEnabled && sc.advStepMinutes > 0) {
                    summary += " \u2022 Change to " + sc.advStepFlow.toFixed(2)
                               + " \u00b5L/min at " + sc.advStepMinutes.toFixed(1) + " min";
                }
                rc.pumpEndSec  = sc.advTotalMinutes > 0 ? Math.round(sc.advTotalMinutes * 60) : 0;
                rc.pumpDurationSec = rc.pumpEndSec;
                rc.pumpStepSec = sc.advStepEnabled ? Math.round(sc.advStepMinutes * 60) : -1;

            } else if (mode === "Pulsatile") {
                rc.setFlowValue.text = sc.advMinFlow.toFixed(2) + " - " + sc.advMaxFlow.toFixed(2);
                summary = sc.advShape + " pulsatile \u2022 "
                          + (sc.advTotalMinutes > 0 ? sc.advTotalMinutes.toFixed(1) + " min" : "no time limit")
                          + " \u2022 " + sc.advPeriod.toFixed(1) + " s period";
                if (sc.advShape === "Square")
                    summary += " \u2022 " + sc.advDuty.toFixed(1) + "% duty";
                rc.pumpEndSec  = sc.advTotalMinutes > 0 ? Math.round(sc.advTotalMinutes * 60) : 0;
                rc.pumpDurationSec = rc.pumpEndSec;
                rc.pumpStepSec = -1;
                hasPulsatile   = true;

            } else {
                rc.setFlowValue.text = f.toFixed(2);
                summary = "Manual mode \u2022 No time limit";
                rc.pumpEndSec  = 0;
                rc.pumpDurationSec = 0;
                rc.pumpStepSec = -1;
            }

            if (mode === "Constant")
                rc.setFlowValue.text = f.toFixed(2);

            rc.infoLabel.text = summary;

            // Show priming status so the operator knows before pressing Start
            if (sc.priming)
                rc.stepLabel.text = "\u27F3 Priming\u2014press Start to stop";

            automationPumpIds.push(pumpId);
            autoIds.push(pumpId);
            autoModes.push(mode === "" ? "Constant" : mode);
            autoShapes.push(sc.advShape  || "Square");
            // Manual mode has no time limit — always push 0 so it never inflates automationTotalMinutes
            autoMins.push(mode === "" ? 0 : sc.advTotalMinutes);
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
        background: Rectangle {
            color: app.theme.cardBg || "#ffffff"
            radius: 8
            border.color: app.theme.cardBorder || "#b0bec5"; border.width: 1
        }
        palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")
        palette.text:       app.contrastColor(app.theme.inputBg || "#ffffff")
        palette.base:       app.theme.inputBg  || "#ffffff"
        palette.button:     app.theme.buttonBg || "#607d8b"
        palette.buttonText: app.contrastColor(app.theme.buttonBg || "#607d8b")

        contentItem: ColumnLayout {
            anchors.margins: 12
            spacing: 8

            // Secret transparent-theme unlock (upper-right, only in fun mode)
            RowLayout {
                Layout.fillWidth: true
                visible: app.funMode
                Item { Layout.fillWidth: true }
                CheckBox {
                    id: transparentUnlockCheck
                    text: "📷"
                    font.pixelSize: 16
                    checked: app.transparentUnlocked
                    onCheckedChanged: {
                        if (checked && app.funMode)
                            app.transparentUnlocked = true;
                    }
                    ToolTip.visible: hovered
                    ToolTip.text:   "Unlock Transparent theme"
                    ToolTip.delay:  600
                }
            }

            RowLayout {
                spacing: 8
                Label { text: "Mode:"; font.pixelSize: 14 }
                ComboBox {
                    id: advModeCombo
                    model: ["Constant", "Pulsatile"]
                    font.pixelSize: 14
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
                Label { text: "Shape:"; font.pixelSize: 14 }
                ComboBox {
                    id: advShapeCombo
                    model: ["Square", "Sinusoidal"]
                    font.pixelSize: 14
                    Layout.preferredWidth: 120
                }
            }

            // Base flow (Constant) or Max flow (Pulsatile)
            RowLayout {
                spacing: 8
                Label {
                    text: advModeCombo.currentText === "Pulsatile" ? "Max flow (µL/min):" : "Base flow (µL/min):"
                    font.pixelSize: 14
                }
                TextField {
                    id: advBaseFlowField
                    visible: advModeCombo.currentText === "Constant"
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                TextField {
                    id: advMaxFlowField
                    visible: advModeCombo.currentText === "Pulsatile"
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Pulsatile"
                Label { text: "Period (s):"; font.pixelSize: 14 }
                TextField {
                    id: advPeriodField
                    text: "2.0"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Pulsatile" && advShapeCombo.currentText === "Square"
                Label { text: "Duty (%):"; font.pixelSize: 14 }
                TextField {
                    id: advDutyField
                    text: "50"
                    validator: DoubleValidator { bottom: 1; top: 99; decimals: 1 }
                    Layout.preferredWidth: 70
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Pulsatile"
                Label { text: "Min flow (µL/min):"; font.pixelSize: 14 }
                TextField {
                    id: advMinFlowField
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }

            RowLayout {
                spacing: 8
                CheckBox {
                    id: advTimeLimitCheck
                    text: "Time limit"
                    font.pixelSize: 14
                    checked: true
                    // Tint indicator so it's readable on any background
                    palette.windowText: app.contrastColor(app.theme.cardBg || "#ffffff")
                }
                TextField {
                    id: advTotalMinutesField
                    text: "0.0"
                    enabled: advTimeLimitCheck.checked
                    opacity: advTimeLimitCheck.checked ? 1.0 : 0.4
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Label {
                    text: "min"
                    font.pixelSize: 14
                    visible: advTimeLimitCheck.checked
                }
            }

            CheckBox {
                id: advStepCheck
                text: "Change flow after time"
                font.pixelSize: 14
                visible: advModeCombo.currentText === "Constant"
            }

            RowLayout {
                spacing: 8
                visible: advModeCombo.currentText === "Constant" && advStepCheck.checked
                Label { text: "After (min):"; font.pixelSize: 14 }
                TextField {
                    id: advStepMinField
                    text: "2.0"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 70
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
                Label { text: "New flow (µL/min):"; font.pixelSize: 14 }
                TextField {
                    id: advStepFlowField
                    text: "0.00"
                    validator: DoubleValidator { bottom: 0; decimals: 2 }
                    Layout.preferredWidth: 80
                    font.pixelSize: 14
                    inputMethodHints: Qt.ImhFormattedNumbersOnly | Qt.ImhPreferNumbers
                }
            }
        }

        footer: RowLayout {
            spacing: 8
            Item { Layout.fillWidth: true }
            Button {
                text: "Close"
                font.pixelSize: 14
                onClicked: advancedDialog.close()
                background: Rectangle {
                    radius: 4
                    color:  app.theme.buttonBg || "#607d8b"
                    Behavior on color { ColorAnimation { duration: 80 } }
                }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: app.contrastColor(app.theme.buttonBg || "#607d8b")
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
            Button {
                text: "Apply Advanced Settings"
                font.pixelSize: 14
                background: Rectangle {
                    radius: 4
                    color:  app.theme.buttonBg || "#607d8b"
                    Behavior on color { ColorAnimation { duration: 80 } }
                }
                contentItem: Text {
                    text: parent.text; font: parent.font
                    color: app.contrastColor(app.theme.buttonBg || "#607d8b")
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var pumps = [setup.pump1, setup.pump2, setup.pump3,
                                 setup.pump4, setup.pump5, setup.pump6,
                                 setup.pump7, setup.pump8, setup.pump9];
                    var mode = advModeCombo.currentText;
                    for (var i = 0; i < pumps.length; ++i) {
                        var card = pumps[i];
                        if (!card || !card.selected) continue;
                        card.advMode         = mode;
                        card.advTotalMinutes = advTimeLimitCheck.checked
                                              ? (parseFloat(advTotalMinutesField.text) || 0.0)
                                              : 0.0;
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
        color:  app._isRainbow ? app._rainbowToolbarColor : (app.theme.toolbarBg || "#1565c0")
        Behavior on color { ColorAnimation { duration: 200 } }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Gear / theme-settings button — left side so it's away from the OS close button
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
                    color: app.contrastColor(app.theme.toolbarBg || "#546e7a")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(app.theme.toolbarBg || "#1565c0", 1.3)
                                          : "transparent"
                }
            }

            TabBar {
                id: tabs
                Layout.fillWidth: true
                background: Rectangle { color: "transparent" }

                TabButton {
                    text: "Set up"
                    font.pixelSize: 16
                    contentItem: Text {
                        text:  parent.text
                        font:  parent.font
                        // When active, tab bg = pageBg; contrast against that.
                        // When inactive, text sits on toolbarBg; contrast against that.
                        color: parent.checked
                               ? app.contrastColor(app.theme.pageBg    || "#eef1f5")
                               : app.contrastColor(app.theme.toolbarBg || "#546e7a")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    background: Rectangle {
                        color: parent.checked
                               ? (app.theme.pageBg    || "#eef1f5")
                               : "transparent"
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                TabButton {
                    text: "Run"
                    font.pixelSize: 16
                    contentItem: Text {
                        text:  parent.text
                        font:  parent.font
                        color: parent.checked
                               ? app.contrastColor(app.theme.pageBg    || "#eef1f5")
                               : app.contrastColor(app.theme.toolbarBg || "#546e7a")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    background: Rectangle {
                        color: parent.checked
                               ? (app.theme.pageBg   || "#eef1f5")
                               : "transparent"
                        radius: 4
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
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

                if (!c.pumpStarted) continue; // not yet started — skip
                if (c.paused) continue;        // don't fire step changes while paused

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

                // Compare against per-pump effective elapsed — must subtract both the
                // start offset AND any accumulated pause time so the step fires at
                // the correct amount of actual pumping time, not wall-clock time.
                var pumpElapsed = (elapsedSec - (c.pumpStartedAt || 0)) - c.pumpPausedAccum;
                if (pumpElapsed < stepMinutes * 60)
                    continue;

                var flowVal = parseFloat(flowStr);
                if (!isNaN(flowVal)) {
                    var stepPid    = pumpIdFromRunCard(c);
                    var stepFactor = calibrationForPumpId(stepPid);

                    if (c.setFlowValue)
                        c.setFlowValue.text = flowVal.toFixed(2);

                    if (c.ppsLabel)
                        c.ppsLabel.text = (flowVal * stepFactor).toFixed(0);

                    // Update rawFlow so any subsequent pause/resume restores the
                    // stepped rate rather than reverting to the original flow.
                    c.rawFlow = flowVal;

                    if (typeof backend !== "undefined" && backend.set_flow && stepPid > 0)
                        backend.set_flow(stepPid, flowVal * stepFactor);
                }

                var tag = "Flow changed to " + flowStr + " at " + stepMinutes.toFixed(1) + " min";
                c.infoLabel.text = text + " \u2022 " + tag;

                run.statusLabel.text = "Flow changed at " + stepMinutes.toFixed(1) + " min.";
                logEvent("Flow change", pumpIdFromRunCard(c).toString(),
                         "→ " + flowStr + " µL/min at " + stepMinutes.toFixed(1) + " min");
            }
            // --- per-pump countdown & step-change labels ---
            for (var pi = 0; pi < runCards.length; ++pi) {
                var pc = runCards[pi];
                if (!pc || !pc.visible) continue;
                if (!pc.pumpStarted) continue;  // not started yet — skip countdown

                // Effective elapsed for this pump, relative to when it was started.
                // pumpStartedAt is the universal timer value at the moment the pump
                // was started (via Start All or Start Selected), so subtracting it
                // gives per-pump elapsed time regardless of when the run began.
                var pcEff = pc.paused
                    ? Math.max(0, (pc.pumpPausedAt - pc.pumpStartedAt) - pc.pumpPausedAccum)
                    : ((elapsedSec - pc.pumpStartedAt) - pc.pumpPausedAccum);

                // Main countdown
                if (pc.pumpEndSec > 0) {
                    var remSec = Math.max(0, pc.pumpEndSec - pcEff);
                    if (remSec > 0) {
                        var remM = Math.floor(remSec / 60);
                        var remS = remSec % 60;
                        pc.timerLabel.text = remM + ":" + pad(remS) + " remaining";
                    } else if (!pc.pumpStopped && !pc.paused) {
                        pc.pumpStopped = true;
                        pc.opacity = 0.5;       // grey out — locked until Stop All
                        pc.timerLabel.text = "Done";
                        var stopPid = pumpIdFromRunCard(pc);
                        if (stopPid > 0 && typeof backend !== "undefined" && backend.stop)
                            backend.stop(stopPid);
                        logEvent("Timer complete", stopPid.toString(),
                                 "stopped after " + (pc.pumpDurationSec / 60.0).toFixed(1) + " min");
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

            // --- Check whether all TIMED pumps have finished ----------------
            // Each timed pump sets pumpStopped = true and calls backend.stop()
            // individually when its countdown hits 0.  We only declare
            // "automation complete" once every timed pump is stopped.
            // Manual pumps (pumpEndSec === 0) keep running indefinitely.
            if (!automationFinished && automationTotalMinutes > 0) {
                var hasTimedPumps   = false;
                var allTimedStopped = true;
                var hasRunningManual = false;

                for (var fi = 0; fi < runCards.length; ++fi) {
                    var fc = runCards[fi];
                    if (!fc || !fc.visible) continue;

                    if (fc.pumpEndSec > 0) {
                        hasTimedPumps = true;
                        if (!fc.pumpStopped) allTimedStopped = false;
                    } else {
                        // Manual pump — still running unless explicitly stopped
                        if (!fc.pumpStopped) hasRunningManual = true;
                    }
                }

                if (hasTimedPumps && allTimedStopped) {
                    automationFinished = true;

                    // Mark only timed pump cards as complete
                    for (var fj = 0; fj < runCards.length; ++fj) {
                        var fd = runCards[fj];
                        if (!fd || !fd.visible || fd.pumpEndSec === 0) continue;
                        if (fd.infoLabel && fd.infoLabel.text.indexOf("Run complete") === -1)
                            fd.infoLabel.text += " \u2022 Run complete";
                    }

                    if (hasRunningManual) {
                        run.statusLabel.text = "Timed pumps complete \u2022 Manual pumps still running";
                    } else {
                        // No manual pumps — safe to stop the display timer
                        runTimer.stop();
                        run.statusLabel.text = "Automation complete.";

                        // Fun Mode — celebrate!
                        if (app.funMode) {
                            app.showConfetti = true;
                            confettiTimer.restart();
                        }
                    }
                }
            }
        }
    }

    // ── Fun Mode — Confetti layer ─────────────────────────────────────────────
    Item {
        id: confettiLayer
        anchors.fill: parent
        z: 9995
        visible: app.showConfetti && app.funMode
        clip: true

        Timer {
            id: confettiTimer
            interval: 5500          // hide confetti after 5.5 s
            onTriggered: app.showConfetti = false
        }

        // "Yay!" banner
        Text {
            anchors.centerIn: parent
            z: 1
            text: "🎉  Yay!  🎉"
            font.pixelSize: 72
            font.bold: true
            color: "#e91e63"
            style: Text.Outline; styleColor: "#ffffff"
            SequentialAnimation on scale {
                running: confettiLayer.visible
                loops: Animation.Infinite
                NumberAnimation { to: 1.25; duration: 280; easing.type: Easing.OutQuad }
                NumberAnimation { to: 1.0;  duration: 220; easing.type: Easing.InQuad  }
            }
        }

        // Falling confetti pieces
        Repeater {
            model: 70
            delegate: Rectangle {
                id: piece
                // Deterministic "random" placement from the index
                property real rx: ((index * 137 + 23)  % 1000) / 1000.0
                property real rd: ((index * 293 + 71)  % 800)          // delay 0-800ms
                property real rt: 2800 + ((index * 179) % 1500)        // fall time
                property real rr: ((index * 53)  % 360)                // start rotation

                width:  6 + (index % 5) * 3
                height: width
                radius: index % 3 === 0 ? width / 2 : 1
                color:  ["#ff4444","#ff9900","#ffee00","#44cc00",
                          "#1e90ff","#9933ff","#ff44cc","#00cccc"][index % 8]
                x: rx * (app.width - width)
                y: -20

                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: confettiLayer.visible
                    PauseAnimation        { duration: piece.rd }
                    NumberAnimation       { from: -20; to: app.height + 20
                                            duration: piece.rt; easing.type: Easing.InQuad }
                }
                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    running: confettiLayer.visible
                    from: piece.rr; to: piece.rr + 360
                    duration: 900 + (index % 6) * 150
                }
            }
        }
    }

    // ── Global press tracker — records Y for Nyan Cat targeting ─────────────────
    MouseArea {
        anchors.fill:          parent
        z:                     9990
        propagateComposedEvents: true
        onPressed: { app.lastPressY = mouse.y; mouse.accepted = false; }
    }

    // ── Fun Mode — Nyan Cat overlay ───────────────────────────────────────────
    Item {
        id: nyanLayer
        anchors.fill: parent
        z: 9996
        visible: app.funMode
        clip: false

        // Tracks the y mid-point for the current pass (set by ScriptAction)
        property real nyanBaseY: 200

        NyanCat {
            id: nyanCatItem
            y: nyanLayer.nyanBaseY

            onClicked: {
                if (!app.rainbowUnlocked) {
                    app.rainbowUnlocked = true;
                    unlockToast.visible = true;
                    unlockToastTimer.restart();
                }
            }

            // Fly across with a 5-second gap, targeting last press y.
            SequentialAnimation {
                running: app.funMode
                loops:   Animation.Infinite

                ScriptAction {
                    script: {
                        nyanLayer.nyanBaseY = Math.max(10,
                            Math.min(app.height - nyanCatItem.height - 10,
                                     app.lastPressY - nyanCatItem.height / 2));
                        nyanCatItem.x = -nyanCatItem.width - 10;
                        nyanCatItem.y = nyanLayer.nyanBaseY;
                    }
                }

                NumberAnimation {
                    target: nyanCatItem; property: "x"
                    from:   -nyanCatItem.width - 10
                    to:     app.width + 10
                    duration: 11000
                    easing.type: Easing.Linear
                }

                PauseAnimation { duration: 5000 }
            }

            // Gentle vertical bob around nyanBaseY, runs throughout flight + gap
            SequentialAnimation on y {
                running: app.funMode
                loops:   Animation.Infinite
                NumberAnimation { to: nyanLayer.nyanBaseY - 28; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { to: nyanLayer.nyanBaseY + 28; duration: 1400; easing.type: Easing.InOutSine }
            }
        }

        // "🌈 Rainbow theme unlocked!" toast
        Rectangle {
            id: unlockToast
            anchors.horizontalCenter: parent.horizontalCenter
            y: 160
            width: unlockToastText.implicitWidth + 28
            height: 42
            radius: 10
            color: "#7b1fa2"
            visible: false
            z: 1

            Text {
                id: unlockToastText
                anchors.centerIn: parent
                text: "🌈  Rainbow theme unlocked!  Open Settings to apply."
                font.pixelSize: 16
                color: "#ffffff"
            }

            Timer {
                id: unlockToastTimer
                interval: 3500
                onTriggered: unlockToast.visible = false
            }
        }

        // "🐺 Northeastern theme unlocked!" toast
        Rectangle {
            id: nuToast
            anchors.horizontalCenter: parent.horizontalCenter
            y: 210
            width: nuToastText.implicitWidth + 28
            height: 42
            radius: 10
            color: "#c8102e"
            visible: false
            z: 1

            Text {
                id: nuToastText
                anchors.centerIn: parent
                text: "🐺  Northeastern theme unlocked!  Open Settings to apply."
                font.pixelSize: 16
                color: "#ffffff"
                font.bold: true
            }

            Timer {
                id: nuToastTimer
                interval: 3500
                onTriggered: nuToast.visible = false
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

        // ── Easter egg: "1898" in any numeric field unlocks Northeastern theme ──
        function _checkNU(text) {
            if (app.funMode && !app.northeasternUnlocked && text === "1898") {
                app.northeasternUnlocked = true;
                nuToast.visible = true;
                nuToastTimer.restart();
            }
        }
        setup.groupFlowField.textChanged.connect(function() { _checkNU(setup.groupFlowField.text); });
        setup.primeFlowField.textChanged.connect(function() { _checkNU(setup.primeFlowField.text); });
        var nuCards = [setup.pump1, setup.pump2, setup.pump3,
                       setup.pump4, setup.pump5, setup.pump6,
                       setup.pump7, setup.pump8, setup.pump9];
        for (var ni = 0; ni < nuCards.length; ++ni) {
            (function(card) {
                card.flowField.textChanged.connect(function() { _checkNU(card.flowField.text); });
            })(nuCards[ni]);
        }

        // Setup buttons
        setup.applyGroupButton.clicked.connect(app.applyGroupFlowToSelected);
        setup.readyToRunButton.clicked.connect(function () {
            app.populateRunFromSetup();
            automationFinished = false;
            elapsedSec = 0;
            run.runTimeLabel.text = "00:00:00";
            run.statusLabel.text  = "";
            run.runStarted        = false;
            run.allPumpsStarted   = false;
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

        // Prime buttons: toggle priming at calibration-scaled speed
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
                        if (backend.prime) {
                            // Use the shared Prime flow field (toolbar, default 15 µL/min)
                            // multiplied by this pump's calibration factor.
                            var primeFlow = parseFloat(setup.primeFlowField.text) || 0.0;
                            var primeCal  = calibrationForPumpId(pid);
                            var primePps  = primeFlow > 0 ? primeFlow * primeCal : 0.0;
                            backend.prime(pid, primePps);
                        }
                    } else {
                        if (backend.stop)
                            backend.stop(pid);
                    }
                }
            })(card));
        }

        // ── Run buttons ───────────────────────────────────────────────────────

        // ── Start All / Stop All (toggling button) ────────────────────────────
        run.startButton.clicked.connect(function () {
            // When the run is already active the button shows "Stop All"
            if (run.runStarted) {
                stopAllDialog.open();
                return;
            }

            var allRunCards = [run.r1, run.r2, run.r3, run.r4,
                               run.r5, run.r6, run.r7, run.r8, run.r9];
            var visible = [];
            for (var vi = 0; vi < allRunCards.length; ++vi)
                if (allRunCards[vi] && allRunCards[vi].visible) visible.push(allRunCards[vi]);

            automationFinished = false;
            _startCards(visible);

            run.runStarted      = true;
            run.allPumpsStarted = true;  // Start All touches every visible pump

            var ids = [];
            for (var ii = 0; ii < visible.length; ++ii)
                ids.push(pumpIdFromRunCard(visible[ii]));
            logEvent("Start All", ids.join(", "), "");
        });

        // ── Start Selected ────────────────────────────────────────────────────
        run.startSelectedButton.clicked.connect(function () {
            var selIds = selectedRunPumpIds();
            if (!selIds.length) return;

            var allRunCards2 = [run.r1, run.r2, run.r3, run.r4,
                                run.r5, run.r6, run.r7, run.r8, run.r9];
            var selCards = [];
            for (var vi2 = 0; vi2 < allRunCards2.length; ++vi2) {
                var c2 = allRunCards2[vi2];
                if (c2 && c2.visible && c2.selected) selCards.push(c2);
            }

            _startCards(selCards);

            // Deselect the cards that were just started
            for (var di = 0; di < selCards.length; ++di)
                selCards[di].selected = false;

            // Switch the Start All button to Stop All mode
            run.runStarted = true;

            // Grey out Start Selected once every visible pump has been started
            var allStartedNow = true;
            for (var ci = 0; ci < allRunCards2.length; ++ci) {
                var ck = allRunCards2[ci];
                if (ck && ck.visible && !ck.pumpStarted) { allStartedNow = false; break; }
            }
            run.allPumpsStarted = allStartedNow;

            logEvent("Start Selected", selIds.join(", "), "");
        });

        // ── Pause All ─────────────────────────────────────────────────────────
        run.pauseButton.clicked.connect(function () {
            // Do NOT stop the universal timer — just freeze individual pump timers
            var allCards = [run.r1, run.r2, run.r3, run.r4,
                            run.r5, run.r6, run.r7, run.r8, run.r9];
            var pausedIds = [];
            for (var i = 0; i < allCards.length; ++i) {
                var ac = allCards[i];
                if (!ac || !ac.visible || !ac.pumpStarted || ac.pumpStopped) continue;
                if (!ac.paused) {
                    ac.paused = true;
                    ac.pumpPausedAt = elapsedSec;
                    pausedIds.push(pumpIdFromRunCard(ac));
                }
            }
            if (typeof backend !== "undefined" && backend.pauseAll)
                backend.pauseAll();
            logEvent("Pause All", pausedIds.join(", "), "");
        });

        // ── Stop All ──────────────────────────────────────────────────────────
        run.stopButton.clicked.connect(function () {
            stopAllDialog.open();
        });
        // ── Pause Selected ────────────────────────────────────────────────────
        run.pauseSelectedButton.clicked.connect(function () {
            var ids = selectedRunPumpIds();
            if (!ids.length) return;
            var runCards = [run.r1, run.r2, run.r3, run.r4,
                            run.r5, run.r6, run.r7, run.r8, run.r9];
            for (var j = 0; j < runCards.length; ++j) {
                var c3 = runCards[j];
                if (!c3 || !c3.visible || !c3.selected || !c3.pumpStarted || c3.pumpStopped) continue;
                var pid = pumpIdFromRunCard(c3);
                if (ids.indexOf(pid) !== -1 && !c3.paused) {
                    c3.paused = true;
                    c3.pumpPausedAt = elapsedSec;
                    if (pausedPumpIds.indexOf(pid) === -1)
                        pausedPumpIds.push(pid);
                }
            }
            if (typeof backend !== "undefined" && backend.pausePumps)
                backend.pausePumps(ids);
            logEvent("Pause Selected", ids.join(", "), "");
        });

        // ── Resume Selected ───────────────────────────────────────────────────
        run.resumeSelectedButton.clicked.connect(function () {
            var ids = selectedRunPumpIds();
            if (!ids.length) return;

            var runCards2 = [run.r1, run.r2, run.r3, run.r4,
                             run.r5, run.r6, run.r7, run.r8, run.r9];

            var resumedIds        = [];
            var pulsatileReIds    = [];
            var pulsatileReModes  = [];
            var pulsatileReShapes = [];
            var pulsatileReMins   = [];
            var pulsatileRePer    = [];
            var pulsatileReDuty   = [];
            var pulsatileReMin    = [];
            var pulsatileReMax    = [];

            for (var j2 = 0; j2 < runCards2.length; ++j2) {
                var c4 = runCards2[j2];
                if (!c4 || !c4.visible || !c4.selected) continue;
                var pid4 = pumpIdFromRunCard(c4);
                if (ids.indexOf(pid4) === -1) continue;
                if (c4.pumpStopped) continue;   // skip completed pumps
                if (!c4.paused) continue;        // not paused, nothing to resume

                var isPulsatile4 = c4.infoLabel && c4.infoLabel.text.indexOf("pulsatile") !== -1;

                // Calculate remaining time BEFORE updating pumpPausedAccum.
                // pcEff at pause = (pumpPausedAt - pumpStartedAt) - pumpPausedAccum
                var pcEff4   = Math.max(0, (c4.pumpPausedAt - c4.pumpStartedAt) - c4.pumpPausedAccum);
                var remSec4  = c4.pumpEndSec > 0 ? Math.max(0, c4.pumpEndSec - pcEff4) : 0;

                // Accumulate pause duration — pumpPausedAccum already handles
                // the offset so pumpEndSec does NOT need to be recalculated.
                if (c4.pumpPausedAt >= 0)
                    c4.pumpPausedAccum += elapsedSec - c4.pumpPausedAt;
                c4.pumpPausedAt = -1;
                c4.paused = false;

                resumedIds.push(pid4);

                var idx4 = pausedPumpIds.indexOf(pid4);
                if (idx4 !== -1) pausedPumpIds.splice(idx4, 1);

                // Pulsatile pumps need startAutomation (not just set_flow).
                // Always restart regardless of time limit — pass remaining mins,
                // or 0 for no-limit pumps (0 = run indefinitely in backend).
                if (isPulsatile4) {
                    for (var ai4 = 0; ai4 < autoIds.length; ++ai4) {
                        if (autoIds[ai4] === pid4) {
                            pulsatileReIds.push(autoIds[ai4]);
                            pulsatileReModes.push(autoModes[ai4]);
                            pulsatileReShapes.push(autoShapes[ai4]);
                            var minsToResume = c4.pumpEndSec > 0 ? remSec4 / 60.0 : 0;
                            pulsatileReMins.push(minsToResume);
                            pulsatileRePer.push(autoPeriods[ai4]);
                            pulsatileReDuty.push(autoDuties[ai4]);
                            var reCal = calibrationForPumpId(autoIds[ai4]);
                            pulsatileReMin.push(autoMinFlows[ai4] * reCal);
                            pulsatileReMax.push(autoMaxFlows[ai4] * reCal);
                            break;
                        }
                    }
                } else if (!isPulsatile4) {
                    if (typeof backend !== "undefined" && backend.set_flow && c4.rawFlow > 0) {
                        var resCal = calibrationForPumpId(pid4);
                        backend.set_flow(pid4, c4.rawFlow * resCal);
                    }
                }
            }

            // Restart pulsatile automation with remaining time
            if (pulsatileReIds.length > 0 &&
                typeof backend !== "undefined" && backend.startAutomation) {
                backend.startAutomation(pulsatileReIds, pulsatileReModes,
                                        pulsatileReShapes, pulsatileReMins,
                                        pulsatileRePer, pulsatileReDuty,
                                        pulsatileReMin, pulsatileReMax);
            }

            if (resumedIds.length > 0) {
                if (!runTimer.running) runTimer.start();
                logEvent("Resume Selected", resumedIds.join(", "), "");
            }
        });

        // ── History ───────────────────────────────────────────────────────────
        run.historyButton.clicked.connect(function () {
            historyDialog.open();
        });

    }
}
