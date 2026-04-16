import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: root

    property var themeColors: ({
        buttonBg:    "#607d8b",
        buttonFlash: "#37474f"
    })

    property int flashDuration: 450
    property bool _flashed: false

    function _luma(hex) {
        if (!hex || hex.length < 7) return 0.5;
        var r = parseInt(hex.slice(1,3),16)/255;
        var g = parseInt(hex.slice(3,5),16)/255;
        var b = parseInt(hex.slice(5,7),16)/255;
        return 0.299*r + 0.587*g + 0.114*b;
    }

    Timer {
        id: flashTimer
        interval: root.flashDuration
        onTriggered: root._flashed = false
    }

    onClicked: { _flashed = true; flashTimer.restart() }

    background: Rectangle {
        radius: 4
        color: root._flashed
               ? (root.themeColors.buttonFlash || "#37474f")
               : (root.themeColors.buttonBg    || "#607d8b")
        Behavior on color { ColorAnimation { duration: 80 } }
    }

    contentItem: Text {
        text:                root.text
        font:                root.font
        color:               root._luma(root._flashed
                               ? (root.themeColors.buttonFlash || "#37474f")
                               : (root.themeColors.buttonBg    || "#607d8b")) > 0.5
                             ? "#000000" : "#ffffff"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
        elide:               Text.ElideRight
    }
}
