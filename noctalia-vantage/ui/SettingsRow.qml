import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System

Item {
    id: root

    property string baseIcon
    property string checkedIcon: ""
    readonly property string icon: root.checked ? (checkedIcon === "" ? root.baseIcon + "-filled" : checkedIcon) : baseIcon
    property string title
    property string description
    property string tooltip
    property bool checked

    signal toggled(bool checked)

    width: ListView.view.width
    height: 64 * Style.uiScaleRatio

    MouseArea {
        id: mouseArea
        hoverEnabled: true
        anchors.fill: parent

        onEntered: {
            TooltipService.show(root, root.tooltip, BarService.getTooltipDirection());
        }

        onExited: {
            TooltipService.hide();
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Style.marginM

        NIcon {
            icon: root.icon
            pointSize: Style.fontSizeXXL
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Style.marginS

            NText {
                text: root.title
                font.weight: Style.fontWeightBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            NText {
                text: root.description
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        NToggle {
            checked: root.checked
            onToggled: checked => root.toggled(checked)
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
