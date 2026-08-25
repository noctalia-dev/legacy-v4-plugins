import QtQuick

// MockMain.qml — bench stand-in for Main.qml's public surface. A real
// QtObject (not a JS literal) so string-property notifications fire and
// Panel's Connections (onActiveProviderIdChanged) can be exercised.
// Data lives in the initial property values (no onCompleted race).
QtObject {
  // NOTE: object literals with an `id` key must be returned from a function
  // expression — in a property binding `id:` is parsed as the QML id keyword.
  property var providers: (function () {
    return [
      { id: "zai_1", type: "zai", apiKey: "sk-zai", label: "", planLabel: "", validUntil: "", enabled: true },
      { id: "deepseek_1", type: "deepseek", apiKey: "sk-ds", label: "", planLabel: "", validUntil: "", enabled: true }
    ];
  })()
  property var entries: (function () {
    return {
      zai_1: {
        plan: "pro", status: "ready", fetchedAt: 1,
        sections: [
          { type: "metric", key: "session", percent: 40, value: "60%", severity: "mid", detail: "60", resetAt: 1787600000000 }
        ]
      },
      deepseek_1: {
        plan: "pay-as-you-go", status: "ready", fetchedAt: 1,
        sections: [
          { type: "metric", key: "balance", percent: null, value: "110.00 CNY", severity: "mid", detail: "", resetAt: 0 }
        ]
      }
    };
  })()
  property var errors: ({})
  property var fetching: ({})
  property real now: Date.now()
  property string activeProviderId: "zai_1"
  readonly property string activeError: errors[activeProviderId] !== undefined ? errors[activeProviderId] : ""
  readonly property var activeEntry: entries[activeProviderId] !== undefined ? entries[activeProviderId] : null
  readonly property var activeProvider: (function () {
    for (var i = 0; i < providers.length; i++)
      if (providers[i].id === activeProviderId)
        return providers[i];
    return null;
  })()
  function leftPercent(e) {
    var h = headlineSection(e);
    return h && h.percent !== null && h.percent !== undefined ? 100 - h.percent : -1;
  }

  function setActive(id) {
    activeProviderId = id;
  }

  function chipFor(p) {
    return { monogram: p.type === "zai" ? "Z" : "DS", color: "#7c7cf0" };
  }

  function displayLabel(p) {
    return p.label !== "" ? p.label : p.type;
  }

  function headlineSection(e) {
    return e.sections.length > 0 ? e.sections[0] : null;
  }

  function severityColor(sev) {
    return "#7c7cf0";
  }

  function fetchProvider(p) {}
}
