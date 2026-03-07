.pragma library

// Shared hover state between MPD.qml (widget) and Panel.qml.
// .pragma library makes this a singleton across the entire QML engine —
// writes in one component are immediately visible in the other.
var cursorOnWidget = false
var cursorOnPanel = false
