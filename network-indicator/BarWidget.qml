import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.System

Item {
    id: root

    property var pluginApi: null

    property ShellScreen screen
    property string widgetId: ""
    property string section: ""

    // ---------- Configuration ----------

    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    property string arrowType: cfg.arrowType || defaults.arrowType || "chevron"
    property int minWidth: cfg.minWidth || defaults.minWidth || 0

    property bool useCustomColors: cfg.useCustomColors ?? defaults.useCustomColors
    property bool showNumbers: cfg.showNumbers ?? defaults.showNumbers
    property bool forceMegabytes: cfg.forceMegabytes ?? defaults.forceMegabytes

    property color colorSilent: root.useCustomColors && cfg.colorSilent || Color.mSurfaceVariant
    property color colorTx: root.useCustomColors && cfg.colorTx || Color.mSecondary
    property color colorRx: root.useCustomColors && cfg.colorRx || Color.mPrimary
    property color colorText: root.useCustomColors && cfg.colorText || Qt.alpha(Color.mOnSurfaceVariant, 0.3)

    property int byteThresholdActive: cfg.byteThresholdActive || defaults.byteThresholdActive || 1024
    property real fontSizeModifier: cfg.fontSizeModifier || defaults.fontSizeModifier || 1
    property real iconSizeModifier: cfg.iconSizeModifier || defaults.iconSizeModifier || 1
    property real spacingInbetween: cfg.spacingInbetween || defaults.spacingInbetween || 0

    property string barPosition: Settings.data.bar.position || "top"
    property string barDensity: Settings.data.bar.density || "compact"
    property bool barIsSpacious: barDensity != "mini"
    property bool barIsVertical: barPosition === "left" || barPosition === "right"

    readonly property real contentWidth: barIsVertical ? Style.capsuleHeight : Math.max(contentRow.implicitWidth, minWidth)
    readonly property real contentHeight: barIsVertical ? Math.round(contentRow.implicitHeight + Style.marginM * 2) : Style.capsuleHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    // ---------- Widget ----------

    property real txSpeed: SystemStatService.txSpeed
    property real rxSpeed: SystemStatService.rxSpeed

    Rectangle {
        id: visualCapsule
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: root.useCustomColors && cfg.colorBackground || Style.capsuleColor
        radius: Style.radiusM
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: contentRow

            anchors.centerIn: parent
            spacing: Style.marginS

            Column {
                visible: root.showNumbers && barIsSpacious && !barIsVertical

                spacing: root.spacingInbetween

                NText {
                    visible: true
                    text: convertBytes(root.txSpeed)
                    color: root.colorText
                    pointSize: Style.barFontSize * 0.75 * root.fontSizeModifier
                }

                NText {
                    visible: true
                    text: convertBytes(root.rxSpeed)
                    color: root.colorText
                    pointSize: Style.barFontSize * 0.75 * root.fontSizeModifier
                }
            }

            Column {
                spacing: -10.0 + root.spacingInbetween

                NIcon {
                    icon: arrowType + "-up"
                    color: root.txSpeed > root.byteThresholdActive ? root.colorTx : root.colorSilent
                    pointSize: Style.fontSizeL * root.iconSizeModifier
                }

                NIcon {
                    icon: arrowType + "-down"
                    color: root.rxSpeed > root.byteThresholdActive ? root.colorRx : root.colorSilent
                    pointSize: Style.fontSizeL * root.iconSizeModifier
                }
            }
        }
    }

    // ---------- Utilities ----------

    function convertBytes(bytesPerSecond) {
        const KB = 1024;
        const MB = KB * 1024;

        let value;
        let unit;

        if (bytesPerSecond < MB & !root.forceMegabytes) {
            value = bytesPerSecond / KB;
            unit = "KB";
        } else {
            value = bytesPerSecond / MB;
            unit = "MB";
        }

        const text = value.toFixed(1) + " " + unit;
        return text.padStart(10, " ");
    }
}
