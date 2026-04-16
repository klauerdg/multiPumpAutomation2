import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// HSV colour wheel picker dialog.
// Set initialColor before calling open(), then listen for colorAccepted(hex).
Dialog {
    id: root
    modal: true
    closePolicy: Popup.CloseOnEscape
    title: "Pick a Color"
    width: 320

    // ── Public API ────────────────────────────────────────────────────────────
    property color initialColor: "#ffffff"
    property color currentColor: "#ffffff"

    signal colorAccepted(string hex)

    // ── Internal HSV state ────────────────────────────────────────────────────
    property real _h: 0      // hue        0–1
    property real _s: 0      // saturation 0–1
    property real _v: 1      // value      0–1

    // ── Helpers ───────────────────────────────────────────────────────────────
    function _colorToHsv(c) {
        var r = c.r, g = c.g, b = c.b;
        var mx = Math.max(r, g, b);
        var mn = Math.min(r, g, b);
        var d  = mx - mn;
        _v = mx;
        _s = (mx === 0) ? 0 : d / mx;
        if (d === 0) { _h = 0; return; }
        if      (mx === r) _h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
        else if (mx === g) _h = ((b - r) / d + 2) / 6;
        else               _h = ((r - g) / d + 4) / 6;
    }

    function _refresh() {
        currentColor = Qt.hsva(_h, _s, _v, 1.0);
        wheel.requestPaint();
        valSlider.value = _v;
        if (!hexInput.activeFocus)
            hexInput.text = currentColor.toString().toUpperCase();
    }

    onOpened: {
        _colorToHsv(initialColor);
        currentColor = initialColor;
        _refresh();
    }

    // ── Content ───────────────────────────────────────────────────────────────
    contentItem: ColumnLayout {
        anchors.margins: 12
        spacing: 10

        // ── Wheel ─────────────────────────────────────────────────────────────
        Canvas {
            id: wheel
            width: 240; height: 240
            Layout.alignment: Qt.AlignHCenter

            // Wheel geometry (used by paint + hit-test)
            readonly property real cx: width  / 2
            readonly property real cy: height / 2
            readonly property real wr: Math.min(width, height) / 2 - 6

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // Render each pixel inside the circle using HSV
                var img  = ctx.createImageData(width, height);
                var data = img.data;
                var cx2 = cx, cy2 = cy, r2 = wr * wr;

                for (var py = 0; py < height; py++) {
                    for (var px = 0; px < width; px++) {
                        var dx = px - cx2;
                        var dy = py - cy2;
                        if (dx * dx + dy * dy > r2) continue;

                        var hh   = (Math.atan2(dy, dx) / (2 * Math.PI) + 1) % 1;
                        var ss   = Math.sqrt(dx * dx + dy * dy) / wr;
                        var col  = Qt.hsva(hh, ss, root._v, 1.0);
                        var idx  = (py * width + px) * 4;
                        data[idx]     = col.r * 255;
                        data[idx + 1] = col.g * 255;
                        data[idx + 2] = col.b * 255;
                        data[idx + 3] = 255;
                    }
                }
                ctx.putImageData(img, 0, 0);

                // Crosshair at current H+S position
                var ang = root._h * 2 * Math.PI;
                var rr  = root._s * wr;
                var hx  = cx2 + Math.cos(ang) * rr;
                var hy  = cy2 + Math.sin(ang) * rr;

                // Outer dark ring
                ctx.beginPath();
                ctx.arc(hx, hy, 9, 0, 2 * Math.PI);
                ctx.strokeStyle = "#000000";
                ctx.lineWidth = 2.5;
                ctx.stroke();
                // Inner white ring
                ctx.beginPath();
                ctx.arc(hx, hy, 9, 0, 2 * Math.PI);
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = 1.5;
                ctx.stroke();
            }

            MouseArea {
                anchors.fill: parent
                function pick(mx, my) {
                    var dx   = mx - wheel.cx;
                    var dy   = my - wheel.cy;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    root._h  = (Math.atan2(dy, dx) / (2 * Math.PI) + 1) % 1;
                    root._s  = Math.min(dist / wheel.wr, 1.0);
                    root._refresh();
                }
                onClicked:         pick(mouseX, mouseY)
                onPositionChanged: if (pressed) pick(mouseX, mouseY)
            }
        }

        // ── Brightness slider ─────────────────────────────────────────────────
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Label { text: "Brightness:"; font.pixelSize: 12 }

            Slider {
                id: valSlider
                from: 0.05; to: 1.0; value: root._v
                Layout.fillWidth: true

                onMoved: {
                    root._v = value;
                    root._refresh();
                }

                background: Rectangle {
                    x: valSlider.leftPadding
                    y: valSlider.topPadding + valSlider.availableHeight / 2 - height / 2
                    width:  valSlider.availableWidth
                    height: 12; radius: 6
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#000000" }
                        GradientStop {
                            position: 1.0
                            color: Qt.hsva(root._h, Math.max(root._s, 0.15), 1.0, 1.0)
                        }
                    }
                }

                handle: Rectangle {
                    x: valSlider.leftPadding + valSlider.visualPosition * valSlider.availableWidth - width / 2
                    y: valSlider.topPadding  + valSlider.availableHeight / 2 - height / 2
                    width: 18; height: 18; radius: 9
                    color: "#ffffff"
                    border.color: "#888888"; border.width: 1
                }
            }
        }

        // ── Preview + hex input ───────────────────────────────────────────────
        RowLayout {
            spacing: 10
            Layout.fillWidth: true

            // Before / After swatches
            ColumnLayout {
                spacing: 2
                Label { text: "Before"; font.pixelSize: 10; color: "#888" }
                Rectangle {
                    width: 44; height: 28; radius: 4
                    color: root.initialColor
                    border.color: "#aaaaaa"; border.width: 1
                }
            }
            ColumnLayout {
                spacing: 2
                Label { text: "After"; font.pixelSize: 10; color: "#888" }
                Rectangle {
                    width: 44; height: 28; radius: 4
                    color: root.currentColor
                    border.color: "#aaaaaa"; border.width: 1
                }
            }

            Item { Layout.fillWidth: true }

            // Hex text input
            ColumnLayout {
                spacing: 2
                Label { text: "Hex"; font.pixelSize: 10; color: "#888" }
                TextField {
                    id: hexInput
                    text: root.currentColor.toString().toUpperCase()
                    Layout.preferredWidth: 90
                    font.pixelSize: 12
                    font.family: "Monospace"
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

                    onEditingFinished: {
                        var v = text.trim().toUpperCase();
                        if (/^#[0-9A-F]{6}$/.test(v)) {
                            root._colorToHsv(Qt.color(v));
                            root.currentColor = Qt.color(v);
                            root._refresh();
                        }
                    }
                }
            }
        }
    }

    // ── Footer buttons ────────────────────────────────────────────────────────
    footer: RowLayout {
        spacing: 8
        Item { Layout.fillWidth: true }
        Button {
            text: "Cancel"
            font.pixelSize: 12
            onClicked: root.close()
        }
        Button {
            text: "OK"
            font.pixelSize: 12
            onClicked: {
                root.colorAccepted(root.currentColor.toString().toUpperCase());
                root.close();
            }
        }
    }
}
