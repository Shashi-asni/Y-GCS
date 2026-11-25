import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.VideoManager

/// Y-GCS Fly view dashboard: one large slot and two small cards.
/// The large slot shows the map or one of the two RTSP streams; the small
/// cards show the other two. Clicking a card swaps it with the large slot.
Item {
    id: root

    /// 0 = map large, 1 = primary RTSP large, 2 = thermal RTSP large
    property int mainState: 0

    readonly property bool mapIsMain: mainState === 0
    readonly property var  videoManager: QGroundControl.videoManager
    readonly property var  videoSettings: QGroundControl.settingsManager.videoSettings
    readonly property var  primaryStream: videoManager.primaryStream
    readonly property var  thermalStream: videoManager.thermalStream

    readonly property real _m: ScreenTools.defaultFontPixelWidth * 0.75
    // Compact video cards overlay the full-screen map at the bottom corners.
    readonly property real _smallW: Math.max(220, Math.min(380, width * 0.27))
    readonly property real _smallH: _smallW * 9 / 16

    readonly property rect fullRect: Qt.rect(0, 0, width, height)
    readonly property rect small1Rect: Qt.rect(_m, height - _smallH - _m, _smallW, _smallH)
    readonly property rect small2Rect: Qt.rect(width - _m - _smallW, height - _smallH - _m, _smallW, _smallH)

    readonly property rect mapRect: mapIsMain ? fullRect : small1Rect
    readonly property rect primaryRect: mainState === 1 ? fullRect : (mainState === 2 ? small2Rect : small1Rect)
    readonly property rect thermalRect: mainState === 2 ? fullRect : small2Rect

    function _startConfiguredStreams() {
        if (videoSettings.rtspUrl.rawValue !== "" || videoSettings.rtspUrl2.rawValue !== "") {
            videoManager.startVideo()
        }
    }

    function _openSettings(target) {
        settingsPopup.target = target
        urlField.text = (target === 0 ? videoSettings.rtspUrl.rawValue : videoSettings.rtspUrl2.rawValue)
        settingsPopup.open()
        urlField.forceActiveFocus()
    }

    function _saveSettings() {
        const url = urlField.text.trim()
        if (settingsPopup.target === 0) {
            videoSettings.rtspUrl.rawValue = url
            if (url !== "") {
                videoSettings.videoSource.rawValue = videoSettings.rtspVideoSource
            }
        } else {
            videoSettings.rtspUrl2.rawValue = url
        }
        settingsPopup.close()
        _startConfiguredStreams()
    }

    Component.onCompleted: {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            _startConfiguredStreams()
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() {
            if (QGroundControl.multiVehicleManager.activeVehicle) {
                root._startConfiguredStreams()
            }
        }
    }

    YGCSFlyVideoCard {
        id: primaryCard
        stream: root.primaryStream
        title: qsTr("LIVE RTSP")
        large: root.mainState === 1
        z: large ? 0 : 2
        x: root.primaryRect.x
        y: root.primaryRect.y
        width: root.primaryRect.width
        height: root.primaryRect.height
        onClicked: root.mainState = 1
        onSettingsClicked: root._openSettings(0)

        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    YGCSFlyVideoCard {
        id: thermalCard
        stream: root.thermalStream
        title: qsTr("THERMAL RTSP")
        large: root.mainState === 2
        z: large ? 0 : 2
        x: root.thermalRect.x
        y: root.thermalRect.y
        width: root.thermalRect.width
        height: root.thermalRect.height
        onClicked: root.mainState = 2
        onSettingsClicked: root._openSettings(1)

        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Popup {
        id: settingsPopup
        property int target: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        width: Math.min(460, root.width - 60)
        height: 236
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        padding: 0

        background: Rectangle {
            radius: 14
            color: "#101114"
            border.width: 1
            border.color: "#363a41"
        }

        contentItem: ColumnLayout {
            spacing: 12
            Layout.margins: 0

            QGCLabel {
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.topMargin: 16
                text: settingsPopup.target === 0 ? qsTr("Live RTSP Stream") : qsTr("Thermal RTSP Stream")
                color: "#f1f2f4"
                font.pixelSize: 18
                font.bold: true
            }

            QGCLabel {
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                text: qsTr("RTSP URL")
                color: "#8b8f98"
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }

            QGCTextField {
                id: urlField
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.fillWidth: true
                placeholderText: "rtsp://192.168.1.100:554/stream"
                onAccepted: root._saveSettings()
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.bottomMargin: 16
                Layout.fillWidth: true
                spacing: 10
                Item { Layout.fillWidth: true }
                QGCButton {
                    text: qsTr("Cancel")
                    onClicked: settingsPopup.close()
                }
                QGCButton {
                    text: qsTr("Save & Connect")
                    primary: true
                    onClicked: root._saveSettings()
                }
            }
        }
    }
}
