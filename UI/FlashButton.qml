import QtQuick 2.15
import QtQuick.Controls 2.15

// A Button that briefly flashes a darker colour after being pressed so the
// user can clearly see the tap was registered on a touchscreen.
// Set themeColors to the current theme object for automatic colour updates.
// Does NOT apply to the Prime button (which has its own priming-state style).
Button {
    id: root

    property var themeColors: ({
        buttonBg:    "#1976d2",
        buttonFlash: "#0d47a1",
        buttonText:  "#ffffff"
    })

    // How long the flash colour stays visible (ms)
    property int flashDuration: 450

    property bool _flashed: false

    Timer {
        id: flashTimer
        interval: root.flashDuration
        onTriggered: root._flashed = false
    }

    onClicked: {
        _flashed = true
        flashTimer.restart()
    }

    background: Rectangle {
        radius: 4
        color: root._flashed
               ? (root.themeColors.buttonFlash || "#0d47a1")
               : (root.themeColors.buttonBg    || "#1976d2")
        Behavior on color { ColorAnimation { duration: 80 } }
    }

    contentItem: Text {
        text:                root.text
        font:                root.font
        color:               root.themeColors.buttonText || "#ffffff"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
        elide:               Text.ElideRight
    }
}
