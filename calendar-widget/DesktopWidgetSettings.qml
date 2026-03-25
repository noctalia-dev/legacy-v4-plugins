import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root
    implicitWidth: 400
    implicitHeight: 200

    // This is the only object reliably injected into the Settings Window
    property var pluginApi: null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
            text: pluginApi?.tr("menu.title") ?? "Calendar Settings"
            font.bold: true
            font.pointSize: Style.fontSizeM
            color: Color.mPrimary
        }

        RowLayout {
            Layout.fillWidth: true
            
            NText { 
                text: pluginApi?.tr("menu.settings") ?? "Start Week on Monday"
                Layout.fillWidth: true
                color: Color.mOnSurface
            }
            
            NButton {
                // Accessing the global plugin settings instead of widgetData
                property bool isMonday: pluginApi?.pluginSettings?.startOnMonday ?? true
                text: isMonday ? "Monday" : "Sunday"
                
                onClicked: {
                    isMonday = !isMonday;
                    
                    if (pluginApi && pluginApi.pluginSettings) {
                        // 1. Update the Global setting
                        pluginApi.pluginSettings.startOnMonday = isMonday;
                        
                        // 2. Tell Noctalia to write the change to disk
                        pluginApi.saveSettings();
                        
                        Logger.i("CalendarPlugin", "Saved to Global Settings: " + isMonday);
                    } else {
                        Logger.e("CalendarPlugin", "CRITICAL: pluginSettings is missing!");
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
}
