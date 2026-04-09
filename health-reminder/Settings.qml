import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool editEnableSedentaryReminder: cfg.enableSedentaryReminder ?? defaults.enableSedentaryReminder ?? true
  property int editSedentaryIntervalMinutes: cfg.sedentaryIntervalMinutes ?? defaults.sedentaryIntervalMinutes ?? 45
  property string editSedentaryMessage: cfg.sedentaryMessage ?? defaults.sedentaryMessage ?? pluginApi?.tr("toast.sedentary")
  property bool editEnableHydrationReminder: cfg.enableHydrationReminder ?? defaults.enableHydrationReminder ?? true
  property int editHydrationIntervalMinutes: cfg.hydrationIntervalMinutes ?? defaults.hydrationIntervalMinutes ?? 30
  property string editHydrationMessage: cfg.hydrationMessage ?? defaults.hydrationMessage ?? pluginApi?.tr("toast.hydration")
  property bool editDebugMode: cfg.debugMode ?? defaults.debugMode ?? false
  property string editIconColor: cfg.iconColor ?? defaults.iconColor ?? "none"
  property var editMedicationReminders: []
  property int medicationRevision: 0

  implicitWidth: 560 * Style.uiScaleRatio
  implicitHeight: 720 * Style.uiScaleRatio

  Component.onCompleted: {
    loadMedicationReminders();
  }

  function loadMedicationReminders() {
    let src = cfg.medicationReminders ?? defaults.medicationReminders ?? [];
    if (!Array.isArray(src)) src = [];

    const copy = [];
    for (let i = 0; i < src.length; i++) {
      copy.push({
        "id": src[i].id || `med-${i}`,
        "name": src[i].name || "",
        "time": src[i].time || "08:00",
        "enabled": src[i].enabled !== false,
        "message": src[i].message || ""
      });
    }

    editMedicationReminders = copy;
    medicationRevision++;
  }

  function addMedicationReminder() {
    editMedicationReminders = editMedicationReminders.concat([
      {
        "id": `med-${Date.now()}-${editMedicationReminders.length}`,
        "name": "",
        "time": "08:00",
        "enabled": true,
        "message": ""
      }
    ]);
    medicationRevision++;
  }

  function removeMedicationReminder(index) {
    const items = editMedicationReminders.slice();
    items.splice(index, 1);
    editMedicationReminders = items;
    medicationRevision++;
  }

  function updateMedicationReminder(index, key, value) {
    const items = editMedicationReminders.slice();
    if (index < 0 || index >= items.length) return;
    const nextItem = {
      "id": items[index].id,
      "name": items[index].name,
      "time": items[index].time,
      "enabled": items[index].enabled,
      "message": items[index].message
    };
    nextItem[key] = value;
    items[index] = nextItem;
    editMedicationReminders = items;
    medicationRevision++;
  }

  Flickable {
    id: settingsFlickable
    anchors.fill: parent
    contentHeight: contentColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.DragOverBounds

    ScrollBar.vertical: ScrollBar {
      parent: settingsFlickable
      anchors.top: settingsFlickable.top
      anchors.right: settingsFlickable.right
      anchors.bottom: settingsFlickable.bottom
      policy: ScrollBar.AsNeeded
    }

    ColumnLayout {
      id: contentColumn
      width: settingsFlickable.width
      spacing: Style.marginL

      NHeader {
        label: pluginApi?.tr("settings.sections.general.label")
        description: pluginApi?.tr("settings.sections.general.description")
      }

      NColorChoice {
        label: I18n.tr("common.select-icon-color")
        description: I18n.tr("common.select-color-description")
        currentKey: root.editIconColor
        onSelected: key => root.editIconColor = key
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NLabel {
          label: pluginApi?.tr("settings.debugMode.label")
          description: pluginApi?.tr("settings.debugMode.description")
        }

        NToggle {
          checked: root.editDebugMode
          onToggled: checked => root.editDebugMode = checked
        }
      }

      NDivider {
        Layout.fillWidth: true
      }

      NHeader {
        label: pluginApi?.tr("settings.sections.system.label")
        description: pluginApi?.tr("settings.sections.system.description")
      }

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: systemReminderColumn.implicitHeight + Style.marginM * 2

        ColumnLayout {
          id: systemReminderColumn
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginL

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NLabel {
              label: pluginApi?.tr("settings.sedentary.enabled.label")
              description: pluginApi?.tr("settings.sedentary.enabled.description")
            }

            NToggle {
              checked: root.editEnableSedentaryReminder
              onToggled: checked => root.editEnableSedentaryReminder = checked
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NLabel {
              label: pluginApi?.tr("settings.sedentary.interval.label")
              description: pluginApi?.tr("settings.sedentary.interval.description")
            }

            NSpinBox {
              from: 5
              to: 180
              stepSize: 5
              suffix: " min"
              value: root.editSedentaryIntervalMinutes
              onValueChanged: if (value !== root.editSedentaryIntervalMinutes) root.editSedentaryIntervalMinutes = value
            }
          }

          NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.sedentary.message.label")
            description: pluginApi?.tr("settings.sedentary.message.description")
            placeholderText: pluginApi?.tr("settings.sedentary.message.placeholder")
            text: root.editSedentaryMessage
            onTextChanged: root.editSedentaryMessage = text
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NLabel {
              label: pluginApi?.tr("settings.hydration.enabled.label")
              description: pluginApi?.tr("settings.hydration.enabled.description")
            }

            NToggle {
              checked: root.editEnableHydrationReminder
              onToggled: checked => root.editEnableHydrationReminder = checked
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NLabel {
              label: pluginApi?.tr("settings.hydration.interval.label")
              description: pluginApi?.tr("settings.hydration.interval.description")
            }

            NSpinBox {
              from: 5
              to: 180
              stepSize: 5
              suffix: " min"
              value: root.editHydrationIntervalMinutes
              onValueChanged: if (value !== root.editHydrationIntervalMinutes) root.editHydrationIntervalMinutes = value
            }
          }

          NTextInput {
            Layout.fillWidth: true
            label: pluginApi?.tr("settings.hydration.message.label")
            description: pluginApi?.tr("settings.hydration.message.description")
            placeholderText: pluginApi?.tr("settings.hydration.message.placeholder")
            text: root.editHydrationMessage
            onTextChanged: root.editHydrationMessage = text
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
      }

      NHeader {
        label: pluginApi?.tr("settings.medication.header")
        description: pluginApi?.tr("settings.medication.description")
      }

      Repeater {
        model: {
          void root.medicationRevision;
          return root.editMedicationReminders.length;
        }

        delegate: NBox {
          required property int index
          Layout.fillWidth: true
          Layout.preferredHeight: medicationItem.implicitHeight + Style.marginM * 2

          readonly property var reminder: {
            void root.medicationRevision;
            return index >= 0 && index < root.editMedicationReminders.length ? root.editMedicationReminders[index] : null;
          }

          ColumnLayout {
            id: medicationItem
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.medication.name.label")
              placeholderText: pluginApi?.tr("settings.medication.name.placeholder")
              text: reminder?.name || ""
              onTextChanged: {
                if ((reminder?.name || "") !== text) {
                  root.updateMedicationReminder(index, "name", text);
                }
              }
            }

            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.medication.time.label")
              placeholderText: "08:00"
              text: reminder?.time || "08:00"
              onTextChanged: {
                const nextValue = text.trim();
                if ((reminder?.time || "") !== nextValue) {
                  root.updateMedicationReminder(index, "time", nextValue);
                }
              }
            }

            NTextInput {
              Layout.fillWidth: true
              label: pluginApi?.tr("settings.medication.message.label")
              placeholderText: pluginApi?.tr("settings.medication.message.placeholder")
              text: reminder?.message || ""
              onTextChanged: {
                if ((reminder?.message || "") !== text) {
                  root.updateMedicationReminder(index, "message", text);
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              NToggle {
                checked: reminder?.enabled ?? true
                onToggled: checked => root.updateMedicationReminder(index, "enabled", checked)
              }

              NText {
                text: pluginApi?.tr("settings.medication.enabled")
                color: Color.mOnSurfaceVariant
                Layout.fillWidth: true
              }

              NIconButton {
                icon: "trash"
                tooltipText: pluginApi?.tr("settings.medication.remove")
                onClicked: root.removeMedicationReminder(index)
              }
            }
          }
        }
      }

      NText {
        visible: root.editMedicationReminders.length === 0
        text: pluginApi?.tr("settings.medication.empty")
        color: Color.mOnSurfaceVariant
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }

      NButton {
        text: pluginApi?.tr("settings.medication.add")
        icon: "plus"
        onClicked: root.addMedicationReminder()
      }
    }
  }

  function saveSettings() {
    if (!pluginApi) return;

    if (!pluginApi.pluginSettings) {
      pluginApi.pluginSettings = {};
    }

    const validMedicationReminders = [];
    for (let i = 0; i < editMedicationReminders.length; i++) {
      const item = editMedicationReminders[i];
      const time = (item.time || "").trim();
      if (!/^([01]\d|2[0-3]):([0-5]\d)$/.test(time)) {
        continue;
      }

      validMedicationReminders.push({
        "id": item.id || `med-${i}`,
        "name": (item.name || "").trim() || pluginApi?.tr("panel.medication.defaultName"),
        "time": time,
        "enabled": item.enabled !== false,
        "message": (item.message || "").trim()
      });
    }

    pluginApi.pluginSettings.enableSedentaryReminder = root.editEnableSedentaryReminder;
    pluginApi.pluginSettings.sedentaryIntervalMinutes = root.editSedentaryIntervalMinutes;
    pluginApi.pluginSettings.sedentaryMessage = root.editSedentaryMessage;
    pluginApi.pluginSettings.enableHydrationReminder = root.editEnableHydrationReminder;
    pluginApi.pluginSettings.hydrationIntervalMinutes = root.editHydrationIntervalMinutes;
    pluginApi.pluginSettings.hydrationMessage = root.editHydrationMessage;
    pluginApi.pluginSettings.debugMode = root.editDebugMode;
    pluginApi.pluginSettings.iconColor = root.editIconColor;
    pluginApi.pluginSettings.medicationReminders = validMedicationReminders;
    pluginApi.saveSettings();

    if (pluginApi.mainInstance) {
      pluginApi.mainInstance.resetReminderTimers();
    }
  }
}
