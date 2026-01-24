.pragma library

var widgets = [
    {
        id: "clock",
        name: "Clock",
        component: "widgets/ClockWidget.qml",
        icon: "clock",
        defaultWidth: 200,
        defaultHeight: 100,
        description: "Simple clock widget"
    },
    {
        id: "cpu",
        name: "CPU Monitor",
        component: "widgets/CPUMonitor.qml",
        icon: "cpu",
        defaultWidth: 250,
        defaultHeight: 150,
        description: "CPU usage monitor"
    },
    {
        id: "memory",
        name: "Memory Monitor",
        component: "widgets/MemoryMonitor.qml",
        icon: "memory",
        defaultWidth: 250,
        defaultHeight: 150,
        description: "Memory usage monitor"
    },
    {
        id: "network",
        name: "Network Stats",
        component: "widgets/NetworkStats.qml",
        icon: "network",
        defaultWidth: 250,
        defaultHeight: 120,
        description: "Network statistics"
    },
    {
        id: "system",
        name: "System Info",
        component: "widgets/SystemInfo.qml",
        icon: "info",
        defaultWidth: 300,
        defaultHeight: 200,
        description: "System information"
    }
];

function getWidgetById(id) {
    for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].id === id) {
            return widgets[i];
        }
    }
    return null;
}

function getAllWidgets() {
    return widgets;
}
