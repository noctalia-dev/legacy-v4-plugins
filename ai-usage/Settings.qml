// Settings.qml v3 — provider CRUD:
//   list  — chip + display name + key mask + enabled toggle + edit + delete
//           (click on a row makes the provider active)
//   form  — opened only via «Add provider» / pencil; submit + cancel at the
//           bottom. In edit mode the key field starts empty (the stored key
//           is never loaded back): a new key overwrites, an empty one clears.
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "Logic.js" as Logic

ColumnLayout {
  id: root

  property var pluginApi: null

  readonly property var mainInstance: pluginApi ? pluginApi.mainInstance : null

  // provider form state (shared by add and edit)
  property bool addVisible: false
  property string editId: ""
  property string editKeyPreview: "" // mask of the stored key, never the key
  property string newType: "zai"
  property string newApiKey: ""
  property string newLabel: ""
  property string newPlanLabel: ""
  property string newValidUntil: ""

  readonly property bool editMode: editId !== ""
  readonly property bool formVisible: addVisible || editMode
  // claude logs in through the CLI's own credentials — no key involved
  readonly property bool formKeyless: Logic.PROVIDERS[newType] !== undefined
    && !!Logic.PROVIDERS[newType].keyless

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.i("AiUsage", "settings UI loaded");
  }

  function settingsObj() {
    return pluginApi ? pluginApi.pluginSettings : null;
  }

  function persist() {
    // Prefer Main.saveSettings(): it re-tightens settings.json permissions
    // after every framework write.
    if (mainInstance && mainInstance.saveSettings)
      mainInstance.saveSettings();
    else if (pluginApi && pluginApi.saveSettings)
      pluginApi.saveSettings();
    if (mainInstance) {
      // A key saved plaintext while crypto was unavailable gets encrypted
      // here instead of surviving until the next shell restart.
      if (mainInstance.migrateEncryption)
        mainInstance.migrateEncryption();
      mainInstance.loadProviders();
    }
  }

  function providerTypes() {
    var types = [];
    for (var key in Logic.PROVIDERS)
      types.push(key);
    return types;
  }

  function resetForm() {
    newType = "zai";
    newApiKey = "";
    newLabel = "";
    newPlanLabel = "";
    newValidUntil = "";
  }

  function openAdd() {
    editId = "";
    resetForm();
    addVisible = true;
  }

  // The stored key (plaintext OR enc:v1 envelope) is deliberately not seeded
  // into the form; only its Logic.keyMask preview (envelope hint = last 4).
  function openEdit(p) {
    addVisible = false;
    editId = p.id;
    editKeyPreview = p.apiKey !== "" ? Logic.keyMask(p.apiKey) : "";
    newType = p.type;
    newApiKey = "";
    newLabel = p.label;
    newPlanLabel = p.planLabel;
    newValidUntil = p.validUntil;
  }

  function cancelForm() {
    editId = "";
    editKeyPreview = "";
    addVisible = false;
    resetForm();
  }

  // storedKey is the enc:v1 envelope, or '' meaning "keep the stored one"
  // (edit mode — mergeProviderForm preserves it).
  function applySubmit(s, storedKey, f) {
    if (editMode) {
      for (var i = 0; i < s.providers.length; i++) {
        if (s.providers[i].id !== editId)
          continue;
        var merged = Logic.mergeProviderForm(s.providers[i], {
          type: newType,
          apiKey: storedKey,
          label: f.label,
          planLabel: f.planLabel,
          validUntil: f.validUntil
        });
        s.providers[i].type = merged.type;
        s.providers[i].apiKey = merged.apiKey;
        s.providers[i].label = merged.label;
        s.providers[i].planLabel = merged.planLabel;
        s.providers[i].validUntil = merged.validUntil;
        persist();
        if (mainInstance && storedKey !== "")
          mainInstance.fetchProvider(s.providers[i]);
        break;
      }
    } else {
      var id = Logic.newProviderId(newType, s.providers.map(function (p) { return p.id; }));
      s.providers.push({
        id: id,
        type: newType,
        apiKey: storedKey,
        label: f.label,
        planLabel: f.planLabel,
        validUntil: f.validUntil,
        enabled: true
      });
      s.activeProviderId = id;
      persist();
      if (mainInstance) {
        for (var j = 0; j < s.providers.length; j++) {
          if (s.providers[j].id === id)
            mainInstance.fetchProvider(s.providers[j]);
        }
      }
    }
    cancelForm();
  }

  function submitForm() {
    var s = settingsObj();
    if (!s)
      return;
    var f = Logic.normalizeProviderForm({
      apiKey: newApiKey,
      label: newLabel,
      planLabel: newPlanLabel,
      validUntil: newValidUntil
    });
    if (!editMode && f.apiKey === "" && !formKeyless)
      return;

    if (f.apiKey === "") {
      // Edit mode with an untouched key field: keep the stored envelope.
      applySubmit(s, "", f);
    } else if (mainInstance && mainInstance.encryptSecret && mainInstance.cryptoReady) {
      // New key: encrypt before it ever touches the settings file.
      mainInstance.encryptSecret(f.apiKey, function (env) {
        if (env === null) {
          Logger.e("AiUsage", "key encryption failed; provider not saved");
          return;
        }
        applySubmit(s, env, f);
      });
    } else {
      // Crypto unavailable (bench / early boot): store plaintext; the
      // startup migration encrypts it on the next shell start.
      Logger.w("AiUsage", "crypto not ready; key stored unencrypted");
      applySubmit(s, f.apiKey, f);
    }
  }

  function removeProvider(id) {
    var s = settingsObj();
    if (!s)
      return;
    var idx = -1;
    for (var i = 0; i < s.providers.length; i++) {
      if (s.providers[i].id === id)
        idx = i;
    }
    if (idx < 0)
      return;
    s.providers.splice(idx, 1);
    if (s.activeProviderId === id)
      s.activeProviderId = s.providers.length > 0 ? s.providers[0].id : "";
    if (editId === id)
      cancelForm();
    persist();
  }

  function setEnabled(id, enabled) {
    var s = settingsObj();
    if (!s)
      return;
    for (var i = 0; i < s.providers.length; i++) {
      if (s.providers[i].id === id) {
        s.providers[i].enabled = enabled;
        break;
      }
    }
    persist();
  }

  function tr(key) {
    return pluginApi ? pluginApi.tr(key) : "";
  }

  // --- refresh interval (global) ------------------------------------------

  NComboBox {
    Layout.fillWidth: true
    label: root.tr("settings.refresh.label")
    description: root.tr("settings.refresh.description")
    // NComboBox compares item.key === currentKey STRICTLY; keys must be
    // strings (currentKey is a string property) — numbers never match.
    model: [1, 5, 10, 15, 30, 60].map(function (m) {
      return { key: String(m), name: String(m) };
    })
    currentKey: {
      var m = Number(settingsObj() ? settingsObj().refreshMinutes : 5);
      return isFinite(m) && m >= 1 ? String(Math.min(60, Math.round(m))) : "5";
    }
    onSelected: function (key) {
      settingsObj().refreshMinutes = Number(key);
      persist();
    }
  }

  // --- provider list --------------------------------------------------------

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: root.tr("settings.providers_label")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
    }

    Item { Layout.fillWidth: true }

    NButton {
      text: root.tr("settings.add_provider.button")
      icon: "plus"
      fontSize: Style.fontSizeS
      buttonRadius: Style.iRadiusS
      onClicked: root.openAdd()
    }
  }

  Repeater {
    model: mainInstance ? mainInstance.providers : []

    delegate: Rectangle {
      id: prow
      required property var modelData

      Layout.fillWidth: true
      readonly property bool active: modelData.id === (root.mainInstance ? root.mainInstance.activeProviderId : "")
      implicitHeight: Style.baseWidgetSize + Style.marginM * 2
      radius: Style.radiusS
      color: prow.active ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.12) : Color.mSurfaceVariant
      border.width: prow.active ? 1 : 0
      border.color: Color.mPrimary
      opacity: modelData.enabled ? 1 : 0.45

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.mainInstance)
            root.mainInstance.setActive(prow.modelData.id);
        }
      }

      RowLayout {
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        ProviderChip {
          Layout.alignment: Qt.AlignVCenter
          monogram: root.mainInstance ? root.mainInstance.chipFor(prow.modelData).monogram : "?"
          chipColor: root.mainInstance ? root.mainInstance.chipFor(prow.modelData).color : Color.mOnSurfaceVariant
          size: Style.fontSizeL
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: Style.marginXXS

          NText {
            Layout.fillWidth: true
            text: root.mainInstance ? root.mainInstance.displayLabel(prow.modelData) : ""
            color: Color.mOnSurface
            pointSize: Style.fontSizeM
            font.bold: prow.active
            elide: Text.ElideRight
          }

          NText {
            Layout.fillWidth: true
            text: (prow.modelData.apiKey
                   ? Logic.keyMask(prow.modelData.apiKey)
                   : (Logic.PROVIDERS[prow.modelData.type]
                        && Logic.PROVIDERS[prow.modelData.type].keyless
                      ? root.tr("settings.provider.cli_login")
                      : root.tr("desktop_widget.no_key")))
              + (prow.modelData.validUntil ? " · " + prow.modelData.validUntil : "")
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            elide: Text.ElideRight
          }
        }

        NToggle {
          Layout.alignment: Qt.AlignVCenter
          label: ""
          description: ""
          checked: prow.modelData.enabled
          onToggled: function (checked) {
            root.setEnabled(prow.modelData.id, checked);
          }
        }

        NIconButton {
          Layout.alignment: Qt.AlignVCenter
          icon: "pencil"
          tooltipText: root.tr("settings.edit")
          onClicked: root.openEdit(prow.modelData)
        }

        NIconButton {
          Layout.alignment: Qt.AlignVCenter
          icon: "trash"
          onClicked: root.removeProvider(prow.modelData.id)
        }
      }
    }
  }

  // --- add / edit form (visible only while filling it) ----------------------

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.formVisible
    spacing: Style.marginM

    NDivider {
      Layout.fillWidth: true
    }

    NText {
      Layout.fillWidth: true
      text: root.tr(root.editMode ? "settings.edit_provider.label" : "settings.add_provider.label")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
    }

    NComboBox {
      Layout.fillWidth: true
      label: root.tr("settings.provider.type")
      model: root.providerTypes().map(function (t) {
        return { key: t, name: Logic.PROVIDERS[t].name };
      })
      currentKey: root.newType
      onSelected: function (key) {
        root.newType = key;
      }
    }

    NTextInput {
      Layout.fillWidth: true
      visible: !root.formKeyless
      label: root.tr("settings.api_key.label")
      description: root.tr(root.editMode ? "settings.api_key.description_edit" : "settings.api_key.description")
      placeholderText: root.editMode && root.editKeyPreview !== ""
        ? root.editKeyPreview + " · " + root.tr("settings.api_key.placeholder_keep")
        : "sk-…"
      text: root.newApiKey
      onTextChanged: root.newApiKey = text
    }

    NText {
      Layout.fillWidth: true
      visible: root.formKeyless
      wrapMode: Text.WordWrap
      text: root.tr("settings.api_key.keyless_hint")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NTextInput {
        Layout.fillWidth: true
        label: root.tr("settings.provider.label_field")
        placeholderText: ""
        text: root.newLabel
        onTextChanged: root.newLabel = text
      }

      NTextInput {
        Layout.fillWidth: true
        label: root.tr("settings.provider.plan_field")
        placeholderText: "pro"
        text: root.newPlanLabel
        onTextChanged: root.newPlanLabel = text
      }
    }

    NTextInput {
      Layout.fillWidth: true
      label: root.tr("settings.provider.valid_until")
      placeholderText: "2026-09-15"
      text: root.newValidUntil
      onTextChanged: root.newValidUntil = text
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      Item { Layout.fillWidth: true }

      NButton {
        text: root.tr("settings.form.cancel")
        outlined: true
        fontSize: Style.fontSizeS
        buttonRadius: Style.iRadiusS
        onClicked: root.cancelForm()
      }

      NButton {
        text: root.tr(root.editMode ? "settings.edit_provider.action" : "settings.add_provider.action")
        icon: root.editMode ? "device-floppy" : "plus"
        fontSize: Style.fontSizeS
        buttonRadius: Style.iRadiusS
        enabled: root.editMode || root.formKeyless || root.newApiKey.trim() !== ""
        onClicked: root.submitForm()
      }
    }
  }

  // --- widget background ---------------------------------------------------------

  NToggle {
    Layout.fillWidth: true
    label: root.tr("settings.background.label")
    description: root.tr("settings.background.description")
    checked: settingsObj() ? settingsObj().showBackground : true
    onToggled: function (checked) {
      settingsObj().showBackground = checked;
      persist();
    }
  }
}
