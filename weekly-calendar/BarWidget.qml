import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Modules.Bar.Extras
import qs.Services.UI

Item {
    id: root
    
    property QtObject pluginApi: null
    readonly property QtObject pluginCore: pluginApi?.mainInstance
    
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    
    property string tooltipContent: ""
    
    Timer {
        id: updateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateTooltip()
    }
    
    function updateTooltip() {
        if (!pluginCore || !pluginCore.eventsModel) {
            tooltipContent = "";
            return;
        }
        
        var events = pluginCore.eventsModel;
        var now = new Date();
        
        // Get start and end of today
        var todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var todayEnd = new Date(todayStart);
        todayEnd.setDate(todayEnd.getDate() + 1);
        
        var currentEv = null;
        var nextEv = null;
        var hasEventsToday = false;
        
        for (var i = 0; i < events.count; i++) {
            var event = events.get(i);
            var eventStart = event.startTime;
            var eventEnd = event.endTime;
            
            // Only consider events that occur today
            var occursToday = (eventStart >= todayStart && eventStart < todayEnd) ||
                             (eventEnd > todayStart && eventEnd <= todayEnd) ||
                             (eventStart < todayStart && eventEnd > todayEnd);
            
            if (!occursToday) {
                continue;
            }
            
            hasEventsToday = true;
            
            // Check if event is currently happening
            if (now >= eventStart && now <= eventEnd) {
                currentEv = event;
            }
            
            // Check for next event (starting later today)
            if (!nextEv && eventStart > now && eventStart < todayEnd) {
                nextEv = event;
            }
            
            if (currentEv && nextEv) break;
        }
        
        var tip = "";
        
        if (currentEv) {
            tip = pluginApi.tr("bar_widget.now") + ": " + currentEv.title + "\n" + 
                  pluginCore.formatTimeRangeForDisplay(currentEv);
            
            // If there's a current event and a next event
            if (nextEv) {
                tip += "\n\n" + pluginApi.tr("bar_widget.next") + ": " + nextEv.title + "\n" + 
                        pluginCore.formatTimeRangeForDisplay(nextEv);
            }
        }
        
        if (nextEv && !currentEv) {
            // If no current event but there's a next event today
            tip = pluginApi.tr("bar_widget.next") + ": " + nextEv.title + "\n" + 
                  pluginCore.formatTimeRangeForDisplay(nextEv);
        }
        
        // If all events have passed today
        if (!tip && hasEventsToday) {
            tip = pluginApi.tr("bar_widget.no_more_events_today");
        }
        
        tooltipContent = tip;
    }
    
    Connections {
        target: pluginCore
        function onEventsModelChanged() { updateTooltip(); }
        function onCurrentDateChanged() { updateTooltip(); }
    }
    
    implicitWidth: pill.width
    implicitHeight: pill.height

    BarPill {
        id: pill
        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        forceClose: true
        
        icon: "calendar"
        tooltipText: tooltipContent
        
        onClicked: root.pluginApi?.openPanel(root.screen)
        
        onRightClicked: {
            PanelService.showContextMenu(contextMenu, pill, root.screen);
        }
    }

    NPopupContextMenu {
        id: contextMenu
        model: [
            {
                "label": pluginApi.tr("bar_widget.settings"),
                "action": "widget-settings",
                "icon": "settings",
                "enabled": true
            }
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(root.screen);

            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi.manifest);
            }
        }
    }
}