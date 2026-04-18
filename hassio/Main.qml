import QtQuick
import QtWebSockets
import qs.Commons

QtObject {
    id: root
    property var pluginApi: null

    signal entityUpdated(string entity_id)

    // Expose state to BarWidget and Panel via pluginApi.mainInstance
    property bool connected: false
    property bool authenticated: false
    property bool authFailed: false

    property ListModel entities: ListModel {}

    property var _entityIndex: ({})

    // True while a drop-and-retry cycle is in progress; cleared only on successful auth
    property bool isReconnecting: false

    property int _msgId: 1
    property int _initialFetchId: -1
    property var _pendingCallbacks: ({})
    property string haUrl: ""
    property string haToken: ""

    property int _reconnectAttempts: 0
    property int _reconnectBaseInterval: 5000
    property int _reconnectMaxInterval: 60000

    Component.onCompleted: _loadSettings()

    property WebSocket _socket: WebSocket {
        id: _socket

        url: {
            const base = root.haUrl;
            if (!base)
                return "";
            return base.replace(/^http/, "ws") + "/api/websocket";
        }
        active: url !== ""

        onStatusChanged: function (status) {
            if (status === WebSocket.Open) {
                Logger.i("HASS", "WebSocket connected");
                root.connected = true;
                root.authenticated = false;
            } else if (status === WebSocket.Closed) {
                Logger.w("HASS", "WebSocket closed");
                root.connected = false;
                root.authenticated = false;
                if (!root.authFailed) {
                    root.isReconnecting = true;
                    root._scheduleReconnect();
                }
            } else if (status === WebSocket.Error) {
                Logger.e("HASS", "WebSocket error");
                root.connected = false;
                root.authenticated = false;
                if (!root.authFailed) {
                    root.isReconnecting = true;
                    root._scheduleReconnect();
                }
            }
        }

        onTextMessageReceived: function (msg) {
            const data = JSON.parse(msg);

            switch (data.type) {
            case "auth_required":
                root._authenticate();
                break;
            case "auth_ok":
                Logger.i("HASS", "Authenticated");
                root.authenticated = true;
                root.isReconnecting = false;
                root._resetReconnect();
                root._fetchStates();
                root._subscribeEvents();
                break;
            case "auth_invalid":
                Logger.e("HASS", "Auth failed - check your token");
                root.authenticated = false;
                root.authFailed = true;
                root._resetReconnect();
                break;
            case "event":
                if (data.event?.event_type === "state_changed") {
                    _handleStateChange(data.event.data);
                }
                break;
            case "result":
                if (data.id === root._initialFetchId && data.success) {
                    root._populateEntities(data.result);
                }

                if (!data.success) {
                    Logger.e("HASS", "Service call failed: " + JSON.stringify(data.error));
                }

                if (root._pendingCallbacks[data.id]) {
                    const cb = root._pendingCallbacks[data.id];
                    delete root._pendingCallbacks[data.id];
                    if (data.success) {
                        const mapped = data.result.map(e => ({
                                    entity_id: e.entity_id,
                                    friendly_name: e.attributes.friendly_name ?? e.entity_id,
                                    state: e.state,
                                    domain: e.entity_id.split(".")[0]
                                }));
                        cb(mapped);
                    }
                }
                break;
            }
        }
    }

    property Timer _reconnectTimer: Timer {
        repeat: false
        onTriggered: {
            Logger.w("HASS", "Reconnect attempt " + (root._reconnectAttempts + 1));
            _socket.active = false;
            _socket.active = true;
        }
    }

    function _nextId() {
        return ++_msgId;
    }

    function _authenticate() {
        const token = haToken;
        _socket.sendTextMessage(JSON.stringify({
            type: "auth",
            access_token: token
        }));
    }

    function _fetchStates() {
        _initialFetchId = _nextId();
        _socket.sendTextMessage(JSON.stringify({
            id: _initialFetchId,
            type: "get_states"
        }));
    }

    function _subscribeEvents() {
        _socket.sendTextMessage(JSON.stringify({
            id: _nextId(),
            type: "subscribe_events",
            event_type: "state_changed"
        }));
    }

    function _populateEntities(allStates) {
        const pinned = pluginApi?.pluginSettings?.entities ?? [];

        root.entities.clear();
        root._entityIndex = {};

        for (const state of allStates) {
            if (!pinned.includes(state.entity_id))
                continue;
            const idx = root.entities.count;
            root.entities.append({
                entity_id: state.entity_id,
                friendly_name: state.attributes.friendly_name ?? state.entity_id,
                state: state.state,
                unit: state.attributes.unit_of_measurement ?? "",
                domain: state.entity_id.split(".")[0],
                brightness: state.attributes.brightness ?? -1,
                color_temp: state.attributes.color_temp_kelvin ? Math.round(1000000 / state.attributes.color_temp_kelvin) : (state.attributes.color_temp ?? -1),
                supports_brightness: _supportsColorMode(state.attributes.supported_color_modes, ["brightness", "color_temp", "hs", "xy", "rgb", "rgbw", "rgbww"]),
                supports_color_temp: _supportsColorMode(state.attributes.supported_color_modes, ["color_temp"])
            });
            root._entityIndex[state.entity_id] = idx;
        }

        Logger.i("HASS", "Entities loaded: " + root.entities.count);
    }

    function _handleStateChange(data) {
        const entity_id = data.entity_id;
        const newState = data.new_state;
        if (!newState)
            return;

        const i = root._entityIndex[entity_id];
        if (i === undefined)
            return;

        root.entities.setProperty(i, "state", newState.state);
        root.entities.setProperty(i, "unit", newState.attributes.unit_of_measurement ?? "");
        root.entities.setProperty(i, "brightness", newState.attributes.brightness ?? -1);
        root.entities.setProperty(i, "color_temp", newState.attributes.color_temp_kelvin ? Math.round(1000000 / newState.attributes.color_temp_kelvin) : (newState.attributes.color_temp ?? -1));
        root.entityUpdated(entity_id);
    }

    function callService(domain, service, entity_id) {
        const id = _nextId();
        _socket.sendTextMessage(JSON.stringify({
            id: id,
            type: "call_service",
            domain: domain,
            service: service,
            service_data: {
                entity_id: entity_id
            }
        }));
    }

    // Called from panel after user pins/unpins an entity
    function refreshEntities() {
        if (root.authenticated) {
            root._fetchStates();
        }
    }

    function getAllStates(callback) {
        const id = _nextId();
        root._pendingCallbacks[id] = callback;
        _socket.sendTextMessage(JSON.stringify({
            id: id,
            type: "get_states"
        }));
    }

    function _loadSettings() {
        const url = pluginApi?.pluginSettings?.haUrl ?? "";
        const token = pluginApi?.pluginSettings?.haToken ?? "";
        // Only reconnect if values actually changed
        if (url === root.haUrl && token === root.haToken)
            return;
        root.haUrl = url;
        root.haToken = token;
        _settingsDebounce.restart();
    }

    function reconnect() {
        Logger.i("HASS", "Manual reconnect initiated");
        root.authFailed = false;
        root.isReconnecting = false;
        root._resetReconnect();
        root.connected = false;
        root.authenticated = false;
        _socket.active = false;
        _socket.active = true;
    }

    function _scheduleReconnect() {
        const delay = Math.min(root._reconnectBaseInterval * Math.pow(2, root._reconnectAttempts), root._reconnectMaxInterval);
        root._reconnectAttempts++;
        Logger.w("HASS", "Reconnecting in " + (delay / 1000) + "s (attempt " + root._reconnectAttempts + ")");
        root._reconnectTimer.interval = delay;
        root._reconnectTimer.start();
    }

    function _resetReconnect() {
        root._reconnectAttempts = 0;
        root._reconnectTimer.stop();
    }

    function callLightService(entity_id, brightness, color_temp) {
        const id = _nextId();
        const serviceData = {
            entity_id: entity_id
        };
        if (brightness >= 0)
            serviceData.brightness = brightness;
        if (color_temp >= 0) {
            // Convert mireds to Kelvin: K = 1,000,000 / mireds
            serviceData.color_temp_kelvin = Math.round(1000000 / color_temp);
        }

        _socket.sendTextMessage(JSON.stringify({
            id: id,
            type: "call_service",
            domain: "light",
            service: "turn_on",
            service_data: serviceData
        }));
    }

    function _supportsColorMode(modes, targets) {
        if (!modes || !Array.isArray(modes))
            return false;
        return modes.some(m => targets.includes(m));
    }

    // Called from Settings.qml after the user saves
    function reloadSettings() {
        _loadSettings();
    }

    property Timer _settingsDebounce: Timer {
        interval: 300
        repeat: false
        onTriggered: {
            Logger.i("HASS", "Settings changed, reconnecting...");
            root.authFailed = false;
            root.isReconnecting = false;
            root._resetReconnect();
            _socket.active = false;
            root.connected = false;
            root.authenticated = false;
            root.entities.clear();
            root._entityIndex = {};
            _socket.active = true;
        }
    }
}
