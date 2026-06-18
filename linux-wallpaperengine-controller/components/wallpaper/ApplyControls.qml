import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "."

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  // Shared context.
  property var pluginApi: null
  property var mainInstance: null
  property var selectedWallpaperData: null

  // Apply target selection.
  property bool singleScreenMode: true
  property bool applyAllDisplays: true
  property bool applyTargetExpanded: false
  property var screenModel: []
  property string selectedScreenName: ""

  // Per-apply runtime options.
  property string selectedScaling: "fill"
  property string selectedClamp: "clamp"
  property int selectedVolume: 100
  property bool selectedMuted: true
  property bool selectedAudioReactiveEffects: true
  property bool selectedDisableMouse: false
  property bool selectedDisableParallax: false
  property bool applyWallpaperColorsOnApply: false
  property bool applyingWallpaperColors: false
  property bool showApplyButton: true

  // Extra wallpaper property editor state.
  property bool extraPropertiesEditorEnabled: true
  property bool loadingWallpaperProperties: false
  property string wallpaperPropertyError: ""
  property var wallpaperPropertyDefinitions: []
  property var propertyEditorApi: null

  // Upstream actions.
  signal applyRequested()
  signal applyAllDisplaysRequested(bool value)
  signal applyTargetExpandedRequested(bool value)
  signal selectedScreenNameRequested(string value)
  signal selectedScalingRequested(string value)
  signal selectedClampRequested(string value)
  signal selectedVolumeRequested(int value)
  signal selectedMutedRequested(bool value)
  signal selectedAudioReactiveEffectsRequested(bool value)
  signal selectedDisableMouseRequested(bool value)
  signal selectedDisableParallaxRequested(bool value)
  signal applyWallpaperColorsOnApplyRequested(bool value)

  Layout.fillWidth: true
  spacing: Style.marginS

  // Primary apply action and display target chooser.
  RowLayout {
    Layout.fillWidth: true
    visible: root.showApplyButton || (!root.singleScreenMode)
    spacing: Style.marginS

    NButton {
      visible: root.showApplyButton
      Layout.fillWidth: true
      text: root.applyAllDisplays
        ? pluginApi?.tr("panel.applyAllDisplays")
        : pluginApi?.tr("panel.applySingleDisplay", { screen: root.selectedScreenName })
      icon: "check"
      enabled: (root.mainInstance?.engineAvailable ?? false) && !!root.selectedWallpaperData
      onClicked: root.applyRequested()
    }

    NIconButton {
      Layout.preferredWidth: 42 * Style.uiScaleRatio
      Layout.preferredHeight: 42 * Style.uiScaleRatio
      visible: root.showApplyButton && !root.singleScreenMode
      enabled: root.mainInstance?.engineAvailable ?? false
      icon: "device-desktop"
      tooltipText: root.applyAllDisplays
        ? pluginApi?.tr("panel.targetAllDisplays")
        : pluginApi?.tr("panel.targetSingleDisplay", { screen: root.selectedScreenName })
      onClicked: root.applyTargetExpandedRequested(!root.applyTargetExpanded)
    }
  }

  NBox {
    Layout.fillWidth: true
    visible: !root.singleScreenMode && root.applyTargetExpanded
    Layout.preferredHeight: targetScreenColumn.implicitHeight + Style.marginL * 2

    ButtonGroup {
      id: targetScreenGroup
    }

    ColumnLayout {
      id: targetScreenColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginS

      NRadioButton {
        ButtonGroup.group: targetScreenGroup
        Layout.fillWidth: true
        enabled: root.mainInstance?.engineAvailable ?? false
        text: pluginApi?.tr("panel.applyAllDisplays")
        checked: root.applyAllDisplays
        onClicked: {
          root.applyAllDisplaysRequested(true)
          root.applyTargetExpandedRequested(false)
        }
      }

      Repeater {
        model: root.screenModel

        NRadioButton {
          ButtonGroup.group: targetScreenGroup
          required property var modelData
          Layout.fillWidth: true
          enabled: root.mainInstance?.engineAvailable ?? false
          text: pluginApi?.tr("panel.applySingleDisplay", { screen: modelData.name })
          checked: !root.applyAllDisplays && root.selectedScreenName === modelData.key
          onClicked: {
            root.applyAllDisplaysRequested(false)
            root.selectedScreenNameRequested(modelData.key)
            root.applyTargetExpandedRequested(false)
          }
        }
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NText {
    text: pluginApi?.tr("panel.sectionAudio")
    color: Color.mOnSurface
    font.weight: Font.Bold
    font.pointSize: Style.fontSizeM
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.wallpaperScaling")
    model: [
      { "key": "fill", "name": pluginApi?.tr("panel.scalingFill") },
      { "key": "fit", "name": pluginApi?.tr("panel.scalingFit") },
      { "key": "stretch", "name": pluginApi?.tr("panel.scalingStretch") },
      { "key": "default", "name": pluginApi?.tr("panel.scalingDefault") }
    ]
    currentKey: root.selectedScaling
    onSelected: key => root.selectedScalingRequested(key)
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.wallpaperClamp")
    model: [
      { "key": "clamp", "name": pluginApi?.tr("panel.clampClamp") },
      { "key": "border", "name": pluginApi?.tr("panel.clampBorder") },
      { "key": "repeat", "name": pluginApi?.tr("panel.clampRepeat") }
    ]
    currentKey: root.selectedClamp
    onSelected: key => root.selectedClampRequested(key)
  }

  NSpinBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.wallpaperVolume")
    from: 0
    to: 100
    stepSize: 1
    suffix: pluginApi?.tr("settings.units.percent")
    value: root.selectedVolume
    enabled: !root.selectedMuted
    onValueChanged: if (value !== root.selectedVolume) root.selectedVolumeRequested(value)
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.wallpaperMuted")
    checked: root.selectedMuted
    onToggled: checked => root.selectedMutedRequested(checked)
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginM
    Layout.bottomMargin: Style.marginM
  }

  NText {
    text: pluginApi?.tr("panel.sectionFeatures")
    color: Color.mOnSurface
    font.weight: Font.Bold
    font.pointSize: Style.fontSizeM
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.wallpaperAudioReactive")
    checked: root.selectedAudioReactiveEffects
    onToggled: checked => root.selectedAudioReactiveEffectsRequested(checked)
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.wallpaperDisableMouse")
    checked: root.selectedDisableMouse
    onToggled: checked => root.selectedDisableMouseRequested(checked)
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.wallpaperDisableParallax")
    checked: root.selectedDisableParallax
    onToggled: checked => root.selectedDisableParallaxRequested(checked)
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("panel.syncWallpaperColors")
    checked: root.applyWallpaperColorsOnApply
    enabled: (root.mainInstance?.engineAvailable ?? false)
      && !!root.selectedWallpaperData
      && !root.applyingWallpaperColors
    onToggled: checked => root.applyWallpaperColorsOnApplyRequested(checked)
  }

  // Optional extra property editor for wallpapers that expose editable values.
  ColumnLayout {
    Layout.fillWidth: true
    visible: root.extraPropertiesEditorEnabled
    spacing: Style.marginS

    NDivider {
      Layout.fillWidth: true
      Layout.topMargin: Style.marginM
      Layout.bottomMargin: Style.marginM
    }

    PropertiesEditor {
      pluginApi: root.pluginApi
      loadingWallpaperProperties: root.loadingWallpaperProperties
      wallpaperPropertyError: root.wallpaperPropertyError
      wallpaperPropertyDefinitions: root.wallpaperPropertyDefinitions
      propertyEditorApi: root.propertyEditorApi
    }
  }
}
