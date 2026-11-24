import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Important Note: Toolbar buttons must manage their checked state manually in order to support
// view switch prevention. This means they can't be checkable or autoExclusive.

Button {
    id:                 button
    height:             ScreenTools.defaultFontPixelHeight * 3
    leftPadding:        _horizontalMargin
    rightPadding:       _horizontalMargin
    checkable:          false

    property bool logo: false

    property real _horizontalMargin: ScreenTools.defaultFontPixelWidth

    onCheckedChanged: checkable = false

    background: Rectangle {
        anchors.fill:   parent
        anchors.margins: 2
        radius:         ScreenTools.defaultFontPixelWidth * 0.6
        color:          button.checked
                        ? qgcPal.accent
                        : (button.hovered ? Qt.rgba(0.60, 0.42, 1.0, 0.22) : Qt.rgba(0, 0, 0, 0))
        border.color:   QGroundControl.corePlugin.showTouchAreas ? "red" : qgcPal.brandPrimary
        border.width:   QGroundControl.corePlugin.showTouchAreas ? 3 : (button.hovered && !button.checked ? 1 : 0)
    }

    contentItem: Row {
        spacing:                ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: button.verticalCenter
        // Logo buttons render the multi-colour logo natively; non-logo buttons tint their
        // monochrome icon through QGCColoredImage. Plain `Row` skips visible:false items.
        // A plain Image handles both SVG and raster (PNG) logos, so rebranded builds can
        // ship either format without breaking the toolbar.
        Image {
            visible:                button.logo
            height:                 ScreenTools.defaultFontPixelHeight * 2
            width:                  height
            fillMode:               Image.PreserveAspectFit
            source:                 visible ? button.icon.source : ""
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                objectName:         "toolbar_qgcUpdateAvailableBadge"
                z:                  1
                anchors.top:        parent.top
                anchors.right:      parent.right
                anchors.topMargin:  -height * 0.25
                anchors.rightMargin: -width * 0.25
                width:              ScreenTools.defaultFontPixelHeight
                height:             width
                radius:             width / 2
                color:              Qt.rgba(1, 1, 1, 0.75)
                visible:            QGroundControl.newStableVersion !== ""

                QGCColoredImage {
                    anchors.fill:   parent
                    source:         "/res/UpdateAvailable.svg"
                    color:          qgcPal.colorBlue
                }
            }
        }
        QGCColoredImage {
            visible:                !button.logo
            height:                 ScreenTools.defaultFontPixelHeight * 2
            width:                  height
            sourceSize.height:      parent.height
            fillMode:               Image.PreserveAspectFit
            color:                  button.checked ? qgcPal.accentText : qgcPal.textPrimary
            source:                 visible ? button.icon.source : ""
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id:                     _label
            visible:                text !== ""
            text:                   button.text
            color:                  button.checked ? qgcPal.accentText : qgcPal.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
