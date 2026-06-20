import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string editHabiticaUserId: cfg.habiticaUserId ?? defaults.habiticaUserId ?? ""
  property string editHabiticaApiToken: cfg.habiticaApiToken ?? defaults.habiticaApiToken ?? ""
  property int editRefreshInterval: cfg.refreshInterval ?? defaults.refreshInterval ?? 300
  property int editMaxDailies: cfg.maxDailies ?? defaults.maxDailies ?? 8
  property int editMaxTodos: cfg.maxTodos ?? defaults.maxTodos ?? 8
  property int editMaxHabits: cfg.maxHabits ?? defaults.maxHabits ?? 8
  property bool editShowHabits: cfg.showHabits ?? defaults.showHabits ?? false
  property bool editShowChecklistItems: cfg.showChecklistItems ?? defaults.showChecklistItems ?? false
  property bool editEnableTagFilter: cfg.enableTagFilter ?? defaults.enableTagFilter ?? false
  property string editSelectedTagId: cfg.selectedTagId ?? defaults.selectedTagId ?? ""
  property bool editShowNotificationBadge: cfg.showNotificationBadge ?? defaults.showNotificationBadge ?? true
  property bool editColorizationEnabled: cfg.colorizationEnabled ?? defaults.colorizationEnabled ?? false
  property string editColorizationIcon: cfg.colorizationIcon ?? defaults.colorizationIcon ?? "Primary"
  property string editColorizationBadge: cfg.colorizationBadge ?? defaults.colorizationBadge ?? "Error"
  property string editColorizationBadgeText: cfg.colorizationBadgeText ?? defaults.colorizationBadgeText ?? "Primary"

  spacing: Style.marginM

  NLabel {
    label: pluginApi?.tr("settings.account.label")
    description: pluginApi?.tr("settings.account.description")
  }

  NTextInput {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.userId.label")
    description: pluginApi?.tr("settings.userId.description")
    placeholderText: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    text: root.editHabiticaUserId
    onTextChanged: root.editHabiticaUserId = text
  }

  NTextInput {
    id: apiTokenInput
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.apiToken.label")
    description: pluginApi?.tr("settings.apiToken.description")
    placeholderText: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    text: root.editHabiticaApiToken
    onTextChanged: root.editHabiticaApiToken = text

    Component.onCompleted: {
      if (apiTokenInput.inputItem) {
        apiTokenInput.inputItem.echoMode = TextInput.Password
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NLabel {
    label: pluginApi?.tr("settings.basicUi.label")
    description: pluginApi?.tr("settings.basicUi.description")
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.refreshInterval.label")
      description: pluginApi?.tr("settings.refreshInterval.descriptionPrefix") + Math.floor(root.editRefreshInterval / 60) + pluginApi?.tr("settings.refreshInterval.descriptionSuffix")
    }

    NSlider {
      Layout.fillWidth: true
      from: 60
      to: 3600
      stepSize: 60
      value: root.editRefreshInterval
      onValueChanged: root.editRefreshInterval = value
    }
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 2
    columnSpacing: Style.marginM
    rowSpacing: Style.marginS

    ColumnLayout {
      Layout.fillWidth: true

      NLabel {
        label: pluginApi?.tr("settings.dailies.label")
        description: pluginApi?.tr("settings.dailies.descriptionPrefix") + root.editMaxDailies
      }

      NSlider {
        Layout.fillWidth: true
        from: 1
        to: 25
        stepSize: 1
        value: root.editMaxDailies
        onValueChanged: root.editMaxDailies = value
      }
    }

    ColumnLayout {
      Layout.fillWidth: true

      NLabel {
        label: pluginApi?.tr("settings.todos.label")
        description: pluginApi?.tr("settings.todos.descriptionPrefix") + root.editMaxTodos
      }

      NSlider {
        Layout.fillWidth: true
        from: 1
        to: 25
        stepSize: 1
        value: root.editMaxTodos
        onValueChanged: root.editMaxTodos = value
      }
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.notificationBadge.label")
    description: pluginApi?.tr("settings.notificationBadge.description")
    checked: root.editShowNotificationBadge
    onToggled: checked => root.editShowNotificationBadge = checked
  }

  NDivider {
    Layout.fillWidth: true
  }

  NLabel {
    label: pluginApi?.tr("settings.advancedUi.label")
    description: pluginApi?.tr("settings.advancedUi.description")
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showHabits.label")
    description: pluginApi?.tr("settings.showHabits.description")
    checked: root.editShowHabits
    onToggled: checked => root.editShowHabits = checked
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.editShowHabits

    NLabel {
      label: pluginApi?.tr("settings.habits.label")
      description: pluginApi?.tr("settings.habits.descriptionPrefix") + root.editMaxHabits
    }

    NSlider {
      Layout.fillWidth: true
      from: 1
      to: 25
      stepSize: 1
      value: root.editMaxHabits
      onValueChanged: root.editMaxHabits = value
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.checklist.label")
    description: pluginApi?.tr("settings.checklist.description")
    checked: root.editShowChecklistItems
    onToggled: checked => root.editShowChecklistItems = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.tagFilter.label")
    description: pluginApi?.tr("settings.tagFilter.description")
    checked: root.editEnableTagFilter
    onToggled: checked => root.editEnableTagFilter = checked
  }

  NTextInput {
    Layout.fillWidth: true
    visible: root.editEnableTagFilter
    label: pluginApi?.tr("settings.selectedTag.label")
    description: pluginApi?.tr("settings.selectedTag.description")
    placeholderText: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    text: root.editSelectedTagId
    onTextChanged: root.editSelectedTagId = text
  }

  NDivider {
    Layout.fillWidth: true
  }

  NLabel {
    label: pluginApi?.tr("settings.colors.label")
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.colorization.label")
    description: pluginApi?.tr("settings.colorization.description")
    checked: root.editColorizationEnabled
    onToggled: checked => root.editColorizationEnabled = checked
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editColorizationEnabled
    label: pluginApi?.tr("settings.iconColor.label")
    model: colorModel
    currentKey: root.editColorizationIcon
    onSelected: key => root.editColorizationIcon = key
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editColorizationEnabled
    label: pluginApi?.tr("settings.badgeColor.label")
    model: colorModel
    currentKey: root.editColorizationBadge
    onSelected: key => root.editColorizationBadge = key
  }

  NComboBox {
    Layout.fillWidth: true
    visible: root.editColorizationEnabled
    label: pluginApi?.tr("settings.badgeTextColor.label")
    model: colorModel
    currentKey: root.editColorizationBadgeText
    onSelected: key => root.editColorizationBadgeText = key
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: infoColumn.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant
    radius: Style.radiusM

    ColumnLayout {
      id: infoColumn
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.ipc.title")
        pointSize: Style.fontSizeS
        font.weight: Font.Bold
        color: Color.mOnSurface
      }

      NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.ipc.refresh")
        pointSize: Style.fontSizeXS
        font.family: Settings.data.ui.fontFixed
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WrapAnywhere
      }
    }
  }

  property var colorModel: [
    { key: "None", name: "None" },
    { key: "Primary", name: "Primary" },
    { key: "Secondary", name: "Secondary" },
    { key: "Tertiary", name: "Tertiary" },
    { key: "Error", name: "Error" }
  ]

  function saveSettings() {
    if (!pluginApi) return

    pluginApi.pluginSettings.habiticaUserId = root.editHabiticaUserId.trim()
    pluginApi.pluginSettings.habiticaApiToken = root.editHabiticaApiToken.trim()
    pluginApi.pluginSettings.refreshInterval = root.editRefreshInterval
    pluginApi.pluginSettings.maxDailies = root.editMaxDailies
    pluginApi.pluginSettings.maxTodos = root.editMaxTodos
    pluginApi.pluginSettings.maxHabits = root.editMaxHabits
    pluginApi.pluginSettings.showHabits = root.editShowHabits
    pluginApi.pluginSettings.showChecklistItems = root.editShowChecklistItems
    pluginApi.pluginSettings.enableTagFilter = root.editEnableTagFilter
    pluginApi.pluginSettings.selectedTagId = root.editSelectedTagId.trim()
    pluginApi.pluginSettings.showNotificationBadge = root.editShowNotificationBadge
    pluginApi.pluginSettings.colorizationEnabled = root.editColorizationEnabled
    pluginApi.pluginSettings.colorizationIcon = root.editColorizationIcon
    pluginApi.pluginSettings.colorizationBadge = root.editColorizationBadge
    pluginApi.pluginSettings.colorizationBadgeText = root.editColorizationBadgeText

    pluginApi.saveSettings()
    Logger.i("Habitica", "Settings saved")
    ToastService.showNotice(pluginApi?.tr("settings.saved"))
  }
}
