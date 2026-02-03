import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    readonly property var pluginCore: pluginApi ? pluginApi.mainInstance : null
    readonly property var geometryPlaceholder: panelContainer

    property real contentPreferredWidth: 550 * Style.uiScaleRatio
    property real contentPreferredHeight: 750 * Style.uiScaleRatio

    readonly property bool allowAttach: true

    property var pendingChanges: ({
        positions: {},
        scales: {},
        modes: {},
        transforms: {}
    })

    readonly property bool hasPendingChanges: {
        if (!pendingChanges) return false;
        return Object.keys(pendingChanges.positions || {}).length > 0 ||
               Object.keys(pendingChanges.scales || {}).length > 0 ||
               Object.keys(pendingChanges.modes || {}).length > 0 ||
               Object.keys(pendingChanges.transforms || {}).length > 0;
    }

    readonly property var outputNames: (pluginCore && pluginCore.outputs) ? Object.keys(pluginCore.outputs) : []

    property bool snapToGrid: true
    property bool snapToDisplays: true
    readonly property int gridSize: 320
    readonly property int snapThreshold: 360

    anchors.fill: parent

    Component.onCompleted: {
        if (pluginCore) pluginCore.refresh();
    }

    function setPendingChange(category, outputName, value) {
        let updated = JSON.parse(JSON.stringify(pendingChanges));
        updated[category][outputName] = value;
        pendingChanges = updated;
    }

    function getPendingOrDefault(category, outputName, defaultValue) {
        if (pendingChanges && pendingChanges[category] && pendingChanges[category][outputName] !== undefined) {
            return pendingChanges[category][outputName];
        }
        return defaultValue;
    }

    function applyChanges() {
        if (!pluginCore) return;

        Object.keys(pendingChanges.positions || {}).forEach(name => {
            const pos = pendingChanges.positions[name];
            pluginCore.setPosition(name, pos.x, pos.y);
        });

        Object.keys(pendingChanges.scales || {}).forEach(name => {
            pluginCore.setScale(name, pendingChanges.scales[name]);
        });

        Object.keys(pendingChanges.modes || {}).forEach(name => {
            const mode = pendingChanges.modes[name];
            pluginCore.setMode(name, mode.width, mode.height, mode.refresh_rate);
        });

        Object.keys(pendingChanges.transforms || {}).forEach(name => {
            pluginCore.setTransform(name, pendingChanges.transforms[name]);
        });

        discardChanges();
    }

    function discardChanges() {
        pendingChanges = { positions: {}, scales: {}, modes: {}, transforms: {} };
        if (pluginCore) pluginCore.refresh();
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginM
            }
            spacing: Style.marginM

            RowLayout {
                spacing: Style.marginS

                NText {
                    text: pluginApi ? pluginApi.tr("panel.display-configuration") : "Display Configuration"
                    pointSize: Style.fontSizeL
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                }

                NIconButton {
                    icon: "refresh"
                    onClicked: {
                        root.discardChanges();
                        layoutPreview.fitToContent();
                    }
                }
            }

            LayoutPreview {
                id: layoutPreview
                Layout.fillWidth: true
                Layout.preferredHeight: 280 * Style.uiScaleRatio

                outputNames: root.outputNames
                pluginCore: root.pluginCore
                pendingPositions: root.pendingChanges ? root.pendingChanges.positions : ({})
                snapToGrid: root.snapToGrid
                snapToDisplays: root.snapToDisplays
                gridSize: root.gridSize

                onPositionChanged: function(outputName, snappedX, snappedY) {
                    // Update pending changes with the snapped position
                    root.setPendingChange("positions", outputName, { x: snappedX, y: snappedY });
                }
            }

            Row {
                Layout.alignment: Qt.AlignRight
                spacing: Style.marginXS

                NIconButton {
                    icon: "grid-3x3"
                    opacity: root.snapToGrid ? 1.0 : 0.4
                    onClicked: root.snapToGrid = !root.snapToGrid
                    tooltipText: "Grid snap"
                }

                NIconButton {
                    icon: "layout-dashboard"
                    opacity: root.snapToDisplays ? 1.0 : 0.4
                    onClicked: root.snapToDisplays = !root.snapToDisplays
                    tooltipText: "Display snap"
                }

                NIconButton {
                    icon: "maximize"
                    onClicked: layoutPreview.fitToContent()
                    tooltipText: "Reset view"
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: parent.width
                    spacing: Style.marginS

                    Repeater {
                        model: root.outputNames

                        OutputSettingsCard {
                            Layout.fillWidth: true
                            outputName: modelData
                            outputData: pluginCore ? pluginCore.outputs[modelData] : null
                            pendingChanges: root.pendingChanges

                            onOutputScaleChanged: function(value) { root.setPendingChange("scales", modelData, value); }
                            onOutputTransformChanged: function(value) { root.setPendingChange("transforms", modelData, value); }
                            onOutputModeChanged: function(mode) { root.setPendingChange("modes", modelData, mode); }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.hasPendingChanges
                spacing: Style.marginS

                NButton {
                    Layout.fillWidth: true
                    text: pluginApi ? pluginApi.tr("panel.apply") : "Apply"
                    icon: "check"
                    backgroundColor: Color.mPrimary
                    textColor: Color.mOnPrimary
                    onClicked: root.applyChanges()
                }

                NButton {
                    text: pluginApi ? pluginApi.tr("panel.discard") : "Discard"
                    icon: "x"
                    onClicked: root.discardChanges()
                }
            }
        }
    }

    component LayoutPreview: Rectangle {
        id: preview

        property var outputNames: []
        property var pluginCore: null
        property var pendingPositions: ({})
        property bool snapToGrid: true
        property bool snapToDisplays: true
        property int gridSize: 320
        readonly property int snapThreshold: 360

        property var localSnappedPositions: ({})
        property int localSnappedVersion: 0

        property var dragPositions: ({})
        property int dragPositionsVersion: 0

        signal positionChanged(string outputName, real snappedX, real snappedY)

        onPendingPositionsChanged: {
            localSnappedPositions = JSON.parse(JSON.stringify(pendingPositions));
            localSnappedVersion++;
        }

        function updateDragPosition(outputName, x, y) {
            var updated = JSON.parse(JSON.stringify(dragPositions));
            updated[outputName] = { x: x, y: y };
            dragPositions = updated;
            dragPositionsVersion++;
        }

        function clearDragPosition(outputName) {
            var updated = JSON.parse(JSON.stringify(dragPositions));
            delete updated[outputName];
            dragPositions = updated;
            dragPositionsVersion++;
        }

        function getOutputPosition(outputName) {
            if (localSnappedPositions && localSnappedPositions[outputName]) {
                return Qt.point(localSnappedPositions[outputName].x, localSnappedPositions[outputName].y);
            }
            var out = pluginCore ? pluginCore.outputs[outputName] : null;
            if (!out || !out.logical) return Qt.point(0, 0);
            return Qt.point(out.logical.x, out.logical.y);
        }

        function getOutputSize(outputName) {
            var out = pluginCore ? pluginCore.outputs[outputName] : null;
            if (!out || !out.logical) return Qt.size(100, 100);
            return Qt.size(out.logical.width, out.logical.height);
        }

        function calculateSnap(outputName, rawX, rawY) {
            var scale = 1.0;

            var mySize = getOutputSize(outputName);
            var resultX = rawX;
            var resultY = rawY;

            var snapCandidatesX = [];
            var snapCandidatesY = [];

            if (snapToDisplays) {
                for (var i = 0; i < outputNames.length; i++) {
                    var otherName = outputNames[i];
                    if (otherName === outputName) continue;

                    var otherPos = getOutputPosition(otherName);
                    var otherSize = getOutputSize(otherName);

                    snapCandidatesX.push({ target: otherPos.x + otherSize.width, source: rawX, priority: 1 });
                    snapCandidatesX.push({ target: otherPos.x - mySize.width, source: rawX, priority: 1 });
                    snapCandidatesX.push({ target: otherPos.x, source: rawX, priority: 1 });
                    snapCandidatesX.push({ target: otherPos.x + otherSize.width - mySize.width, source: rawX, priority: 1 });

                    snapCandidatesY.push({ target: otherPos.y + otherSize.height, source: rawY, priority: 1 });
                    snapCandidatesY.push({ target: otherPos.y - mySize.height, source: rawY, priority: 1 });
                    snapCandidatesY.push({ target: otherPos.y, source: rawY, priority: 1 });
                    snapCandidatesY.push({ target: otherPos.y + otherSize.height - mySize.height, source: rawY, priority: 1 });

                    var otherCenterX = otherPos.x + otherSize.width / 2;
                    var myHalfWidth = mySize.width / 2;
                    snapCandidatesX.push({ target: otherCenterX - myHalfWidth, source: rawX, priority: 2 });

                    var otherCenterY = otherPos.y + otherSize.height / 2;
                    var myHalfHeight = mySize.height / 2;
                    snapCandidatesY.push({ target: otherCenterY - myHalfHeight, source: rawY, priority: 2 });
                }
            }

            snapCandidatesX.push({ target: 0, source: rawX, priority: 2 });
            snapCandidatesY.push({ target: 0, source: rawY, priority: 2 });

            if (snapToGrid) {
                var gridSnapX = Math.round(rawX / gridSize) * gridSize;
                var gridSnapY = Math.round(rawY / gridSize) * gridSize;

                snapCandidatesX.push({ target: gridSnapX, source: rawX, priority: 3 });
                snapCandidatesY.push({ target: gridSnapY, source: rawY, priority: 3 });

                var gridSnapRight = Math.round((rawX + mySize.width) / gridSize) * gridSize - mySize.width;
                var gridSnapBottom = Math.round((rawY + mySize.height) / gridSize) * gridSize - mySize.height;
                
                snapCandidatesX.push({ target: gridSnapRight, source: rawX, priority: 3 });
                snapCandidatesY.push({ target: gridSnapBottom, source: rawY, priority: 3 });
            }

            var bestX = findBestSnap(snapCandidatesX, snapThreshold);
            if (bestX) resultX = bestX.target;

            var bestY = findBestSnap(snapCandidatesY, snapThreshold);
            if (bestY) resultY = bestY.target;

            resultX = Math.max(0, resultX);
            resultY = Math.max(0, resultY);

            return { x: resultX, y: resultY };
        }

        function findBestSnap(candidates, threshold) {
            var best = null;
            var bestDist = threshold;

            for (var i = 0; i < candidates.length; i++) {
                var c = candidates[i];
                var dist = Math.abs(c.source - c.target);
                if (dist >= threshold) continue;

                if (best === null) {
                    best = c;
                    bestDist = dist;
                } else {
                    var distDiff = Math.abs(dist - bestDist);
                    var isSimilarDistance = distDiff < (threshold * 0.2);

                    if (dist < bestDist) {
                        if (isSimilarDistance && best.priority < c.priority) {
                            // Keep current best
                        } else {
                            best = c;
                            bestDist = dist;
                        }
                    } else if (isSimilarDistance && c.priority < best.priority) {
                        best = c;
                        bestDist = dist;
                    }
                }
            }
            return best;
        }

        function applySnapAndNotify(outputName, rawX, rawY) {
            var snapResult = calculateSnap(outputName, rawX, rawY);

            var updated = JSON.parse(JSON.stringify(localSnappedPositions));
            updated[outputName] = { x: snapResult.x, y: snapResult.y };
            localSnappedPositions = updated;
            localSnappedVersion++;

            positionChanged(outputName, snapResult.x, snapResult.y);
        }

        color: Color.mSurfaceVariant
        radius: Style.radiusM
        clip: true

        property real viewScale: 1.0
        property real viewPanX: 0
        property real viewPanY: 0

        readonly property real padding: 40

        function computeBounds() {
            if (!pluginCore || !pluginCore.outputs || outputNames.length === 0) {
                return Qt.rect(0, 0, 100, 100);
            }

            var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

            for (var i = 0; i < outputNames.length; i++) {
                var name = outputNames[i];
                var out = pluginCore.outputs[name];
                if (!out || !out.logical) continue;

                var pos = localSnappedPositions[name] || out.logical;
                minX = Math.min(minX, pos.x);
                minY = Math.min(minY, pos.y);
                maxX = Math.max(maxX, pos.x + out.logical.width);
                maxY = Math.max(maxY, pos.y + out.logical.height);
            }

            if (minX === Infinity) return Qt.rect(0, 0, 100, 100);
            return Qt.rect(minX, minY, Math.max(1, maxX - minX), Math.max(1, maxY - minY));
        }

        function fitToContent() {
            var bounds = computeBounds();

            if (bounds.width <= 0 || bounds.height <= 0) {
                 bounds = Qt.rect(0, 0, 1920, 1080);
            }

            var availableWidth = Math.max(100, width - padding * 2);
            var availableHeight = Math.max(100, height - padding * 2);

            var scaleX = availableWidth / bounds.width;
            var scaleY = availableHeight / bounds.height;

            var fitScale = Math.min(scaleX, scaleY);
            fitScale = Math.max(0.05, Math.min(fitScale, 5.0));

            viewScale = 1.0;

            var boundsCenterX = bounds.x + bounds.width / 2;
            var boundsCenterY = bounds.y + bounds.height / 2;

            var viewCenterX = width / 2;
            var viewCenterY = height / 2;

            var currentAutoScale = Math.min(availableWidth / bounds.width, availableHeight / bounds.height);
            var effectiveScale = currentAutoScale * viewScale;

            viewPanX = viewCenterX - (boundsCenterX * effectiveScale);
            viewPanY = viewCenterY - (boundsCenterY * effectiveScale);
        }

        readonly property real autoScale: {
            var bounds = computeBounds();
            return Math.min(
                (width - padding * 2) / bounds.width,
                (height - padding * 2) / bounds.height
            );
        }

        readonly property real totalScale: autoScale * viewScale

        onWidthChanged: fitToContent()
        onHeightChanged: fitToContent()

        Connections {
            target: preview.pluginCore
            function onOutputsChanged() { preview.fitToContent(); }
        }

        Canvas {
            anchors.fill: parent
            opacity: 0.08
            visible: preview.snapToGrid

            property real scale: preview.totalScale
            property real panX: preview.viewPanX
            property real panY: preview.viewPanY
            property int gridSize: preview.gridSize

            onPanXChanged: requestPaint()
            onPanYChanged: requestPaint()
            onScaleChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = Color.mOnSurfaceVariant;
                ctx.lineWidth = 1;
                ctx.globalAlpha = 0.5;

                var step = gridSize * scale;

                var originScreenX = panX;
                var offsetX = originScreenX % step;
                var startX = offsetX;
                while (startX > 0) startX -= step;
                for (var x = startX; x < width; x += step) {
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                }

                var originScreenY = panY;
                var offsetY = originScreenY % step;
                var startY = offsetY;
                while (startY > 0) startY -= step;
                for (var y = startY; y < height; y += step) {
                    ctx.beginPath();
                    ctx.moveTo(0, y);
                    ctx.lineTo(width, y);
                    ctx.stroke();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            hoverEnabled: true

            property point lastPos

            onPressed: function(mouse) {
                lastPos = Qt.point(mouse.x, mouse.y);
            }

            onPositionChanged: function(mouse) {
                if (pressed) {
                    preview.viewPanX += mouse.x - lastPos.x;
                    preview.viewPanY += mouse.y - lastPos.y;
                    lastPos = Qt.point(mouse.x, mouse.y);
                }
            }

            onWheel: function(wheel) {
                var zoomFactor = wheel.angleDelta.y > 0 ? 1.1 : 1 / 1.1;
                var oldScale = preview.viewScale;
                var newScale = Math.max(0.1, Math.min(oldScale * zoomFactor, 20.0));

                if (newScale !== oldScale) {
                    var zoom = newScale / oldScale;
                    preview.viewPanX = wheel.x - (wheel.x - preview.viewPanX) * zoom;
                    preview.viewPanY = wheel.y - (wheel.y - preview.viewPanY) * zoom;
                    preview.viewScale = newScale;
                }
            }
        }

        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom; margins: Style.marginS }
            width: zoomLabel.width + Style.marginS * 2
            height: 20
            radius: Style.radiusS
            color: Color.mSurface
            opacity: 0.9
            z: 10

            NText {
                id: zoomLabel
                anchors.centerIn: parent
                text: Math.round(preview.totalScale * 100) + "%"
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeXS
            }
        }

        Item {
            id: displayContainer
            x: preview.viewPanX
            y: preview.viewPanY
            scale: preview.totalScale
            transformOrigin: Item.TopLeft

            Component.onCompleted: preview.fitToContent()

            Repeater {
                model: preview.outputNames

                Rectangle {
                    id: displayRect

                    property string outputName: modelData
                    property var outputData: preview.pluginCore ? preview.pluginCore.outputs[outputName] : null
                    property bool isDragging: dragHandler.active

                    property real logicalWidth: outputData && outputData.logical ? outputData.logical.width : 100
                    property real logicalHeight: outputData && outputData.logical ? outputData.logical.height : 100
                    property real logicalX: outputData && outputData.logical ? outputData.logical.x : 0
                    property real logicalY: outputData && outputData.logical ? outputData.logical.y : 0

                    width: logicalWidth
                    height: logicalHeight

                    x: {
                        void(preview.dragPositionsVersion);
                        void(preview.localSnappedVersion);

                        if (preview.dragPositions[outputName]) {
                            return preview.dragPositions[outputName].x;
                        }
                        if (preview.localSnappedPositions[outputName]) {
                            return preview.localSnappedPositions[outputName].x;
                        }
                        return logicalX;
                    }

                    y: {
                        void(preview.dragPositionsVersion);
                        void(preview.localSnappedVersion);

                        if (preview.dragPositions[outputName]) {
                            return preview.dragPositions[outputName].y;
                        }
                        if (preview.localSnappedPositions[outputName]) {
                            return preview.localSnappedPositions[outputName].y;
                        }
                        return logicalY;
                    }

                    color: {
                        void(preview.localSnappedVersion);
                        return (isDragging || preview.localSnappedPositions[outputName]) ? Qt.alpha(Color.mTertiary, 0.3) : Qt.alpha(Color.mPrimary, 0.25);
                    }
                    border.color: {
                        void(preview.localSnappedVersion);
                        return (isDragging || preview.localSnappedPositions[outputName]) ? Color.mTertiary : Color.mPrimary;
                    }
                    border.width: 1
                    radius: 2
                    opacity: isDragging ? 0.9 : 1.0

                    Behavior on opacity { NumberAnimation { duration: 100 } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        scale: 1.0 / preview.totalScale

                        NText {
                            text: displayRect.outputName
                            font.weight: Font.Bold
                            pointSize: Style.fontSizeM
                            color: Color.mOnSurface
                            Layout.alignment: Qt.AlignHCenter
                        }

                        NText {
                            text: Math.round(displayRect.x) + ", " + Math.round(displayRect.y)
                            pointSize: Style.fontSizeS
                            color: Color.mOnSurfaceVariant
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: null
                        dragThreshold: 10

                        onTranslationChanged: {
                            if (!displayRect.outputData || !displayRect.outputData.logical) return;

                            var deltaX = translation.x / preview.totalScale;
                            var deltaY = translation.y / preview.totalScale;

                            var basePos = preview.localSnappedPositions[outputName] || displayRect.outputData.logical;

                            var rawX = basePos.x + deltaX;
                            var rawY = basePos.y + deltaY;

                            preview.updateDragPosition(outputName, rawX, rawY);
                        }

                        onActiveChanged: {
                            if (!active) {
                                var dragPos = preview.dragPositions[outputName];

                                if (dragPos) {
                                    var snapResult = preview.calculateSnap(outputName, dragPos.x, dragPos.y);

                                    preview.applySnapAndNotify(outputName, dragPos.x, dragPos.y); // applySnapAndNotify re-calculates snap internally
                                }
                                preview.clearDragPosition(outputName);
                            }
                        }
                    }
                }
            }
        }
    }

    component OutputSettingsCard: Rectangle {
        id: card

        property string outputName: ""
        property var outputData: null
        property var pendingChanges: ({})
        property bool expanded: false

        signal outputScaleChanged(real value)
        signal outputTransformChanged(string value)
        signal outputModeChanged(var mode)

        implicitHeight: cardContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        readonly property bool hasPendingChange: {
            if (!card.pendingChanges) return false;
            return !!(card.pendingChanges.positions && card.pendingChanges.positions[card.outputName]) ||
                   !!(card.pendingChanges.scales && card.pendingChanges.scales[card.outputName]) ||
                   !!(card.pendingChanges.modes && card.pendingChanges.modes[card.outputName]) ||
                    !!(card.pendingChanges.transforms && card.pendingChanges.transforms[card.outputName]);
        }

        readonly property real currentScale: card.outputData && card.outputData.logical ? card.outputData.logical.scale : 1.0
        readonly property string currentTransform: card.outputData && card.outputData.logical ? card.outputData.logical.transform.toLowerCase() : "normal"
        readonly property int currentModeIndex: card.outputData ? card.outputData.current_mode : -1
        readonly property var modes: card.outputData && card.outputData.modes ? card.outputData.modes : []

        ColumnLayout {
            id: cardContent
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Style.marginM
            }
            spacing: Style.marginS

            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Rectangle {
                    width: 4
                    height: parent.height
                    radius: 2
                    color: card.hasPendingChange ? Color.mTertiary : Color.mPrimary
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    NText {
                        text: card.outputName
                        font.weight: Font.Medium
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurface
                    }

                    NText {
                        text: {
                            if (!card.outputData || !card.outputData.logical) return "";
                            var scale = root.getPendingOrDefault("scales", card.outputName, card.currentScale);
                            return card.outputData.logical.width + "x" + card.outputData.logical.height + " @ " + scale.toFixed(1) + "x";
                        }
                        pointSize: Style.fontSizeXS
                        color: Color.mOnSurfaceVariant
                    }
                }

                NIconButton {
                    icon: card.expanded ? "chevron-up" : "chevron-down"
                    onClicked: card.expanded = !card.expanded
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: card.expanded && card.outputData

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                        text: pluginApi ? pluginApi.tr("panel.scale") : "Scale"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        Layout.preferredWidth: 60
                    }

                    NSlider {
                        Layout.fillWidth: true
                        from: 0.5
                        to: 2.5
                        stepSize: 0.1
                        value: root.getPendingOrDefault("scales", card.outputName, card.currentScale)
                        onMoved: card.outputScaleChanged(parseFloat(value.toFixed(1)))
                    }

                    Rectangle {
                        width: 36
                        height: 20
                        radius: Style.radiusS
                        color: Color.mPrimaryContainer || "transparent"

                        NText {
                            anchors.centerIn: parent
                            text: root.getPendingOrDefault("scales", card.outputName, card.currentScale).toFixed(1)
                            color: Color.mOnPrimaryContainer || Color.mOnSurface
                            pointSize: Style.fontSizeXS
                            font.weight: Font.Medium
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginS

                    NText {
                        text: pluginApi ? pluginApi.tr("panel.rotate") : "Rotate"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                        Layout.preferredWidth: 60
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { value: "normal", label: "0" },
                                { value: "90", label: "90" },
                                { value: "180", label: "180" },
                                { value: "270", label: "270" }
                            ]

                            TransformButton {
                                property var transformData: modelData
                                btnValue: transformData ? transformData.value : ""
                                label: transformData ? (transformData.label + "\u00B0") : ""
                                isActive: {
                                    if (!transformData) return false;
                                    var pending = root.getPendingOrDefault("transforms", card.outputName, undefined);
                                    return pending === transformData.value || (pending === undefined && card.currentTransform === transformData.value);
                                }
                                onClicked: if (transformData) card.outputTransformChanged(transformData.value)
                            }
                        }

                        Rectangle { width: 1; height: 24; color: Color.mOutline }

                        Repeater {
                            model: [
                                { value: "flipped", label: "H" },
                                { value: "flipped-180", label: "V" }
                            ]

                            TransformButton {
                                property var transformData: modelData
                                btnValue: transformData ? transformData.value : ""
                                label: transformData ? transformData.label : ""
                                width: 32
                                isActive: {
                                    if (!transformData) return false;
                                    var pending = root.getPendingOrDefault("transforms", card.outputName, undefined);
                                    return pending === transformData.value || (pending === undefined && card.currentTransform === transformData.value);
                                }
                                onClicked: if (transformData) card.outputTransformChanged(transformData.value)
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    NText {
                        text: pluginApi ? pluginApi.tr("panel.mode") : "Mode"
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: card.modes

                            Rectangle {
                                id: modeRect
                                width: modeLabel.implicitWidth + Style.marginS * 2
                                height: 22
                                radius: Style.radiusS
                                visible: modelData !== undefined && modelData !== null

                                property var modeData: modelData || null
                                property bool isCurrent: modeData ? (index === card.currentModeIndex) : false
                                property bool isPending: {
                                    if (!modeData) return false;
                                    var pm = root.getPendingOrDefault("modes", card.outputName, null);
                                    if (!pm) return false;
                                    return pm.width === modeData.width && pm.refresh_rate === modeData.refresh_rate;
                                }
                                property bool hasPendingMode: {
                                    return root.getPendingOrDefault("modes", card.outputName, null) !== null;
                                }

                                color: modeRect.isPending ? Color.mTertiary :
                                       (modeRect.isCurrent && !modeRect.hasPendingMode ? Color.mPrimary : Color.mSurfaceVariant)

                                NText {
                                    id: modeLabel
                                    anchors.centerIn: parent
                                    text: modeRect.modeData ? (modeRect.modeData.width + "x" + modeRect.modeData.height + "@" + (modeRect.modeData.refresh_rate / 1000).toFixed(0)) : ""
                                    color: modeRect.isPending ? Color.mOnTertiary :
                                           (modeRect.isCurrent && !modeRect.hasPendingMode ? Color.mOnPrimary : Color.mOnSurface)
                                    pointSize: Style.fontSizeXS
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (modeRect.modeData) card.outputModeChanged(modeRect.modeData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component TransformButton: Rectangle {
        property string btnValue: ""
        property string label: ""
        property bool isActive: false

        signal clicked()

        width: 36
        height: 24
        radius: Style.radiusS
        color: isActive ? Color.mPrimary : Color.mSurfaceVariant

        NText {
            anchors.centerIn: parent
            text: label
            color: isActive ? Color.mOnPrimary : Color.mOnSurface
            pointSize: Style.fontSizeXS
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
