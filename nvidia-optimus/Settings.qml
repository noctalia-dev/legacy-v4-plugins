import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Settings view for the NVIDIA Optimus plugin.
Item {
  id: root

  property var pluginApi: null

  implicitHeight: col.implicitHeight

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.marginM

    NText {
      text: "NVIDIA Optimus"
      font.weight: Style.fontWeightBold
      pointSize: Style.fontSizeL
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      text: "The bar toggle flips Hyprland's AQ_DRM_DEVICES between Battery (iGPU only — the NVIDIA dGPU runtime-suspends, no HDMI) and HDMI-Ready (iGPU + dGPU — external outputs work). It edits ~/.config/hypr/env.conf (backed up alongside) and applies on the next login. The bar icon is theme-tinted: accent when the dGPU is awake, neutral when asleep. Stats poll every 2s from a bundled sysfs-only script that never wakes the GPU; nvidia-smi runs only while this panel is open, and only when the GPU is already awake."
    }

    NText {
      Layout.fillWidth: true
      wrapMode: Text.WordWrap
      pointSize: Style.fontSizeXS
      color: Color.mOnSurfaceVariant
      text: "Requires: Hyprland (aquamarine), an NVIDIA Optimus laptop with the proprietary driver + nvidia-drm.modeset=1. Override the env file with $HYPR_ENV_FILE if yours lives elsewhere."
    }
  }
}
