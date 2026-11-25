import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import QGroundControl
import QGroundControl.Controls
import QGroundControl.VideoManager

/// One RTSP video card for the Y-GCS Fly view dashboard.
Rectangle {
    id: card

    property var    stream
    property string title: qsTr("RTSP")
    property bool   large: false

    signal clicked()
    signal settingsClicked()

    readonly property bool _hasUri: !!stream && stream.uri !== ""
    readonly property bool _live: !!stream && stream.decoding
    readonly property string _status: _live ? qsTr("LIVE") : (_hasUri ? qsTr("CONNECTING") : qsTr("NO STREAM"))
    readonly property color _accent: "#9a6bff"
    readonly property color _ok: "#34d399"
    readonly property color _muted: "#8b8f98"

    radius: large ? 12 : 10
    color: "#050506"
    border.width: 1
    border.color: large ? _accent : "#363a41"
    clip: true

    VideoStreamOutput {
        anchors.fill: parent
        stream: card.stream
        fillMode: VideoOutput.PreserveAspectFit
        visible: card._hasUri
    }

    // Placeholder when the card has no URL yet.
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width * 0.8
        spacing: 4
        visible: !card._hasUri
        QGCLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No RTSP URL")
            color: card._muted
            font.pixelSize: card.large ? 16 : 12
            font.bold: true
        }
        QGCLabel {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Tap the gear to configure")
            color: card._muted
            font.pixelSize: card.large ? 12 : 10
        }
    }

    // Title + status strip
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 8
        height: titleRow.height + 8
        width: titleRow.width + 16
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.55)
        RowLayout {
            id: titleRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: card._live ? card._ok : (card._hasUri ? "#f59e0b" : "#6a6a6a")
            }
            QGCLabel {
                text: card.title
                color: "#f1f2f4"
                font.pixelSize: card.large ? 12 : 10
                font.bold: true
                font.letterSpacing: 1
            }
            QGCLabel {
                text: card._status
                color: card._live ? card._ok : card._muted
                font.pixelSize: card.large ? 10 : 9
                font.bold: true
            }
        }
    }

    // Click anywhere to bring this stream to the large slot.
    MouseArea {
        anchors.fill: parent
        onClicked: card.clicked()
    }

    // Gear stays above the click area.
    Rectangle {
        id: gearButton
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        width: card.large ? 32 : 28
        height: width
        radius: 8
        color: gearMouse.containsMouse ? "#1b1e23" : Qt.rgba(0, 0, 0, 0.55)
        border.width: 1
        border.color: "#363a41"

        QGCColoredImage {
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: width
            source: "/qmlimages/Gears.svg"
            color: card._accent
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
        }
        MouseArea {
            id: gearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.settingsClicked()
        }
    }
}
