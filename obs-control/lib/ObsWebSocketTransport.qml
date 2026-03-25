import QtQuick
import QtWebSockets
import "Hash.js" as Hash

Item {
  id: root

  readonly property int handshakeTimeoutMs: 1500
  readonly property int helloOpCode: 0
  readonly property int identifyOpCode: 1
  readonly property int identifiedOpCode: 2
  readonly property int requestOpCode: 6
  readonly property int requestResponseOpCode: 7
  readonly property int rpcVersion: 1
  readonly property int noEventSubscriptions: 0

  property url url: ""
  property string password: ""
  property bool identified: false
  property int nextRequestId: 1
  property var pendingRequests: ({})
  property var queuedRequests: []

  readonly property bool connected: socket.status === WebSocket.Open && identified

  function disconnectFromServer() {
    handshakeTimeout.stop()
    identified = false
    socket.active = false
  }

  function request(type, requestData, onSuccess, onFailure) {
    const requestId = String(nextRequestId)
    nextRequestId += 1

    pendingRequests[requestId] = {
      onSuccess: onSuccess,
      onFailure: onFailure,
    }

    queuedRequests.push({
      requestType: type,
      requestId: requestId,
      requestData: requestData ?? ({}),
    })

    ensureConnected()
    flushQueuedRequests()
  }

  function ensureConnected() {
    if (socket.status === WebSocket.Connecting || socket.status === WebSocket.Open) {
      return
    }

    identified = false
    socket.url = url
    socket.active = true
    handshakeTimeout.restart()
  }

  function flushQueuedRequests() {
    if (!connected) {
      return
    }

    while (queuedRequests.length > 0) {
      const request = queuedRequests.shift()
      socket.sendTextMessage(JSON.stringify({
        op: requestOpCode,
        d: {
          requestType: request.requestType,
          requestId: request.requestId,
          requestData: request.requestData,
        },
      }))
    }
  }

  function resolveRequest(requestId, responseData) {
    const entry = pendingRequests[requestId]
    if (!entry) {
      return
    }

    delete pendingRequests[requestId]

    if (entry.onSuccess) {
      entry.onSuccess(responseData ?? ({}))
    }
  }

  function rejectRequest(requestId, message) {
    const entry = pendingRequests[requestId]
    if (!entry) {
      return
    }

    delete pendingRequests[requestId]

    if (entry.onFailure) {
      entry.onFailure(message)
    }
  }

  function rejectAll(message) {
    const pending = pendingRequests
    pendingRequests = ({})
    queuedRequests = []

    for (const requestId in pending) {
      const entry = pending[requestId]
      if (entry.onFailure) {
        entry.onFailure(message)
      }
    }
  }

  function hasPendingRequests() {
    if (queuedRequests.length > 0) {
      return true
    }

    for (const requestId in pendingRequests) {
      return true
    }

    return false
  }

  function handleHello(payload) {
    const identify = {
      rpcVersion: rpcVersion,
      eventSubscriptions: noEventSubscriptions,
    }

    const auth = payload?.authentication
    if (auth) {
      const secret = Hash.sha256Base64(`${password}${auth.salt}`)
      identify.authentication = Hash.sha256Base64(`${secret}${auth.challenge}`)
    }

    socket.sendTextMessage(JSON.stringify({
      op: identifyOpCode,
      d: identify,
    }))
  }

  function handleResponse(payload) {
    const requestId = payload?.requestId
    if (!requestId) {
      return
    }

    if (payload?.requestStatus?.result) {
      resolveRequest(requestId, payload.responseData)
      return
    }

    rejectRequest(requestId, payload?.requestStatus?.comment || "OBS request failed.")
  }

  Timer {
    id: handshakeTimeout

    interval: root.handshakeTimeoutMs
    running: false
    repeat: false

    onTriggered: {
      const message = "Timed out connecting to OBS websocket."
      root.rejectAll(message)
      root.disconnectFromServer()
    }
  }

  WebSocket {
    id: socket

    active: false

    onStatusChanged: {
      if (status !== WebSocket.Closed && status !== WebSocket.Error) {
        return
      }

      const hadPendingRequests = root.hasPendingRequests()
      const message = errorString || (status === WebSocket.Error
                                      ? "Failed to connect to OBS websocket."
                                      : "OBS websocket connection closed.")

      handshakeTimeout.stop()
      root.identified = false

      if (hadPendingRequests) {
        root.rejectAll(message)
      }
    }

    onTextMessageReceived: function(message) {
      let parsed

      try {
        parsed = JSON.parse(message)
      } catch (error) {
        return
      }

      if (parsed.op === root.helloOpCode) {
        root.handleHello(parsed.d)
        return
      }

      if (parsed.op === root.identifiedOpCode) {
        handshakeTimeout.stop()
        root.identified = true
        root.flushQueuedRequests()
        return
      }

      if (parsed.op === root.requestResponseOpCode) {
        root.handleResponse(parsed.d)
      }
    }
  }
}
