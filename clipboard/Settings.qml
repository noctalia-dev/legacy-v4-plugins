import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Settings page for the clipboard plugin. Rendered inside the
// Noctalia Settings dialog when the user navigates to this plugin's entry.
//
// Contracts followed:
//   - docs/specs/settings-panel.md (behavior, constraints, acceptance criteria)
//   - docs/specs/plugin-entry-point-contracts.md §Settings.qml
//     (ColumnLayout root, injected pluginApi, mandatory saveSettings())
//   - docs/specs/plugin-qml-idioms.md (two-phase save pattern,
//     null-guarding, widget library, i18n via pluginApi?.tr)
//
// Controls stacked vertically map to the keys in
// manifest.json metadata.defaultSettings:
//   maxHistorySize     — NSpinBox, 20–500, default 100
//   showImagePreviews  — NToggle, default true
//   density            — NComboBox (compact/comfortable/spacious), default "comfortable"
//
// The two-phase save pattern means edits are held in local "value*"
// properties until the user clicks Apply; saveSettings() flushes them into
// pluginApi.pluginSettings and calls pluginApi.saveSettings().
ColumnLayout {
    id: root
    spacing: Style.marginM

    // Injected by the shell after instantiation. Always null-guard every
    // access with optional chaining (?.) — per docs/specs/plugin-qml-idioms.md.
    property var pluginApi: null
    property var cfg: pluginApi?.pluginSettings || ({})
    property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

    // --- Pending state ------------------------------------------------------
    //
    // Local buffer. UI controls bind to and mutate these properties; they
    // are flushed into pluginApi.pluginSettings only when the user clicks
    // Apply. The ?? fallbacks MUST match manifest.json metadata.defaultSettings
    // exactly — drift between the two is a real bug (a plugin instance that
    // predates a defaults change falls back to the QML literal here, not
    // the manifest value).
    property int valueMaxHistorySize: cfg.maxHistorySize ?? defaults.maxHistorySize ?? 100
    property bool valueShowImagePreviews: cfg.showImagePreviews ?? defaults.showImagePreviews ?? true
    property bool valueClearHistoryOnStartup: cfg.clearHistoryOnStartup ?? defaults.clearHistoryOnStartup ?? false
    property bool valueAutoPasteOnSelect: cfg.autoPasteOnSelect ?? defaults.autoPasteOnSelect ?? false
    property int valueAutoPasteDelayMs: cfg.autoPasteDelayMs ?? defaults.autoPasteDelayMs ?? 500
    property string valueDensity: cfg.density ?? defaults.density ?? "comfortable"

    // --- Controls -----------------------------------------------------------

    // maxHistorySize — number of cliphist entries kept in the list.
    // Takes effect on the next refresh (Main.qml's refresh() reads
    // pluginSettings.maxHistorySize on every call, so no explicit signal
    // is needed — see docs/specs/settings-panel.md §Constraints).
    NSpinBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.max-history-size")
        description: pluginApi?.tr("settings.max-history-size-description")
        from: 20
        to: 500
        stepSize: 10
        value: root.valueMaxHistorySize
        onValueChanged: root.valueMaxHistorySize = value
    }

    // showImagePreviews — guards the whole image-decode path in Main.qml
    // (getImage() short-circuits when this is false — see Main.qml).
    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-image-previews")
        description: pluginApi?.tr("settings.show-image-previews-description")
        checked: root.valueShowImagePreviews
        onToggled: checked => { root.valueShowImagePreviews = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.clear-history-on-startup")
        description: pluginApi?.tr("settings.clear-history-on-startup-description")
        checked: root.valueClearHistoryOnStartup
        onToggled: checked => { root.valueClearHistoryOnStartup = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.auto-paste-on-select")
        description: pluginApi?.tr("settings.auto-paste-on-select-description")
        checked: root.valueAutoPasteOnSelect
        onToggled: checked => { root.valueAutoPasteOnSelect = checked; }
    }

    NSpinBox {
        Layout.fillWidth: true
        visible: root.valueAutoPasteOnSelect
        label: pluginApi?.tr("settings.auto-paste-delay")
        description: pluginApi?.tr("settings.auto-paste-delay-description")
        from: 200
        to: 5000
        stepSize: 100
        value: root.valueAutoPasteDelayMs
        onValueChanged: root.valueAutoPasteDelayMs = value
    }

    // density — enum of "compact" / "comfortable" / "spacious". The
    // NComboBox model uses { key, name } entries; we bind selection through
    // currentKey so the stored value is the enum string itself (matching
    // manifest.json's "comfortable" default) rather than a numeric index.
    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.density")
        description: pluginApi?.tr("settings.density-description")
        model: [
            { "key": "compact",     "name": pluginApi?.tr("settings.density-compact") },
            { "key": "comfortable", "name": pluginApi?.tr("settings.density-comfortable") },
            { "key": "spacious",    "name": pluginApi?.tr("settings.density-spacious") }
        ]
        currentKey: root.valueDensity
        onSelected: key => { root.valueDensity = key; }
    }

    // --- Save contract ------------------------------------------------------
    //
    // Called by the shell when the user clicks the global "Apply" button in
    // the Noctalia Settings dialog. Flushes pending values into
    // pluginApi.pluginSettings, then calls pluginApi.saveSettings() which
    // persists settings.json to ~/.config/noctalia/plugins/clipboard/.
    //
    // Null-guard matches the idiom used in every other entry point — if the
    // shell calls saveSettings() before injecting pluginApi (edge case on
    // rapid open/close), silently return rather than throwing.
    function saveSettings() {
        if (!pluginApi) {
            return;
        }
        pluginApi.pluginSettings.maxHistorySize = root.valueMaxHistorySize;
        pluginApi.pluginSettings.showImagePreviews = root.valueShowImagePreviews;
        pluginApi.pluginSettings.clearHistoryOnStartup = root.valueClearHistoryOnStartup;
        pluginApi.pluginSettings.autoPasteOnSelect = root.valueAutoPasteOnSelect;
        pluginApi.pluginSettings.autoPasteDelayMs = root.valueAutoPasteDelayMs;
        pluginApi.pluginSettings.density = root.valueDensity;
        pluginApi.saveSettings();
    }
}
