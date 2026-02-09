import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Location
import qs.Services.UI
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    readonly property var mainInstance: pluginApi?.mainInstance
    readonly property var geometryPlaceholder: panelContainer
    property real contentPreferredWidth: 950 * Style.uiScaleRatio
    property real contentPreferredHeight: 700 * Style.uiScaleRatio
    property real topHeaderHeight: 60 * Style.uiScaleRatio
    readonly property bool allowAttach: mainInstance ? mainInstance.panelModeSetting === "attached" : false
    readonly property bool panelAnchorHorizontalCenter: mainInstance ? mainInstance.panelModeSetting === "centered" : false
    readonly property bool panelAnchorVerticalCenter: mainInstance ? mainInstance.panelModeSetting === "centered" : false
    anchors.fill: parent

    property real hourHeight: 50 * Style.uiScaleRatio
    property real timeColumnWidth: 65 * Style.uiScaleRatio
    property real daySpacing: 1 * Style.uiScaleRatio

    // Attempt at live syncing
    Connections {
        target: CalendarService
        enabled: root.visible
        function onEventsChanged() { 
            if (mainInstance) {
                Qt.callLater(() => {
                    mainInstance.updateEventsFromService()
                    mainInstance.calculateAllDayEventLayout()
                })
            }
        }
    }

    Component.onCompleted: mainInstance?.initializePlugin()
    onVisibleChanged: if (visible && mainInstance) {
        mainInstance.updateEventsFromService()
        mainInstance.goToToday()
        Qt.callLater(root.scrollToCurrentTime)
    }

    // Scroll to time indicator position
    function scrollToCurrentTime() {
        if (!mainInstance || !calendarFlickable) return
        var now = new Date(), today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var weekStart = new Date(mainInstance.weekStart)
        var weekEnd = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + 7)
        
        if (today >= weekStart && today < weekEnd) {
            var currentHour = now.getHours() + now.getMinutes() / 60
            var scrollPos = (currentHour * hourHeight) - (calendarFlickable.height / 2)
            var maxScroll = Math.max(0, (24 * hourHeight) - calendarFlickable.height)
            scrollAnim.targetY = Math.max(0, Math.min(scrollPos, maxScroll))
            scrollAnim.start()
        }
    }
    
    // UI
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            //Header Section
            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: topHeaderHeight
                color: Color.mSurfaceVariant
                radius: Style.radiusM

                RowLayout {
                    anchors.margins: Style.marginM
                    anchors.fill: parent
                    
                    NIcon { icon: "calendar-week"; pointSize: Style.fontSizeXXL; color: Color.mPrimary }

                    ColumnLayout {
                        Layout.fillHeight: true
                        spacing: 0
                        NText {
                            text: pluginApi.tr("panel.header")
                            font.pointSize: Style.fontSizeL; font.weight: Font.Bold; color: Color.mOnSurface
                        }
                        RowLayout {
                            spacing: Style.marginS
                            NText {
                                text: mainInstance?.monthRangeText || ""
                                font.pointSize: Style.fontSizeS; font.weight: Font.Medium; color: Color.mOnSurfaceVariant
                            }
                            Rectangle {
                                Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                color: mainInstance?.isLoading ? Color.mError : 
                                       mainInstance?.syncStatus?.includes("No") ? Color.mError : Color.mOnSurfaceVariant
                            }
                            NText {
                                text: mainInstance?.syncStatus || ""
                                font.pointSize: Style.fontSizeS; color: Color.mOnSurfaceVariant
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: Style.marginS
                        NIconButton {
                            icon: "chevron-left"
                            onClicked: { mainInstance?.navigateWeek(-7); mainInstance?.loadEvents() }
                        }
                        NIconButton {
                            icon: "calendar"; tooltipText: pluginApi.tr("panel.today")
                            onClicked: { mainInstance?.goToToday(); mainInstance?.loadEvents(); Qt.callLater(root.scrollToCurrentTime) }
                        }
                        NIconButton {
                            icon: "chevron-right"
                            onClicked: { mainInstance?.navigateWeek(7); mainInstance?.loadEvents() }
                        }
                        NIconButton {
                            icon: "refresh"; tooltipText: I18n.tr("common.refresh")
                            onClicked: mainInstance?.loadEvents()
                            enabled: mainInstance ? !mainInstance.isLoading : false
                        }
                        NIconButton {
                            icon: "close"; tooltipText: I18n.tr("common.close")
                            onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                        }
                    }
                }
            }

            // Calendar
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Color.mSurfaceVariant
                radius: Style.radiusM
                clip: true

                Column {
                    anchors.fill: parent
                    spacing: 0

                    //Day Headers
                    Rectangle {
                        id: dayHeaders
                        width: parent.width
                        height: 56
                        color: Color.mSurfaceVariant
                        radius: Style.radiusM
                        
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: root.timeColumnWidth
                            spacing: root.daySpacing
                            
                            Repeater {
                                model: 7
                                Rectangle {
                                    width: mainInstance?.dayColumnWidth
                                    height: parent.height
                                    color: "transparent"
                                    property date dayDate: mainInstance?.weekDates?.[index] || new Date()
                                    property bool isToday: {
                                        var today = new Date()
                                        return dayDate.getDate() === today.getDate() &&
                                               dayDate.getMonth() === today.getMonth() &&
                                               dayDate.getFullYear() === today.getFullYear()
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        color: Color.mSurfaceVariant
                                        border.color: isToday ? Color.mPrimary : "transparent"
                                        border.width: 2
                                        radius: Style.radiusM
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            NText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: dayDate ? I18n.locale.dayName(dayDate.getDay(), Locale.ShortFormat).toUpperCase() : ""
                                                color: isToday ? Color.mPrimary : Color.mOnSurface
                                                font.pointSize: Style.fontSizeS; font.weight: Font.Medium
                                            }
                                            NText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: dayDate ? ((dayDate.getDate() < 10 ? "0" : "") + dayDate.getDate()) : ""
                                                color: isToday ? Color.mPrimary : Color.mOnSurface
                                                font.pointSize: Style.fontSizeM; font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // All-day row
                    Rectangle {
                        id: allDayEventsSection
                        width: parent.width
                        height: mainInstance ? Math.round(mainInstance.allDaySectionHeight * Style.uiScaleRatio) : 0
                        color: Color.mSurfaceVariant
                        visible: height > 0
                        
                        Item {
                            id: allDayEventsContainer
                            anchors.fill: parent
                            anchors.leftMargin: root.timeColumnWidth
                            
                            Repeater {
                                model: 6
                                delegate: Rectangle {
                                    width: 1; height: parent.height
                                    x: (index + 1) * ((mainInstance?.dayColumnWidth) + (root.daySpacing)) - ((root.daySpacing) / 2)
                                    color: Qt.alpha(mainInstance?.lineColor || Color.mOutline, mainInstance?.dayLineOpacitySetting || 0.9)
                                }
                            }
                            
                            Repeater {
                                model: mainInstance?.allDayEventsWithLayout || []
                                delegate: Item {
                                    property var eventData: modelData
                                    x: eventData.startDay * ((mainInstance?.dayColumnWidth) + (root.daySpacing))
                                    y: eventData.lane * 25
                                    width: (eventData.spanDays * ((mainInstance?.dayColumnWidth) + (root.daySpacing))) - (root.daySpacing)
                                    height: 24
                                    
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Color.mTertiary
                                        radius: Style.radiusS
                                        NText {
                                            anchors.fill: parent; anchors.margins: 4
                                            text: eventData.title
                                            color: Color.mOnTertiary
                                            font.pointSize: Style.fontSizeXXS; font.weight: Font.Medium
                                            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            var tip = mainInstance?.getEventTooltip(eventData) || ""
                                            TooltipService.show(parent, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontFixed)
                                        }
                                        onClicked: mainInstance?.handleEventClick(eventData)
                                        onExited: TooltipService.hide()
                                    }
                                }
                            }
                        }
                    }
                    // Calendar flickable                  
                    Rectangle {
                        width: parent.width
                        height: parent.height - dayHeaders.height - (allDayEventsSection.visible ? allDayEventsSection.height : 0)
                        color: Color.mSurfaceVariant
                        radius: Style.radiusM
                        clip: true
                        
                        Flickable {
                            id: calendarFlickable
                            anchors.fill: parent
                            clip: true
                            contentHeight: 24 * (root.hourHeight)
                            boundsBehavior: Flickable.DragOverBounds

                            Component.onCompleted: {
                                calendarFlickable.forceActiveFocus()
                            }
                            
                            // Keyboard interaction
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                    var step = root.hourHeight
                                    var targetY = event.key === Qt.Key_Up ? Math.max(0, contentY - step) :
                                                 Math.min(Math.max(0, contentHeight - height), contentY + step)
                                    scrollAnim.targetY = targetY
                                    scrollAnim.start()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                    if (mainInstance) {
                                        mainInstance.navigateWeek(event.key === Qt.Key_Left ? -7 : 7)
                                        mainInstance.loadEvents()
                                    }
                                    event.accepted = true
                                }
                            }
                            
                            NumberAnimation {
                                id: scrollAnim
                                target: calendarFlickable; property: "contentY"; duration: 100
                                easing.type: Easing.OutCubic; property real targetY: 0; to: targetY
                            }

                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            Row {
                                width: parent.width
                                height: parent.height
                                
                                // Time Column
                                Column {
                                    width: root.timeColumnWidth
                                    height: parent.height
                                    Repeater {
                                        model: 23
                                        Rectangle {
                                            width: root.timeColumnWidth
                                            height: root.hourHeight
                                            color: "transparent"
                                            NText {
                                                text: {
                                                    var hour = index + 1
                                                    if (mainInstance?.use12hourFormat) {
                                                        var d = new Date(); d.setHours(hour, 0, 0, 0)
                                                        return mainInstance.formatTime(d)
                                                    }
                                                    return (hour < 10 ? "0" : "") + hour + ':00'
                                                }
                                                anchors.right: parent.right
                                                anchors.rightMargin: Style.marginS
                                                anchors.verticalCenter: parent.top
                                                anchors.verticalCenterOffset: root.hourHeight
                                                font.pointSize: Style.fontSizeXS; color: Color.mOnSurfaceVariant
                                            }
                                        }
                                    }
                                }
                                
                                // Hour Rectangles
                                Item {
                                    width: 7 * ((mainInstance?.dayColumnWidth) + (root.daySpacing))
                                    height: parent.height
                                    
                                    Row {
                                        anchors.fill: parent
                                        spacing: root.daySpacing
                                        Repeater {
                                            model: 7
                                            Column {
                                                width: mainInstance?.dayColumnWidth
                                                height: parent.height
                                                Repeater {
                                                    model: 24
                                                    Rectangle { width: parent.width; height: 1; color: Color.mSurfaceVariant }
                                                }
                                            }
                                        }
                                    }
                                    // Hour Lines
                                    Repeater {
                                        model: 24
                                        Rectangle {
                                            width: parent.width; height: 1
                                            y: index * (root.hourHeight)
                                            color: Qt.alpha(mainInstance?.lineColor || Color.mOutline, mainInstance?.hourLineOpacitySetting || 0.5)
                                        }
                                    }
                                    // Day Lines
                                    Repeater {
                                        model: 6
                                        Rectangle {
                                            width: 1; height: parent.height
                                            x: (index + 1) * ((mainInstance?.dayColumnWidth) + (root.daySpacing)) - ((root.daySpacing) / 2)
                                            color: Qt.alpha(mainInstance?.lineColor || Color.mOutline, mainInstance?.dayLineOpacitySetting || 0.9)
                                        }
                                    }
                                    
                                    // Event positioning
                                    Repeater {
                                        model: mainInstance?.eventsModel
                                        delegate: Item {
                                            property var eventData: model
                                            property int dayIndex: mainInstance?.getDisplayDayIndexForDate(model.startTime) ?? -1
                                            property real startHour: model.startTime.getHours() + model.startTime.getMinutes() / 60
                                            property real endHour: model.endTime.getHours() + model.endTime.getMinutes() / 60
                                            property real duration: Math.max(0, (model.endTime - model.startTime) / 3600000)
                                            
                                            property real exactHeight: Math.max(1, duration * (mainInstance?.hourHeight || 50) - 1)
                                            property bool isCompact: exactHeight < 40
                                            property var overlapInfo: mainInstance?.overlappingEventsData?.[index] ?? {
                                                xOffset: 0, width: (mainInstance?.dayColumnWidth) - 8, lane: 0, totalLanes: 1
                                            }
                                            property real eventWidth: overlapInfo.width - 1
                                            property real eventXOffset: overlapInfo.xOffset

                                            visible: dayIndex >= 0 && dayIndex < 7 && duration > 0
                                            width: eventWidth
                                            height: exactHeight
                                            x: dayIndex * ((mainInstance?.dayColumnWidth) + (root.daySpacing)) + eventXOffset
                                            y: startHour * (mainInstance?.hourHeight || 50)
                                            z: 100 + overlapInfo.lane
                                            
                                            Rectangle {
                                                anchors.fill: parent
                                                color: Color.mPrimary
                                                radius: Style.radiusS
                                                opacity: 0.9
                                                clip: true
                                                Rectangle {
                                                    visible: exactHeight < 5 && overlapInfo.lane > 0
                                                    anchors.fill: parent
                                                    color: "transparent"
                                                    radius: parent.radius
                                                    border.width: 1
                                                    border.color: Color.mPrimary
                                                }
                                                Loader {
                                                    anchors.fill: parent
                                                    anchors.margins: exactHeight < 10 ? 1 : Style.marginS
                                                    anchors.leftMargin: exactHeight < 10 ? 1 : Style.marginS + 3
                                                    sourceComponent: isCompact ? compactLayout : normalLayout
                                                }
                                            }
                                            
                                            Component {
                                                id: normalLayout
                                                Column {
                                                    spacing: 2
                                                    width: parent.width - 3
                                                    NText {
                                                        visible: exactHeight >= 20
                                                        text: model.title
                                                        color: Color.mOnPrimary
                                                        font.pointSize: Style.fontSizeXS; font.weight: Font.Medium
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                    NText {
                                                        visible: exactHeight >= 30
                                                        text: mainInstance?.formatTimeRangeForDisplay(model) || ""
                                                        color: Color.mOnPrimary
                                                        font.pointSize: Style.fontSizeXXS; opacity: 0.9
                                                        elide: Text.ElideRight; width: parent.width
                                                    }
                                                }
                                            }
                                            
                                            Component {
                                                id: compactLayout
                                                NText {
                                                    text: exactHeight < 15 ? model.title : 
                                                          model.title + " • " + (mainInstance?.formatTimeRangeForDisplay(model) || "")
                                                    color: Color.mOnPrimary
                                                    font.pointSize: exactHeight < 15 ? Style.fontSizeXXS : Style.fontSizeXS
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                                    width: parent.width - 3
                                                }
                                            }
                                            
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    var tip = mainInstance?.getEventTooltip(model) || ""
                                                    TooltipService.show(parent, tip, "auto", Style.tooltipDelay, Settings.data.ui.fontFixed)
                                                }
                                                onClicked: mainInstance?.handleEventClick(eventData)
                                                onExited: TooltipService.hide()
                                            }
                                        }
                                    }

                                    // Time Indicator
                                    Rectangle {
                                        property var now: new Date()
                                        property date today: new Date(now.getFullYear(), now.getMonth(), now.getDate())
                                        property date weekStartDate: mainInstance?.weekStart ?? new Date()
                                        property date weekEndDate: mainInstance ? 
                                            new Date(mainInstance.weekStart.getFullYear(), mainInstance.weekStart.getMonth(), mainInstance.weekStart.getDate() + 7) : new Date()
                                        property bool inCurrentWeek: today >= weekStartDate && today < weekEndDate
                                        property int currentDay: mainInstance?.getDayIndexForDate(now) ?? -1
                                        property real currentHour: now.getHours() + now.getMinutes() / 60
                                        
                                        visible: inCurrentWeek && currentDay >= 0
                                        width: mainInstance?.dayColumnWidth
                                        height: 2
                                        x: currentDay * ((mainInstance?.dayColumnWidth) + (root.daySpacing))
                                        y: currentHour * (root.hourHeight)
                                        color: Color.mError
                                        radius: 1
                                        z: 1000
                                        Rectangle {
                                            width: 8; height: 8; radius: 4; color: Color.mError
                                            anchors.verticalCenter: parent.verticalCenter; x: -4
                                        }
                                        Timer {
                                            interval: 60000; running: true; repeat: true
                                            onTriggered: parent.now = new Date()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}