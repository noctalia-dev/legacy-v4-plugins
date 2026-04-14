import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Edit copies
  property int editMaxHistory: cfg.maxHistory ?? defaults.maxHistory ?? 50
  property int editPreviewWidth: cfg.previewWidth ?? defaults.previewWidth ?? 80
  property bool editEnableImages: cfg.enableImages ?? defaults.enableImages ?? true
  property bool editEnableAutoPaste: cfg.enableAutoPaste ?? defaults.enableAutoPaste ?? false
  property int editAutoPasteDelay: cfg.autoPasteDelay ?? defaults.autoPasteDelay ?? 300
  property bool editEnableFloatingPopup: cfg.enableFloatingPopup ?? defaults.enableFloatingPopup ?? true
  property string editIconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
  property bool editShowItemCount: cfg.showItemCount ?? defaults.showItemCount ?? true

  spacing: Style.marginL

  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.max-history.label")
    description: pluginApi?.tr("settings.max-history.desc")
    from: 10
    to: 200
    stepSize: 10
    value: root.editMaxHistory
    text: String(root.editMaxHistory)
    onMoved: value => { root.editMaxHistory = Math.round(value); }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.preview-width.label")
    description: pluginApi?.tr("settings.preview-width.desc")
    from: 20
    to: 200
    stepSize: 10
    value: root.editPreviewWidth
    text: String(root.editPreviewWidth)
    onMoved: value => { root.editPreviewWidth = Math.round(value); }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.enable-images.label")
    description: pluginApi?.tr("settings.enable-images.desc")
    checked: root.editEnableImages
    onToggled: checked => { root.editEnableImages = checked; }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.enable-auto-paste.label")
    description: pluginApi?.tr("settings.enable-auto-paste.desc")
    checked: root.editEnableAutoPaste
    onToggled: checked => { root.editEnableAutoPaste = checked; }
  }

  NValueSlider {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.auto-paste-delay.label")
    description: pluginApi?.tr("settings.auto-paste-delay.desc")
    from: 100
    to: 1000
    stepSize: 50
    value: root.editAutoPasteDelay
    text: root.editAutoPasteDelay + " ms"
    visible: root.editEnableAutoPaste
    onMoved: value => { root.editAutoPasteDelay = Math.round(value); }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.enable-floating-popup.label")
    description: pluginApi?.tr("settings.enable-floating-popup.desc")
    checked: root.editEnableFloatingPopup
    onToggled: checked => { root.editEnableFloatingPopup = checked; }
  }

  NComboBox {
    label: pluginApi?.tr("settings.icon-color.label")
    description: pluginApi?.tr("settings.icon-color.desc")
    model: Color.colorKeyModel
    currentKey: root.editIconColor
    onSelected: key => { root.editIconColor = key; }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show-item-count.label")
    description: pluginApi?.tr("settings.show-item-count.desc")
    checked: root.editShowItemCount
    onToggled: checked => { root.editShowItemCount = checked; }
  }

  function saveSettings() {
    if (!pluginApi) return;
    pluginApi.pluginSettings.maxHistory = root.editMaxHistory;
    pluginApi.pluginSettings.previewWidth = root.editPreviewWidth;
    pluginApi.pluginSettings.enableImages = root.editEnableImages;
    pluginApi.pluginSettings.enableAutoPaste = root.editEnableAutoPaste;
    pluginApi.pluginSettings.autoPasteDelay = root.editAutoPasteDelay;
    pluginApi.pluginSettings.enableFloatingPopup = root.editEnableFloatingPopup;
    pluginApi.pluginSettings.iconColor = root.editIconColor;
    pluginApi.pluginSettings.showItemCount = root.editShowItemCount;
    pluginApi.saveSettings();
  }
}
