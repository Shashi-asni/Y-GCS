#include "QGCPalette.h"
#include "QGCCorePlugin.h"

#include <QtCore/QDebug>

QList<QGCPalette*>   QGCPalette::_paletteObjects;

QGCPalette::Theme QGCPalette::_theme = QGCPalette::Dark;

QMap<int, QMap<int, QMap<QString, QColor>>> QGCPalette::_colorInfoMap;

QStringList QGCPalette::_colors;

QGCPalette::QGCPalette(QObject* parent) :
    QObject(parent),
    _colorGroupEnabled(true)
{
    if (_colorInfoMap.isEmpty()) {
        _buildMap();
    }

    // We have to keep track of all QGCPalette objects in the system so we can signal theme change to all of them
    _paletteObjects += this;
}

QGCPalette::~QGCPalette()
{
    bool fSuccess = _paletteObjects.removeOne(this);
    if (!fSuccess) {
        qWarning() << "Internal error";
    }
}

void QGCPalette::_buildMap()
{
    // clang-format off
    //                                      Light                 Dark
    //                                      Disabled   Enabled    Disabled   Enabled
    // Surfaces nest window -> windowPanel -> windowCard; windowInset is for input wells inside any of them.
    // YantraYug Y-GCS theme, ported from the frontend design tokens:
    // graphite/black shell, violet #9a6bff accent, magenta #c026d3 secondary.
    DECLARE_QGC_COLOR(window,               "#f4f6fb", "#f4f6fb", "#050506", "#050506")
    DECLARE_QGC_COLOR(windowTransparent,    "#ccf4f6fb", "#ccf4f6fb", "#cc050506", "#cc050506")
    DECLARE_QGC_COLOR(windowPanel,          "#ffffff", "#ffffff", "#101114", "#101114")
    DECLARE_QGC_COLOR(windowCard,           "#f8f9fd", "#f8f9fd", "#1b1e23", "#1b1e23")
    DECLARE_QGC_COLOR(windowInset,          "#eef1f8", "#ffffff", "#000000", "#101114")
    DECLARE_QGC_COLOR(borderSubtle,         "#e1e6f0", "#cfd7e6", "#26282d", "#363a41")
    DECLARE_QGC_COLOR(textPrimary,          "#7c8799", "#131a2a", "#676b73", "#f1f2f4")
    DECLARE_QGC_COLOR(textSecondary,        "#5b677d", "#5b677d", "#8b8f98", "#8b8f98")
    DECLARE_QGC_COLOR(accent,               "#e4e4e4", "#6d28d9", "#1b1e23", "#9a6bff")
    DECLARE_QGC_COLOR(accentSubtle,         "#f4f6fb", "#ede9fe", "#141019", "#1e1630")
    DECLARE_QGC_COLOR(accentText,           "#2c2c2c", "#ffffff", "#2c2c2c", "#ffffff")
    DECLARE_QGC_COLOR(errorText,            "#dc2626", "#dc2626", "#ef4444", "#ef4444")
    DECLARE_QGC_COLOR(warningText,          "#5b6b80", "#5b6b80", "#8fa2bd", "#8fa2bd")
    DECLARE_QGC_COLOR(successText,          "#0f9f6e", "#0f9f6e", "#34d399", "#34d399")
    DECLARE_QGC_COLOR(mapButton,            "#8b8f98", "#131a2a", "#8b8f98", "#000000")
    DECLARE_QGC_COLOR(mapButtonHighlight,   "#8b8f98", "#6d28d9", "#8b8f98", "#9a6bff")
    DECLARE_QGC_COLOR(mapIndicator,         "#8b8f98", "#6d28d9", "#8b8f98", "#9a6bff")
    DECLARE_QGC_COLOR(mapIndicatorChild,    "#5b677d", "#4c1d95", "#8b8f98", "#6d4aa8")
    DECLARE_QGC_COLOR(colorGreen,           "#0f9f6e", "#0f9f6e", "#34d399", "#34d399")
    DECLARE_QGC_COLOR(colorYellow,          "#a2a200", "#a2a200", "#facc15", "#facc15")
    DECLARE_QGC_COLOR(colorYellowGreen,     "#799f26", "#799f26", "#9dbe2f", "#9dbe2f")
    DECLARE_QGC_COLOR(colorOrange,          "#bf7539", "#bf7539", "#f59e0b", "#f59e0b")
    DECLARE_QGC_COLOR(colorRed,             "#dc2626", "#dc2626", "#ef4444", "#ef4444")
    DECLARE_QGC_COLOR(colorGrey,            "#808080", "#808080", "#bfbfbf", "#bfbfbf")
    DECLARE_QGC_COLOR(colorBlue,            "#0284c7", "#0284c7", "#38bdf8", "#38bdf8")
    DECLARE_QGC_COLOR(alertBackground,      "#eecc44", "#eecc44", "#eecc44", "#eecc44")
    DECLARE_QGC_COLOR(alertBorder,          "#808080", "#808080", "#808080", "#808080")
    DECLARE_QGC_COLOR(alertText,            "#000000", "#000000", "#000000", "#000000")
    DECLARE_QGC_COLOR(missionItemEditor,    "#585858", "#ede9fe", "#585858", "#2a1b45")
    DECLARE_QGC_COLOR(toolStripHoverColor,  "#585858", "#c4b5fd", "#585858", "#2a1b45")
    DECLARE_QGC_COLOR(toolbarBackground,    "#00ffffff", "#00ffffff", "#00222222", "#00222222")
    DECLARE_QGC_COLOR(modifiedParamValue,   "#bf7539", "#bf7539", "#f59e0b", "#f59e0b")

    // Colors not affecting by theming
    //                                                      Disabled     Enabled
    DECLARE_QGC_NONTHEMED_COLOR(brandPrimary,               "#8552f0", "#8552f0")
    DECLARE_QGC_NONTHEMED_COLOR(brandAccent,                "#c026d3", "#c026d3")
    DECLARE_QGC_NONTHEMED_COLOR(toolStripFGColor,           "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(photoCaptureButtonColor,    "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(videoCaptureButtonColor,    "#f89a9e", "#f32836")

    // Colors not affecting by theming or enable/disable
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderLight,          "#ffffff")
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderDark,           "#000000")
    DECLARE_QGC_SINGLE_COLOR(mapMissionTrajectory,          "#ffa000")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonInterior,         "green")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonTerrainCollision, "red")
    // Badge fills sized for indicatorText (white) at >= 4.5:1 contrast in either theme
    DECLARE_QGC_SINGLE_COLOR(errorIndicator,                "#c62828")
    DECLARE_QGC_SINGLE_COLOR(warningIndicator,              "#b45309")
    DECLARE_QGC_SINGLE_COLOR(successIndicator,              "#2e7d32")
    DECLARE_QGC_SINGLE_COLOR(indicatorText,                 "#ffffff")
    // clang-format on
}

void QGCPalette::setColorGroupEnabled(bool enabled)
{
    _colorGroupEnabled = enabled;
    emit paletteChanged();
}

void QGCPalette::setGlobalTheme(Theme newTheme)
{
    // Mobile build does not have themes
    if (_theme != newTheme) {
        _theme = newTheme;
        _signalPaletteChangeToAll();
    }
}

void QGCPalette::_signalPaletteChangeToAll()
{
    // Notify all objects of the new theme
    for (QGCPalette *palette : std::as_const(_paletteObjects)) {
        palette->_signalPaletteChanged();
    }
}

void QGCPalette::_signalPaletteChanged()
{
    emit paletteChanged();
}
