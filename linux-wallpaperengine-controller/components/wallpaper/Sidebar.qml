import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

import "."
import "../shared"

SidebarPanel {
  id: root

  // Shared context.
  property var pluginApi: null
  property var mainInstance: null

  // Current wallpaper preview state.
  property var selectedWallpaperData: null
  property var propertyCompatibilityBadgeIconForPath: null
  property var propertyCompatibilityBadgeTextForPath: null
  property var propertyCompatibilityBadgeColorForPath: null
  property var propertyCompatibilityBadgeBackgroundForPath: null
  property var resolutionBadgeIcon: null
  property var resolutionBadgeLabel: null
  property var typeLabel: null
  property var typeBadgeIcon: null
  property var dynamicBadgeIcon: null
  property var badgeOrder: []
  property var isVideoMotion: null
  property var formatBytes: null
  property bool showDescription: true

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
  signal sidebarVisibleRequested(bool value)
  property bool sidebarVisible: true

  panelVisible: root.selectedWallpaperData !== null && root.sidebarVisible

  // Preview content.
  PreviewCard {
    pluginApi: root.pluginApi
    selectedWallpaperData: root.selectedWallpaperData
    propertyCompatibilityBadgeIconForPath: root.propertyCompatibilityBadgeIconForPath
    propertyCompatibilityBadgeTextForPath: root.propertyCompatibilityBadgeTextForPath
    propertyCompatibilityBadgeColorForPath: root.propertyCompatibilityBadgeColorForPath
    propertyCompatibilityBadgeBackgroundForPath: root.propertyCompatibilityBadgeBackgroundForPath
    resolutionBadgeIcon: root.resolutionBadgeIcon
    resolutionBadgeLabel: root.resolutionBadgeLabel
    typeLabel: root.typeLabel
    typeBadgeIcon: root.typeBadgeIcon
    dynamicBadgeIcon: root.dynamicBadgeIcon
    badgeOrder: root.badgeOrder
    isVideoMotion: root.isVideoMotion
    formatBytes: root.formatBytes
    showDescription: root.showDescription
  }

  // Apply controls and property editing.
  ApplyControls {
    pluginApi: root.pluginApi
    mainInstance: root.mainInstance
    selectedWallpaperData: root.selectedWallpaperData
    singleScreenMode: root.singleScreenMode
    applyAllDisplays: root.applyAllDisplays
    applyTargetExpanded: root.applyTargetExpanded
    screenModel: root.screenModel
    selectedScreenName: root.selectedScreenName
    selectedScaling: root.selectedScaling
    selectedClamp: root.selectedClamp
    selectedVolume: root.selectedVolume
    selectedMuted: root.selectedMuted
    selectedAudioReactiveEffects: root.selectedAudioReactiveEffects
    selectedDisableMouse: root.selectedDisableMouse
    selectedDisableParallax: root.selectedDisableParallax
    applyWallpaperColorsOnApply: root.applyWallpaperColorsOnApply
    applyingWallpaperColors: root.applyingWallpaperColors
    extraPropertiesEditorEnabled: root.extraPropertiesEditorEnabled
    loadingWallpaperProperties: root.loadingWallpaperProperties
    wallpaperPropertyError: root.wallpaperPropertyError
    wallpaperPropertyDefinitions: root.wallpaperPropertyDefinitions
    propertyEditorApi: root.propertyEditorApi
    onApplyRequested: root.applyRequested()
    onApplyAllDisplaysRequested: value => root.applyAllDisplaysRequested(value)
    onApplyTargetExpandedRequested: value => root.applyTargetExpandedRequested(value)
    onSelectedScreenNameRequested: value => root.selectedScreenNameRequested(value)
    onSelectedScalingRequested: value => root.selectedScalingRequested(value)
    onSelectedClampRequested: value => root.selectedClampRequested(value)
    onSelectedVolumeRequested: value => root.selectedVolumeRequested(value)
    onSelectedMutedRequested: value => root.selectedMutedRequested(value)
    onSelectedAudioReactiveEffectsRequested: value => root.selectedAudioReactiveEffectsRequested(value)
    onSelectedDisableMouseRequested: value => root.selectedDisableMouseRequested(value)
    onSelectedDisableParallaxRequested: value => root.selectedDisableParallaxRequested(value)
    onApplyWallpaperColorsOnApplyRequested: value => root.applyWallpaperColorsOnApplyRequested(value)
  }

  footerContent: NButton {
    Layout.fillWidth: true
    text: pluginApi?.tr("panel.closeSidebar")
    icon: "layout-sidebar-right-collapse"
    onClicked: root.sidebarVisibleRequested(false)
  }

}
