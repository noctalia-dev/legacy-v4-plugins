import qs.Commons
import qs.Widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
  id: root

  property int editAnimationCardsDuration: pluginApi?.pluginSettings?.animation_cards_duration ?? pluginApi?.manifest?.metadata?.defaultSettings?.animation_cards_duration
  property int editAnimationDuration: pluginApi?.pluginSettings?.animation_duration ?? pluginApi?.manifest?.metadata?.defaultSettings?.animation_window_duration
  property int editAnimationWindowDuration: pluginApi?.pluginSettings?.animation_window_duration ?? pluginApi?.manifest?.metadata?.defaultSettings?.animation_window_duration
  property color editBackgroundColor: pluginApi?.pluginSettings?.background_color ?? pluginApi?.manifest?.metadata?.defaultSettings?.background_color
  property real editBackgroundOpacity: pluginApi?.pluginSettings?.background_opacity ?? pluginApi?.manifest?.metadata?.defaultSettings?.background_opacity
  property int editCardHeight: pluginApi?.pluginSettings?.card_height ?? pluginApi?.manifest?.metadata?.defaultSettings?.card_height
  property int editCardSpacing: pluginApi?.pluginSettings?.card_spacing ?? pluginApi?.manifest?.metadata?.defaultSettings?.card_spacing
  property int editCardStripWidth: pluginApi?.pluginSettings?.card_strip_width ?? pluginApi?.manifest?.metadata?.defaultSettings?.card_strip_width
  property int editCardsShown: pluginApi?.pluginSettings?.cards_shown ?? pluginApi?.manifest?.metadata?.defaultSettings?.cards_shown
  property real editCenterWidthRatio: pluginApi?.pluginSettings?.center_width_ratio ?? pluginApi?.manifest?.metadata?.defaultSettings?.center_width_ratio
  property bool editHideHelp: pluginApi?.pluginSettings?.hide_help ?? pluginApi?.manifest?.metadata?.defaultSettings?.hide_help
  property bool editHideTopBar: pluginApi?.pluginSettings?.hide_top_bar ?? pluginApi?.manifest?.metadata?.defaultSettings?.hide_top_bar ?? false
  property bool editAnimateWindow: pluginApi?.pluginSettings?.animate_window ?? pluginApi?.manifest?.metadata?.defaultSettings?.animate_window ?? true
  property string editIconColor: pluginApi?.pluginSettings?.icon_color ?? "none"
  property bool editLivePreview: pluginApi?.pluginSettings?.live_preview ?? pluginApi?.manifest?.metadata?.defaultSettings?.live_preview
  property string editSelectedFilter: pluginApi?.pluginSettings?.selected_filter || pluginApi?.manifest?.metadata?.defaultSettings?.selected_filter
  property real editShearFactor: pluginApi?.pluginSettings?.shear_factor ?? pluginApi?.manifest?.metadata?.defaultSettings?.shear_factor
  property int editTopBarHeight: pluginApi?.pluginSettings?.top_bar_height ?? pluginApi?.manifest?.metadata?.defaultSettings?.top_bar_height
  property var pluginApi: null

  function saveSettings() {
    if (!pluginApi || !pluginApi.pluginSettings) {
      Logger.e("Wallcards", "Cannot save: pluginApi or pluginSettings is null");
      return;
    }

    pluginApi.pluginSettings.animation_cards_duration = root.editAnimationCardsDuration;
    pluginApi.pluginSettings.animation_window_duration = root.editAnimationWindowDuration;
    pluginApi.pluginSettings.background_color = root.editBackgroundColor.toString();
    pluginApi.pluginSettings.background_opacity = root.editBackgroundOpacity;

    pluginApi.pluginSettings.center_width_ratio = root.editCenterWidthRatio;
    pluginApi.pluginSettings.card_height = root.editCardHeight;
    pluginApi.pluginSettings.card_spacing = root.editCardSpacing;
    pluginApi.pluginSettings.card_strip_width = root.editCardStripWidth;
    pluginApi.pluginSettings.cards_shown = root.editCardsShown;

    pluginApi.pluginSettings.shear_factor = root.editShearFactor;

    pluginApi.pluginSettings.top_bar_height = root.editTopBarHeight;

    pluginApi.pluginSettings.iconColor = root.editIconColor;
    pluginApi.pluginSettings.selected_filter = root.editSelectedFilter;
    pluginApi.pluginSettings.live_preview = root.editLivePreview;
    pluginApi.pluginSettings.hide_help = root.editHideHelp;
    pluginApi.pluginSettings.hide_top_bar = root.editHideTopBar;
    pluginApi.pluginSettings.animate_window = root.editAnimateWindow;

    pluginApi.saveSettings();
    Logger.i("Wallcards", "Settings saved");
  }

  Layout.rightMargin: Style.marginL
  spacing: Style.marginL

  // ── Icon ──
  NComboBox {
    currentKey: root.editIconColor
    description: I18n.tr("common.select-color-description")
    label: I18n.tr("common.select-icon-color")
    minimumWidth: 200
    model: Color.colorKeyModel

    onSelected: key => root.editIconColor = key
  }
  NDivider {
    Layout.fillWidth: true
  }

  // ── Behavior ──
  NToggle {
    checked: root.editLivePreview
    defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.live_preview ?? false
    description: root.pluginApi?.tr("settings.live-preview.description")
    label: root.pluginApi?.tr("settings.live-preview.label")

    onToggled: c => root.editLivePreview = c
  }
  NComboBox {
    currentKey: root.editSelectedFilter
    defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.selected_filter || "all"
    description: root.pluginApi?.tr("settings.default-filter.description")
    label: root.pluginApi?.tr("settings.default-filter.label")
    model: [
      {
        "key": "all",
        "name": root.pluginApi?.tr("buttons.all")
      },
      {
        "key": "images",
        "name": root.pluginApi?.tr("buttons.images")
      },
      {
        "key": "videos",
        "name": root.pluginApi?.tr("buttons.videos")
      }
    ]

    onSelected: key => root.editSelectedFilter = key
  }
  NToggle {
    checked: root.editHideHelp
    defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.hide_help ?? false
    description: root.pluginApi?.tr("settings.hide-shortcuts.description")
    label: root.pluginApi?.tr("settings.hide-shortcuts.label")

    onToggled: c => root.editHideHelp = c
  }
  NToggle {
    checked: root.editHideTopBar
    defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.hide_top_bar ?? false
    description: root.pluginApi?.tr("settings.hide-top-bar.description")
    label: root.pluginApi?.tr("settings.hide-top-bar.label")

    onToggled: c => root.editHideTopBar = c
  }
  NDivider {
    Layout.fillWidth: true
  }

  // ── Card Layout ──
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.center-card-width.description")
      label: root.pluginApi?.tr("settings.center-card-width.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 0.20
      stepSize: 0.01
      text: (root.editCenterWidthRatio * 100).toFixed(0) + "%"
      to: 0.60
      value: root.editCenterWidthRatio

      onMoved: value => root.editCenterWidthRatio = value
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.card-height.description")
      label: root.pluginApi?.tr("settings.card-height.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 100
      stepSize: 10
      text: root.editCardHeight + "px"
      to: 800
      value: root.editCardHeight

      onMoved: value => root.editCardHeight = value
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.strip-width.description")
      label: root.pluginApi?.tr("settings.strip-width.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 20
      stepSize: 5
      text: root.editCardStripWidth + "px"
      to: 150
      value: root.editCardStripWidth

      onMoved: value => root.editCardStripWidth = value
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.card-spacing.description")
      label: root.pluginApi?.tr("settings.card-spacing.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 0
      stepSize: 1
      text: root.editCardSpacing + "px"
      to: 50
      value: root.editCardSpacing

      onMoved: value => root.editCardSpacing = value
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.cards-shown.description")
      label: root.pluginApi?.tr("settings.cards-shown.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 5
      stepSize: 2
      text: root.editCardsShown
      to: 15
      value: root.editCardsShown

      onMoved: value => root.editCardsShown = value
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.marginXXS

      NLabel {
        description: root.pluginApi?.tr("settings.shear-factor.description")
        label: root.pluginApi?.tr("settings.shear-factor.label")
      }
      NValueSlider {
        Layout.fillWidth: true
        from: -0.3
        stepSize: 0.01
        text: root.editShearFactor.toFixed(2)
        to: 0.3
        value: root.editShearFactor

        onMoved: value => root.editShearFactor = value
      }
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.card-animation.description")
      label: root.pluginApi?.tr("settings.card-animation.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 0
      stepSize: 100
      text: root.editAnimationCardsDuration + "ms"
      to: 1500
      value: root.editAnimationCardsDuration

      onMoved: value => root.editAnimationCardsDuration = value
    }
  }
  NDivider {
    Layout.fillWidth: true
  }

  // ── Appearance ──
  RowLayout {
    NLabel {
      Layout.alignment: Qt.AlignTop
      description: root.pluginApi?.tr("settings.background-color.description")
      label: root.pluginApi?.tr("settings.background-color.label")
    }
    NColorPicker {
      selectedColor: root.editBackgroundColor

      onColorSelected: color => root.editBackgroundColor = color
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.background-opacity.description")
      label: root.pluginApi?.tr("settings.background-opacity.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 0
      stepSize: 0.05
      text: (root.editBackgroundOpacity * 100).toFixed(0) + "%"
      to: 1
      value: root.editBackgroundOpacity

      onMoved: value => root.editBackgroundOpacity = value
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.window-animation-speed.description")
      label: root.pluginApi?.tr("settings.window-animation-speed.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 0
      stepSize: 100
      text: root.editAnimationWindowDuration + "ms"
      to: 1500
      value: root.editAnimationWindowDuration

      onMoved: value => root.editAnimationWindowDuration = value
    }
  }
  NToggle {
    checked: root.editAnimateWindow
    defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.animate_window ?? true
    description: root.pluginApi?.tr("settings.animate-window.description")
    label: root.pluginApi?.tr("settings.animate-window.label")

    onToggled: c => root.editAnimateWindow = c
  }
  NDivider {
    Layout.fillWidth: true
  }

  // ── Top Bar ──
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS

    NLabel {
      description: root.pluginApi?.tr("settings.top-bar-height.description")
      label: root.pluginApi?.tr("settings.top-bar-height.label")
    }
    NValueSlider {
      Layout.fillWidth: true
      from: 10
      stepSize: 2
      text: root.editTopBarHeight + "px"
      to: 80
      value: root.editTopBarHeight

      onMoved: value => root.editTopBarHeight = value
    }
  }
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginXXS
  }
}
