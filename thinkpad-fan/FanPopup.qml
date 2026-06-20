import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var screen: null
    
    readonly property var mainWidget: pluginApi?.mainInstance || null

    property real contentPreferredWidth: 260 * Style.uiScaleRatio
    property real contentPreferredHeight: 180 * Style.uiScaleRatio
    
    readonly property var geometryPlaceholder: mainLayout
    readonly property bool allowAttach: true

    anchors.fill: parent

    ColumnLayout {
        id: mainLayout
        anchors.centerIn: parent
        spacing: Style.marginM

        // ===== Grid controls override =====
        Rectangle {
            id: controlCapsule
            Layout.preferredWidth: root.contentPreferredWidth - (Style.marginM * 2)
            Layout.preferredHeight: 140 * Style.uiScaleRatio
            color: Color.mSurfaceVariant
            radius: Style.radiusM
            border.color: Style.capsuleBorderColor
            border.width: Style.capsuleBorderWidth

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginS

                NText {
                    text: pluginApi?.tr("popup.title")
                    font.weight: Font.Bold
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    Layout.alignment: Qt.AlignHCenter
                }

                GridLayout {
                    columns: 4
                    rowSpacing: Style.marginS
                    columnSpacing: Style.marginS
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Automatic & disengaged
                    SelectorButton { text: pluginApi?.tr("popup.auto"); level: "auto"; Layout.columnSpan: 2; Layout.fillWidth: true }
                    SelectorButton { text: pluginApi?.tr("popup.full-out"); level: "disengaged"; Layout.columnSpan: 2; Layout.fillWidth: true }

                    // Numeric steps
                    SelectorButton { text: pluginApi?.tr("popup.level-0"); level: "0" }
                    SelectorButton { text: pluginApi?.tr("popup.level-1"); level: "1" }
                    SelectorButton { text: pluginApi?.tr("popup.level-2"); level: "2" }
                    SelectorButton { text: pluginApi?.tr("popup.level-3"); level: "3" }
                    SelectorButton { text: pluginApi?.tr("popup.level-4"); level: "4" }
                    SelectorButton { text: pluginApi?.tr("popup.level-5"); level: "5" }
                    SelectorButton { text: pluginApi?.tr("popup.level-6"); level: "6" }
                    SelectorButton { text: pluginApi?.tr("popup.level-7"); level: "7" }
                }
            }
        }
    }

    component SelectorButton: MouseArea {
        property string text: ""
        property string level: ""
        
        readonly property bool isSelected: root.mainWidget?.fanLevel === level
       
        implicitWidth: 52 * Style.uiScaleRatio
        implicitHeight: 28 * Style.uiScaleRatio
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        
        onClicked: {
            if (root.mainWidget) {
                root.mainWidget.setFanSpeed(level);
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Style.radiusS
            color: parent.isSelected
                ? (parent.level === "0" ? "#cc241d" : Color.mPrimary)
                : Color.mSurface
            opacity: parent.isSelected ? 1.0 : (parent.containsMouse ? 0.85 : 0.5)
        }

        NText {
            anchors.centerIn: parent
            text: parent.text
            font.weight: parent.isSelected ? Font.Bold : Font.Normal
            pointSize: Style.fontSizeS
            color: parent.isSelected ? Color.mOnPrimary : Color.mOnSurface
        }
    }
}
