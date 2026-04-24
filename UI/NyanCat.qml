import QtQuick 2.15

// Nyan Cat — the classic meme cat with a pop-tart body and rainbow trail.
// Float animation is driven externally (Main.qml sets x / y animations).
// Click the cat to unlock the Rainbow theme.

Item {
    id: root
    // Width = rainbow trail + body.  Height matches the 6 rainbow bands.
    width:  rainbowTrail.width + catBody.width
    height: 54

    signal clicked()

    // ── Rainbow trail ─────────────────────────────────────────────────────────
    Column {
        id: rainbowTrail
        anchors.left:            parent.left
        anchors.verticalCenter:  catBody.verticalCenter
        spacing: 0

        Repeater {
            model: ["#ff0000","#ff8c00","#ffff00","#00cc44","#1e90ff","#9400d3"]
            Rectangle {
                width:  130
                height: 9
                color:  modelData
            }
        }
    }

    // ── Pop-tart body ─────────────────────────────────────────────────────────
    Rectangle {
        id: catBody
        anchors.left:            rainbowTrail.right
        anchors.leftMargin:      -6
        anchors.verticalCenter:  parent.verticalCenter
        width:  72
        height: 54
        radius: 6
        color:  "#e8b4c8"          // pastel pink
        border.color: "#c49ab0"
        border.width: 2

        // Frosting dots
        Grid {
            anchors.fill:    parent
            anchors.margins: 8
            columns: 3
            spacing: 4
            Repeater {
                model: 9
                Rectangle {
                    width: 7; height: 7; radius: 4
                    color: ["#ff99cc","#ffccee","#ff66aa"][index % 3]
                    opacity: 0.85
                }
            }
        }

        // ── Cat head ─────────────────────────────────────────────────────────
        Item {
            id: catHead
            width: 52; height: 44
            anchors.centerIn: parent

            // Left ear
            Rectangle {
                x: 4; y: 0
                width: 12; height: 12
                color: "#909090"
                rotation: -20
            }
            // Right ear
            Rectangle {
                x: 36; y: 0
                width: 12; height: 12
                color: "#909090"
                rotation: 20
            }

            // Face
            Rectangle {
                x: 6; y: 8
                width: 40; height: 32
                radius: 9
                color: "#b0b0b0"

                // Eyes (closed / squinting — classic nyan cat look)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top:              parent.top
                    anchors.topMargin:        8
                    spacing: 9
                    Rectangle { width: 8; height: 3; radius: 2; color: "#222" }
                    Rectangle { width: 8; height: 3; radius: 2; color: "#222" }
                }

                // Blush left
                Rectangle {
                    x: 2; y: 18
                    width: 9; height: 5; radius: 3
                    color: "#ff8888"; opacity: 0.65
                }
                // Blush right
                Rectangle {
                    x: 29; y: 18
                    width: 9; height: 5; radius: 3
                    color: "#ff8888"; opacity: 0.65
                }

                // Mouth
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom:           parent.bottom
                    anchors.bottomMargin:     4
                    text:           "—"
                    font.pixelSize: 9
                    color:          "#333"
                }
            }
        }
    }

    // ── Sparkle stars ─────────────────────────────────────────────────────────
    Repeater {
        model: ListModel {
            ListElement { sx: -22; sy:  4; sz: 11; sc: "#ffffff"; sd: 500 }
            ListElement { sx: -55; sy: 28; sz:  8; sc: "#ffff88"; sd: 750 }
            ListElement { sx: -80; sy: 10; sz: 13; sc: "#ff88ff"; sd: 350 }
            ListElement { sx: -105;sy: 38; sz:  7; sc: "#88ffff"; sd: 600 }
        }
        Text {
            x:               model.sx + catBody.x
            y:               model.sy
            text:            "★"
            font.pixelSize:  model.sz
            color:           model.sc
            opacity:         0.85

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.1; duration: model.sd }
                NumberAnimation { to: 0.9; duration: model.sd }
            }
        }
    }

    // ── Click target ──────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.clicked()
    }
}
