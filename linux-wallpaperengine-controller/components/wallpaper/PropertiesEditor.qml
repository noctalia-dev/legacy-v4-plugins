import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property bool loadingWallpaperProperties: false
  property string wallpaperPropertyError: ""
  property var wallpaperPropertyDefinitions: []
  property var propertyEditorApi: null

  Layout.fillWidth: true
  spacing: Style.marginS

  NText {
    text: pluginApi?.tr("panel.sectionProperties")
    color: Color.mOnSurface
    font.weight: Font.Bold
    font.pointSize: Style.fontSizeM
  }

  NText {
    visible: root.loadingWallpaperProperties
    Layout.fillWidth: true
    text: pluginApi?.tr("panel.loadingProperties")
    color: Color.mOnSurfaceVariant
    wrapMode: Text.Wrap
  }

  NText {
    visible: !root.loadingWallpaperProperties && root.wallpaperPropertyError.length > 0
    Layout.fillWidth: true
    text: root.wallpaperPropertyError
    color: Color.mError
    wrapMode: Text.Wrap
  }

  NText {
    visible: !root.loadingWallpaperProperties && root.wallpaperPropertyError.length === 0 && root.wallpaperPropertyDefinitions.length === 0
    Layout.fillWidth: true
    text: pluginApi?.tr("panel.noEditableProperties")
    color: Color.mOnSurfaceVariant
    wrapMode: Text.Wrap
  }

  NText {
    visible: !root.loadingWallpaperProperties && root.wallpaperPropertyDefinitions.length > 0
    Layout.fillWidth: true
    text: pluginApi?.tr("panel.propertiesNotice")
    color: Color.mOnSurfaceVariant
    wrapMode: Text.Wrap
  }

  Repeater {
    model: root.wallpaperPropertyDefinitions

    delegate: ColumnLayout {
      id: propertyEditor
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.marginXS

      property bool boolValue: !!(root.propertyEditorApi?.propertyValueFor ? root.propertyEditorApi.propertyValueFor(modelData) : false)
      property real sliderValue: root.propertyEditorApi?.numberOr ? root.propertyEditorApi.numberOr(root.propertyEditorApi?.propertyValueFor ? root.propertyEditorApi.propertyValueFor(modelData) : 0, 0) : 0
      property string comboValue: String(root.propertyEditorApi?.propertyValueFor ? root.propertyEditorApi.propertyValueFor(modelData) : "")
      property string textValue: String(root.propertyEditorApi?.propertyValueFor ? root.propertyEditorApi.propertyValueFor(modelData) : "")
      property string imageValue: modelData.type === "image"
        ? String(modelData.imageSource || "")
        : ""
      property color colorValue: Qt.rgba(1, 1, 1, 1)

      Component.onCompleted: {
        if (modelData.type === "color" && root.propertyEditorApi?.ensureColorValue && root.propertyEditorApi?.propertyValueFor) {
          propertyEditor.colorValue = root.propertyEditorApi.ensureColorValue(root.propertyEditorApi.propertyValueFor(modelData));
        }
      }

      NToggle {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: modelData.type === "boolean"
        label: modelData.label
        checked: propertyEditor.boolValue
        onToggled: checked => {
          if (checked === propertyEditor.boolValue) {
            return;
          }
          propertyEditor.boolValue = checked;
          if (root.propertyEditorApi?.setPropertyValue) {
            root.propertyEditorApi.setPropertyValue(modelData.key, checked);
          }
        }
      }

      NValueSlider {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: modelData.type === "slider"
        label: modelData.label
        from: root.propertyEditorApi?.numberOr ? root.propertyEditorApi.numberOr(modelData.min, 0) : 0
        to: root.propertyEditorApi?.numberOr ? root.propertyEditorApi.numberOr(modelData.max, 100) : 100
        stepSize: Math.max(root.propertyEditorApi?.numberOr ? root.propertyEditorApi.numberOr(modelData.step, 1) : 1, 0.001)
        value: propertyEditor.sliderValue
        text: root.propertyEditorApi?.formatSliderValue ? root.propertyEditorApi.formatSliderValue(propertyEditor.sliderValue, modelData.step) : String(propertyEditor.sliderValue)
        onMoved: value => {
          if (value === propertyEditor.sliderValue) {
            return;
          }
          propertyEditor.sliderValue = value;
          if (root.propertyEditorApi?.setPropertyValue) {
            root.propertyEditorApi.setPropertyValue(modelData.key, value);
          }
        }
      }

      NComboBox {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: modelData.type === "combo"
        label: modelData.label
        model: root.propertyEditorApi?.comboChoicesFor ? root.propertyEditorApi.comboChoicesFor(modelData) : []
        currentKey: propertyEditor.comboValue
        onSelected: key => {
          const normalizedKey = String(key);
          if (normalizedKey === propertyEditor.comboValue) {
            return;
          }
          propertyEditor.comboValue = normalizedKey;
          if (root.propertyEditorApi?.setPropertyValue) {
            root.propertyEditorApi.setPropertyValue(modelData.key, normalizedKey);
          }
        }
      }

      NTextInput {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: modelData.type === "textinput"
        label: modelData.label
        text: propertyEditor.textValue
        onEditingFinished: {
          const nextText = String(text);
          if (nextText === propertyEditor.textValue) {
            return;
          }
          propertyEditor.textValue = nextText;
          if (root.propertyEditorApi?.setPropertyValue) {
            root.propertyEditorApi.setPropertyValue(modelData.key, nextText);
          }
        }
        onAccepted: {
          const nextText = String(text);
          if (nextText === propertyEditor.textValue) {
            return;
          }
          propertyEditor.textValue = nextText;
          if (root.propertyEditorApi?.setPropertyValue) {
            root.propertyEditorApi.setPropertyValue(modelData.key, nextText);
          }
        }
      }

      NText {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: modelData.type === "text"
        text: modelData.label
        color: Color.mPrimary
        font.pointSize: Style.fontSizeM
        font.weight: Font.Bold
        wrapMode: Text.Wrap
        topPadding: Style.marginXS
        bottomPadding: Style.marginXS
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: modelData.type === "image"
        spacing: Style.marginXS

        NText {
          Layout.fillWidth: true
          visible: String(modelData.label || "").trim().length > 0
          text: modelData.label
          color: Color.mOnSurface
          font.pointSize: Style.fontSizeM
          wrapMode: Text.Wrap
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 160 * Style.uiScaleRatio
          radius: Style.radiusM
          color: Qt.alpha(Color.mSurfaceVariant, 0.35)
          border.width: Style.borderS
          border.color: Qt.alpha(Color.mOutline, 0.35)
          clip: true

          Image {
            id: sceneTexturePreview
            anchors.fill: parent
            anchors.margins: Style.marginXS
            source: parent.parent.visible && root.propertyEditorApi?.resolvePropertyImageSource
              ? root.propertyEditorApi.resolvePropertyImageSource(propertyEditor.imageValue)
              : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
          }

          NText {
            anchors.centerIn: parent
            visible: sceneTexturePreview.status === Image.Error || sceneTexturePreview.source.length === 0
            text: propertyEditor.imageValue
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WrapAnywhere
            width: parent.width - Style.marginM * 2
            horizontalAlignment: Text.AlignHCenter
          }
        }

        NText {
          Layout.fillWidth: true
          visible: sceneTexturePreview.status === Image.Error || sceneTexturePreview.source.length === 0
          text: propertyEditor.imageValue
          color: Color.mOnSurfaceVariant
          font.pointSize: Style.fontSizeS
          wrapMode: Text.WrapAnywhere
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: modelData.type === "color"
        spacing: Style.marginXS

        NText {
          Layout.fillWidth: true
          text: modelData.label
          color: Color.mOnSurface
          font.pointSize: Style.fontSizeM
          wrapMode: Text.Wrap
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.baseWidgetSize
          radius: Style.radiusM
          color: propertyEditor.colorValue
          border.width: Style.borderS
          border.color: Qt.alpha(Color.mOutline, 0.35)
        }

        NColorPicker {
          screen: pluginApi?.panelOpenScreen
          Layout.fillWidth: true
          Layout.preferredHeight: Style.baseWidgetSize
          selectedColor: propertyEditor.colorValue
          onColorSelected: color => {
            propertyEditor.colorValue = color;
            if (root.propertyEditorApi?.setPropertyValue) {
              root.propertyEditorApi.setPropertyValue(modelData.key, color);
            }
          }
        }

        NText {
          Layout.fillWidth: true
          text: root.propertyEditorApi?.serializePropertyValue ? root.propertyEditorApi.serializePropertyValue(propertyEditor.colorValue, "color") : ""
          color: Color.mOnSurfaceVariant
          font.pointSize: Style.fontSizeS
        }
      }
    }
  }
}
