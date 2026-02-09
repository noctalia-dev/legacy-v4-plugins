import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 700 * Style.uiScaleRatio
  property real contentPreferredHeight: 500 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent
  property ListModel filteredTodosModel: ListModel {}
  property bool showCompleted: false
  property var rawTodos: []
  property int currentPageId: 0
  property bool showEmptyState: false
  property bool detailsEditMode: false

  // Define a function to schedule reloading of todos
  function scheduleReload() {
    Qt.callLater(loadTodos);
  }

  // Bind rawTodos, showCompleted, and currentPageId to plugin settings
  Binding {
    target: root
    property: "rawTodos"
    value: pluginApi?.pluginSettings?.todos || []
  }

  Binding {
    target: root
    property: "showCompleted"
    value: pluginApi?.pluginSettings?.showCompleted !== undefined
         ? pluginApi.pluginSettings.showCompleted
         : pluginApi?.manifest?.metadata?.defaultSettings?.showCompleted || false
  }

  Binding {
    target: root
    property: "currentPageId"
    value: pluginApi?.pluginSettings?.current_page_id || 0
  }

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("Todo", "Panel initialized");
    }
  }

  onPluginApiChanged: {
    if (pluginApi) {
      loadTodos();
    }
  }

  // Listen for changes that affect the todo list display
  onRawTodosChanged: scheduleReload()
  onCurrentPageIdChanged: scheduleReload()
  onShowCompletedChanged: scheduleReload()

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginL

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            spacing: Style.marginM

            NIcon {
              icon: "clipboard-check"
              pointSize: Style.fontSizeXL
            }

            NText {
              text: pluginApi?.tr("panel.header.title")
              font.pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item {
              Layout.fillWidth: true
            }

            NButton {
              enabled: (pluginApi.pluginSettings.completedCount > 0)
              text: pluginApi?.tr("panel.header.clear_completed_button")
              icon: "trash"
              fontSize: Style.fontSizeS
              onClicked: {
                clearCompletedTodos();
              }
            }
          }

          // Page selector using tab components
          NTabBar {
            id: tabBar
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            distributeEvenly: true
            currentIndex: currentPageIndex

            // Track current page index
            property int currentPageIndex: {
              var pages = pluginApi?.pluginSettings?.pages || [];
              var currentId = pluginApi?.pluginSettings?.current_page_id || 0;
              for (var i = 0; i < pages.length; i++) {
                if (pages[i].id === currentId) {
                  return i;
                }
              }
              return 0;
            }

            // Dynamically create tabs based on pages
            Repeater {
              model: pluginApi?.pluginSettings?.pages || []

              delegate: NTabButton {
                id: tabButton
                text: modelData.name
                tabIndex: index
                checked: index === tabBar.currentIndex

                Component.onCompleted: {
                  topLeftRadius = Style.iRadiusM;
                  bottomLeftRadius = Style.iRadiusM;
                  topRightRadius = Style.iRadiusM;
                  bottomRightRadius = Style.iRadiusM;
                }

                onClicked: {
                  pluginApi.pluginSettings.current_page_id = modelData.id;
                  pluginApi.saveSettings();
                }
              }
            }
          }


          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
              spacing: Style.marginS
              Layout.bottomMargin: Style.marginM

              NTextInput {
                id: newTodoInput
                placeholderText: pluginApi?.tr("panel.add_todo.placeholder")
                Layout.fillWidth: true
                Keys.onReturnPressed: addTodo()
              }

              // Priority selector using a simplified approach
              Item {
                Layout.preferredWidth: 120
                Layout.preferredHeight: Style.baseWidgetSize

                Rectangle {
                  anchors.fill: parent
                  color: "transparent"
                  border.color: Color.mOutline
                  border.width: 1
                  radius: Style.iRadiusS

                  Row {
                    anchors.fill: parent
                    spacing: 1

                    Rectangle {
                      id: highPriorityBtn
                      width: (parent.width - 2) / 3
                      height: parent.height
                      color: priorityGroup.currentPriority === "high" ? getPriorityColor("high") : "transparent"
                      radius: Style.iRadiusS

                      NText {
                        anchors.centerIn: parent
                        text: "H"
                        color: priorityGroup.currentPriority === "high" ? Color.mOnPrimary : getPriorityColor("high")
                        font.pointSize: Style.fontSizeS
                      }

                      MouseArea {
                        anchors.fill: parent
                        onClicked: priorityGroup.currentPriority = "high"
                      }
                    }

                    Rectangle {
                      id: mediumPriorityBtn
                      width: (parent.width - 2) / 3
                      height: parent.height
                      color: priorityGroup.currentPriority === "medium" ? getPriorityColor("medium") : "transparent"
                      radius: Style.iRadiusS

                      NText {
                        anchors.centerIn: parent
                        text: "M"
                        color: priorityGroup.currentPriority === "medium" ? Color.mOnPrimary : getPriorityColor("medium")
                        font.pointSize: Style.fontSizeS
                      }

                      MouseArea {
                        anchors.fill: parent
                        onClicked: priorityGroup.currentPriority = "medium"
                      }
                    }

                    Rectangle {
                      id: lowPriorityBtn
                      width: parent.width - (highPriorityBtn.width + mediumPriorityBtn.width + 2)
                      height: parent.height
                      color: priorityGroup.currentPriority === "low" ? getPriorityColor("low") : "transparent"
                      radius: Style.iRadiusS

                      NText {
                        anchors.centerIn: parent
                        text: "L"
                        color: priorityGroup.currentPriority === "low" ? Color.mOnPrimary : getPriorityColor("low")
                        font.pointSize: Style.fontSizeS
                      }

                      MouseArea {
                        anchors.fill: parent
                        onClicked: priorityGroup.currentPriority = "low"
                      }
                    }
                  }
                }
              }

              // Define the priority group as a separate object
              QtObject {
                id: priorityGroup
                property string currentPriority: "medium"
              }

              NIconButton {
                icon: "plus"
                onClicked: {
                  addTodo();
                  priorityGroup.currentPriority = "medium"; // Reset to default after adding
                }
              }
            }

            ListView {
              id: todoListView
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: root.filteredTodosModel
              spacing: Style.marginS
              boundsBehavior: Flickable.StopAtBounds
              flickableDirection: Flickable.VerticalFlick

              delegate: Item {
                id: delegateItem
                width: ListView.view.width
                height: Style.baseWidgetSize + Style.marginS

                required property int index
                required property var modelData

                // Properties for drag functionality
                property bool dragging: false
                property int dragStartY: 0
                property int dragStartIndex: -1
                property int dragTargetIndex: -1
                property int itemSpacing: Style.marginS

                // Properties for edit functionality
                property bool editing: false
                property string originalText: ""

                // Methods for edit functionality
                function startEdit() {
                  editing = true;
                  originalText = modelData.text;
                }

                function saveEdit() {
                  if (pluginApi && todoTextEdit.text.trim() !== "") {
                    var todos = pluginApi.pluginSettings.todos || [];

                    updateTodo(modelData.id, {
                      text: todoTextEdit.text.trim()
                    });

                    pluginApi.pluginSettings.todos = pluginApi.pluginSettings.todos;
                    pluginApi.saveSettings();
                  }
                  editing = false;
                }

                function cancelEdit() {
                  editing = false;
                  // Restore the original text when cancelling
                  if (todoTextEdit) {
                    todoTextEdit.text = originalText;
                  }
                }

                // Watch for editing property changes to handle focus
                onEditingChanged: {
                    if (editing) {
                        // Use a timer to delay the focus operation
                        var timer = Qt.createQmlObject("
                            import QtQuick 2.0;
                            Timer {
                                interval: 50;
                                running: true;
                                onTriggered: {
                                    if (todoTextEdit && todoTextEdit.input) {
                                        todoTextEdit.input.forceActiveFocus();
                                    }
                                }
                            }", delegateItem);
                    }
                }

                // Position binding for non-dragging state
                y: {
                  if (delegateItem.dragging) {
                    return delegateItem.y;
                  }

                  var draggedIndex = -1;
                  var targetIndex = -1;
                  for (var i = 0; i < todoListView.count; i++) {
                    var item = todoListView.itemAtIndex(i);
                    if (item && item.dragging) {
                      draggedIndex = item.dragStartIndex;
                      targetIndex = item.dragTargetIndex;
                      break;
                    }
                  }

                  // If an item is being dragged, adjust positions
                  if (draggedIndex !== -1 && targetIndex !== -1 && draggedIndex !== targetIndex) {
                    var currentIndex = delegateItem.index;

                    if (draggedIndex < targetIndex) {
                      if (currentIndex > draggedIndex && currentIndex <= targetIndex) {
                        return (currentIndex - 1) * (delegateItem.height + delegateItem.itemSpacing);
                      }
                    } else {
                      if (currentIndex >= targetIndex && currentIndex < draggedIndex) {
                        return (currentIndex + 1) * (delegateItem.height + delegateItem.itemSpacing);
                      }
                    }
                  }

                  return delegateItem.index * (delegateItem.height + delegateItem.itemSpacing);
                }

                // Behavior for smooth animation when not dragging
                Behavior on y {
                  enabled: !delegateItem.dragging
                  NumberAnimation {
                    duration: Style.animationNormal
                    easing.type: Easing.OutQuad
                  }
                }

                // The actual todo item rectangle
                Rectangle {
                  anchors.fill: parent
                  color: Color.mSurface
                  radius: Style.radiusS

                  // Mouse area for clicking the entire item to view details
                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      if (!delegateItem.editing) {
                        root.openTodoDetails(modelData);
                      }
                    }
                  }

                  RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.marginM
                    anchors.rightMargin: Style.marginM
                    spacing: Style.marginS

                    // Drag handle
                    Item {
                      id: dragHandle

                      Layout.preferredWidth: Style.baseWidgetSize * 0.5
                      Layout.preferredHeight: Style.baseWidgetSize * 0.8

                      NIcon {
                        id: dragHandleIcon
                        anchors.centerIn: parent
                        icon: "grip-vertical"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                        opacity: 0.5

                        states: [
                          State {
                            name: "hovered"
                            when: dragHandleMouseArea.containsMouse
                            PropertyChanges {
                              target: dragHandleIcon
                              opacity: 1.0
                              color: Color.mOnSurface
                            }
                          }
                        ]

                        transitions: [
                          Transition {
                            from: "*"; to: "hovered"
                            NumberAnimation { properties: "opacity"; duration: 150 }
                          },
                          Transition {
                            from: "hovered"; to: "*"
                            NumberAnimation { properties: "opacity"; duration: 150 }
                          }
                        ]
                      }

                      MouseArea {
                        id: dragHandleMouseArea

                        anchors.fill: parent
                        cursorShape: Qt.SizeVerCursor
                        hoverEnabled: true
                        preventStealing: false
                        z: 1000

                        onPressed: mouse => {
                                      delegateItem.dragStartIndex = delegateItem.index;
                                      delegateItem.dragTargetIndex = delegateItem.index;
                                      delegateItem.dragStartY = delegateItem.y;
                                      delegateItem.dragging = true;
                                      delegateItem.z = 999;

                                      // Signal that interaction started (prevents panel close)
                                      preventStealing = true;
                                    }

                        onPositionChanged: mouse => {
                                              if (delegateItem.dragging) {
                                                var dy = mouse.y - dragHandle.height / 2;
                                                var newY = delegateItem.y + dy;

                                                // Constrain within bounds
                                                newY = Math.max(0, Math.min(newY, todoListView.contentHeight - delegateItem.height));
                                                delegateItem.y = newY;

                                                // Calculate target index (but don't apply yet)
                                                var targetIndex = Math.floor((newY + delegateItem.height / 2) / (delegateItem.height + delegateItem.itemSpacing));
                                                targetIndex = Math.max(0, Math.min(targetIndex, todoListView.count - 1));

                                                delegateItem.dragTargetIndex = targetIndex;
                                              }
                                            }

                        onReleased: {
                          // Apply the model change now that drag is complete
                          if (delegateItem.dragStartIndex !== -1 && delegateItem.dragTargetIndex !== -1 && delegateItem.dragStartIndex !== delegateItem.dragTargetIndex) {
                            moveTodoItem(delegateItem.dragStartIndex, delegateItem.dragTargetIndex);
                          }

                          delegateItem.dragging = false;
                          delegateItem.dragStartIndex = -1;
                          delegateItem.dragTargetIndex = -1;
                          delegateItem.z = 0;

                          // Reset interaction prevention
                          preventStealing = false;
                        }

                        onCanceled: {
                          // Handle cancel (e.g., ESC key pressed during drag)
                          delegateItem.dragging = false;
                          delegateItem.dragStartIndex = -1;
                          delegateItem.dragTargetIndex = -1;
                          delegateItem.z = 0;

                          // Reset interaction prevention
                          preventStealing = false;
                        }
                      }
                    }

                    // Priority indicator - a colored vertical line
                    Rectangle {
                      id: priorityIndicator
                      Layout.preferredWidth: 4  // Width of the priority line
                      Layout.preferredHeight: parent.height - Style.marginS
                      Layout.alignment: Qt.AlignVCenter  // Align vertically centered
                      radius: 2

                      // Determine color based on priority using helper function
                      color: {
                        if (pluginApi) {
                          return getPriorityColor(modelData.priority || "medium");
                        } else {
                          // Fallback to default colors if pluginApi is not ready
                          var priority = modelData.priority || "medium";
                          if (priority === "high") {
                            return Color.mError;
                          } else if (priority === "low") {
                            return Color.mOnSurfaceVariant;
                          } else {
                            return Color.mPrimary;
                          }
                        }
                      }
                    }

                    // Checkbox
                    Item {
                      Layout.preferredWidth: Style.baseWidgetSize * 0.7
                      Layout.preferredHeight: Style.baseWidgetSize * 0.7

                      Rectangle {
                        id: box

                        anchors.fill: parent
                        radius: Style.iRadiusXS
                        color: modelData.completed ? Color.mPrimary : Color.mSurface
                        border.color: Color.mOutline
                        border.width: Style.borderS

                        Behavior on color {
                          ColorAnimation {
                            duration: Style.animationFast
                          }
                        }

                        NIcon {
                          visible: modelData.completed
                          anchors.centerIn: parent
                          anchors.horizontalCenterOffset: -1
                          icon: "check"
                          color: Color.mOnPrimary
                          pointSize: Math.max(Style.fontSizeXS, Style.baseWidgetSize * 0.7 * 0.5)
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            toggleTodo(modelData.id, modelData.completed);
                          }
                        }
                      }
                    }

                    // Text container (using Layout to fit in the RowLayout)
                    Item {
                      Layout.fillWidth: true
                      Layout.preferredHeight: parent.height

                      // Normal text display
                      NText {
                        id: todoTextDisplay
                        visible: !delegateItem.editing
                        text: modelData.text
                        color: modelData.completed ? Color.mOnSurfaceVariant : Color.mOnSurface
                        font.strikeout: modelData.completed
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginS
                        anchors.rightMargin: Style.marginS
                      }

                      // Edit text field - Using TextField directly to have more control
                      Item {
                        id: todoTextEditContainer
                        visible: delegateItem.editing
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginS
                        anchors.rightMargin: Style.baseWidgetSize * 0.4
                        height: parent.height * 0.8
                        anchors.verticalCenter: parent.verticalCenter

                        TextField {
                          id: todoTextEdit
                          anchors.fill: parent
                          anchors.rightMargin: Style.baseWidgetSize * 0.8
                          text: modelData.text

                          verticalAlignment: TextInput.AlignVCenter

                          echoMode: TextInput.Normal
                          color: Color.mOnSurface
                          placeholderTextColor: Qt.alpha(Color.mOnSurfaceVariant, 0.6)

                          selectByMouse: true

                          topPadding: 0
                          bottomPadding: 0
                          leftPadding: Style.marginS
                          rightPadding: Style.baseWidgetSize * 0.6

                          font.family: Settings.data.ui.fontDefault
                          font.pointSize: Style.fontSizeS * Style.uiScaleRatio
                          font.weight: Style.fontWeightRegular

                          // Remove the frame/background to eliminate border
                          background: null

                          Keys.onReturnPressed: {
                            delegateItem.saveEdit();
                          }

                          Keys.onEscapePressed: {
                            delegateItem.cancelEdit();
                          }

                          // Set focus when visible
                          onVisibleChanged: {
                            if (visible) {
                              Qt.callLater(function() {
                                todoTextEdit.forceActiveFocus();
                              });
                            }
                          }
                        }

                        // Clear button
                        Item {
                          implicitWidth: Style.baseWidgetSize * 1.1
                          implicitHeight: Style.baseWidgetSize * 1.1

                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.rightMargin: Style.marginM

                          visible: todoTextEdit.text.length > 0

                          NIcon {
                            id: clearButtonIcon
                            anchors.centerIn: parent
                            icon: "backspace"
                            pointSize: Style.fontSizeL
                            color: Color.mOnSurfaceVariant
                            opacity: 0.5

                            MouseArea {
                              id: clearMouseArea
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                todoTextEdit.clear();
                                todoTextEdit.forceActiveFocus();
                              }

                              states: [
                                State {
                                  name: "hovered"
                                  when: clearMouseArea.containsMouse
                                  PropertyChanges {
                                    target: clearButtonIcon
                                    opacity: 1.0
                                    color: Color.mError
                                  }
                                }
                              ]

                              transitions: [
                                Transition {
                                  from: "*"; to: "hovered"
                                  NumberAnimation { properties: "opacity"; duration: 150 }
                                },
                                Transition {
                                  from: "hovered"; to: "*"
                                  NumberAnimation { properties: "opacity"; duration: 150 }
                                }
                              ]
                            }
                          }
                        }
                      }
                    }

                    // Edit button (only show when not editing)
                    Item {
                      Layout.preferredWidth: Style.baseWidgetSize * 0.8
                      Layout.preferredHeight: parent.height
                      visible: !delegateItem.editing

                      Item {
                        id: editButtonContainer
                        anchors.centerIn: parent

                        implicitWidth: Style.baseWidgetSize * 0.8
                        implicitHeight: Style.baseWidgetSize * 0.8

                        NIcon {
                          id: editButtonIcon
                          anchors.centerIn: parent
                          icon: "pencil"
                          pointSize: Style.fontSizeM
                          color: Color.mOnSurfaceVariant
                          opacity: 0.5

                          MouseArea {
                            id: editMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              delegateItem.startEdit();
                            }
                          }

                          ToolTip {
                            id: editToolTip
                            text: pluginApi?.tr("panel.todo_item.edit_button_tooltip")
                            delay: 1000
                            parent: editButtonIcon
                            visible: editMouseArea.containsMouse

                            contentItem: NText {
                              text: editToolTip.text
                              color: Color.mOnPrimary
                              font.pointSize: Style.fontSizeXS
                            }

                            background: Rectangle {
                              color: Color.mPrimary
                              radius: Style.iRadiusS
                              border.color: Qt.rgba(0, 0, 0, 0.2)
                              border.width: 1
                            }
                          }

                          states: [
                            State {
                              name: "hovered"
                              when: editMouseArea.containsMouse
                              PropertyChanges {
                                target: editButtonIcon
                                opacity: 1.0
                                color: Color.mPrimary
                              }
                            }
                          ]

                          transitions: [
                            Transition {
                              from: "*"; to: "hovered"
                              NumberAnimation { properties: "opacity"; duration: 150 }
                            },
                            Transition {
                              from: "hovered"; to: "*"
                              NumberAnimation { properties: "opacity"; duration: 150 }
                            }
                          ]
                        }
                      }
                    }

                    // Save/Cancel buttons (only show when editing)
                    Item {
                      implicitWidth: Style.baseWidgetSize * 0.8
                      implicitHeight: Style.baseWidgetSize * 0.8
                      visible: delegateItem.editing

                      RowLayout {
                        id: editButtonsRow
                        anchors.centerIn: parent
                        spacing: Style.baseWidgetSize * 0.1

                        // Save button
                        Item {
                          implicitWidth: Style.baseWidgetSize * 1.0
                          implicitHeight: Style.baseWidgetSize * 1.0

                          NIcon {
                            id: saveButtonIcon
                            anchors.centerIn: parent
                            icon: "check"
                            pointSize: Style.fontSizeM
                            color: Color.mOnSurfaceVariant
                            opacity: 0.5

                            MouseArea {
                              id: saveMouseArea
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                delegateItem.saveEdit();
                              }

                              states: [
                                State {
                                  name: "hovered"
                                  when: saveMouseArea.containsMouse
                                  PropertyChanges {
                                    target: saveButtonIcon
                                    opacity: 1.0
                                    color: Color.mPrimary
                                  }
                                }
                              ]

                              transitions: [
                                Transition {
                                  from: "*"; to: "hovered"
                                  NumberAnimation { properties: "opacity"; duration: 150 }
                                },
                                Transition {
                                  from: "hovered"; to: "*"
                                  NumberAnimation { properties: "opacity"; duration: 150 }
                                }
                              ]
                            }
                          }
                        }

                        // Cancel button
                        Item {
                          implicitWidth: Style.baseWidgetSize * 1.0
                          implicitHeight: Style.baseWidgetSize * 1.0

                          NIcon {
                            id: cancelButtonIcon
                            anchors.centerIn: parent
                            icon: "x"
                            pointSize: Style.fontSizeM
                            color: Color.mOnSurfaceVariant
                            opacity: 0.5

                            MouseArea {
                              id: cancelMouseArea
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                delegateItem.cancelEdit();
                              }

                              states: [
                                State {
                                  name: "hovered"
                                  when: cancelMouseArea.containsMouse
                                  PropertyChanges {
                                    target: cancelButtonIcon
                                    opacity: 1.0
                                    color: Color.mOnSurface
                                  }
                                }
                              ]

                              transitions: [
                                Transition {
                                  from: "*"; to: "hovered"
                                  NumberAnimation { properties: "opacity"; duration: 150 }
                                },
                                Transition {
                                  from: "hovered"; to: "*"
                                  NumberAnimation { properties: "opacity"; duration: 150 }
                                }
                              ]
                            }
                          }
                        }
                      }
                    }

                    // Delete button
                    Item {
                      id: deleteButtonContainer
                      implicitWidth: Style.baseWidgetSize * 0.8
                      implicitHeight: Style.baseWidgetSize * 0.8

                      NIcon {
                        id: deleteButtonIcon
                        anchors.centerIn: parent
                        icon: "x"
                        pointSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                        opacity: 0.5
                        visible: !delegateItem.editing

                        MouseArea {
                          id: mouseArea
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            removeTodo(modelData.id);
                          }
                        }

                        ToolTip {
                          id: deleteToolTip
                          text: pluginApi?.tr("panel.todo_item.delete_button_tooltip")
                          delay: 1000
                          parent: deleteButtonIcon
                          visible: mouseArea.containsMouse

                          contentItem: NText {
                            text: deleteToolTip.text
                            color: Color.mOnError
                            font.pointSize: Style.fontSizeXS
                          }

                          background: Rectangle {
                            color: Color.mError
                            radius: Style.iRadiusS
                            border.color: Qt.rgba(0, 0, 0, 0.2)
                            border.width: 1
                          }
                        }

                        states: [
                          State {
                            name: "hovered"
                            when: mouseArea.containsMouse
                            PropertyChanges {
                              target: deleteButtonIcon
                              opacity: 1.0
                              color: Color.mError
                            }
                          }
                        ]

                        transitions: [
                          Transition {
                            from: "*"; to: "hovered"
                            NumberAnimation { properties: "opacity"; duration: 150 }
                          },
                          Transition {
                            from: "hovered"; to: "*"
                            NumberAnimation { properties: "opacity"; duration: 150 }
                          }
                        ]
                      }
                    }
                  }
                }
              }

              highlightRangeMode: ListView.NoHighlightRange
              preferredHighlightBegin: 0
              preferredHighlightEnd: 0

              header: null
            }

            // Empty state overlay - using a separate container that doesn't interfere with layout
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignCenter
              visible: root.filteredTodosModel.count === 0 && root.showEmptyState

              NText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -100
                text: pluginApi?.tr("panel.empty_state.message")
                color: Color.mOnSurfaceVariant
                font.pointSize: Style.fontSizeM
                font.weight: Font.Normal
              }
            }
          }
        }
      }
    }
  }

   // Dialog for displaying todo details
   Popup {
     id: detailDialog

     property var todoId: 0
     property string todoText: ""
     property bool todoCompleted: false
     property string todoCreatedAt: ""
     property int todoPageId: 0
      property string todoPriority: "medium"
      property string todoDetails: ""

     x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: 500 * Style.uiScaleRatio
    height: 300 * Style.uiScaleRatio
    modal: true
    focus: true
    padding: 0

    // Background
    background: Rectangle {
      color: Color.mSurface
      radius: Style.radiusL
      border.color: Color.mOutline
      border.width: 1
    }

    // Content
    contentItem: Item {
      anchors.fill: parent

      // Header bar
      Rectangle {
        id: headerBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44 * Style.uiScaleRatio
        color: Color.mPrimary
        radius: Style.radiusS

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.marginL
          anchors.rightMargin: Style.marginM

          NText {
            text: pluginApi?.tr("panel.todo_details.title")
            font.pointSize: Style.fontSizeM
            font.weight: Font.Bold
            color: Color.mOnPrimary
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "x"
            colorBg: Qt.rgba(1, 1, 1, 0.2)
            colorBgHover: Qt.rgba(1, 1, 1, 0.3)
            colorFg: Color.mOnPrimary
            onClicked: detailDialog.close()
          }
        }
      }

      // Scrollable content (below header)
      Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + Style.marginL
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
          id: contentColumn
          anchors.fill: parent
          anchors.leftMargin: Style.marginL
          anchors.rightMargin: Style.marginL
          anchors.topMargin: Style.marginM
          anchors.bottomMargin: Style.marginM
          spacing: Style.marginM

          // Todo text
          NText {
            text: detailDialog.todoText
            font.pointSize: Style.fontSizeL
            font.weight: Font.Bold
            color: Color.mOnSurface
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }

            // Details section with add/edit button
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              // Divider before details
              Rectangle {
                height: 1
                color: Color.mOutline
                opacity: 0.3
                Layout.fillWidth: true
              }

              // Label + Add/Edit button row
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: pluginApi?.tr("panel.todo_details.label_details")
                  font.pointSize: Style.fontSizeS
                  color: Color.mOnSurfaceVariant
                  Layout.preferredWidth: 80 * Style.uiScaleRatio
                  Layout.alignment: Qt.AlignVCenter
                }

                // Spacer to push button to the right
                Item {
                  Layout.fillWidth: true
                }

                NButton {
                  text: detailDialog.todoDetails.length > 0 ?
                        pluginApi?.tr("panel.todo_details.button_edit_details"):
                        pluginApi?.tr("panel.todo_details.button_add_details")
                  icon: "pencil"
                  backgroundColor: Color.mSurfaceVariant
                  textColor: Color.mOnSurface
                  fontSize: Style.fontSizeS
                  outlined: true
                  onClicked: {
                    detailsEditMode = true;
                    Qt.callLater(function() {
                      detailsTextArea.text = detailDialog.todoDetails;
                      detailsTextArea.forceActiveFocus();
                    });
                  }
                }
              }

              // View mode (show details if not empty)
              NText {
                text: detailDialog.todoDetails
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurface
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: detailDialog.todoDetails.length > 0 && !detailsEditMode
              }

              // Edit mode (TextArea)
              TextArea {
                id: detailsTextArea
                visible: detailsEditMode
                text: detailDialog.todoDetails
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                wrapMode: TextArea.Wrap
                color: Color.mOnSurface
                background: Rectangle {
                  color: Color.mSurfaceVariant
                  radius: Style.iRadiusS
                }
                Keys.onEscapePressed: {
                  detailsEditMode = false;
                }
              }

              // Save/Cancel buttons for details edit
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS
                visible: detailsEditMode

                NButton {
                  text: pluginApi?.tr("panel.todo_details.button_save")
                  backgroundColor: Color.mPrimary
                  onClicked: {
                    updateTodo(detailDialog.todoId, { details: detailsTextArea.text });
                    pluginApi.saveSettings();
                    detailDialog.todoDetails = detailsTextArea.text;
                    detailsEditMode = false;
                  }
                }

                NButton {
                  text: pluginApi?.tr("panel.todo_details.button_cancel")
                  backgroundColor: Color.mSurfaceVariant
                  onClicked: {
                    detailsEditMode = false;
                  }
                }
              }
            }

          // Divider
          Rectangle {
            height: 1
            color: Color.mOutline
            opacity: 0.3
            Layout.fillWidth: true
          }

          // Details
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            // Page
            RowLayout {
              spacing: Style.marginS
              Layout.fillWidth: true

              NText {
                text: pluginApi?.tr("panel.todo_details.label_page")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 80 * Style.uiScaleRatio
                Layout.alignment: Qt.AlignTop
              }

              NText {
                text: getPageName(detailDialog.todoPageId)
                font.pointSize: Style.fontSizeS
                font.weight: Font.Medium
                color: Color.mOnSurface
                Layout.alignment: Qt.AlignTop
              }
            }

            // Status
            RowLayout {
              spacing: Style.marginS
              Layout.fillWidth: true

              NText {
                text: pluginApi?.tr("panel.todo_details.label_status")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 80 * Style.uiScaleRatio
                Layout.alignment: Qt.AlignTop
              }

              NText {
                text: detailDialog.todoCompleted ?
                       pluginApi?.tr("panel.todo_details.status_completed") :
                       pluginApi?.tr("panel.todo_details.status_pending")
                font.pointSize: Style.fontSizeS
                font.weight: Font.Medium
                color: detailDialog.todoCompleted ? Color.mPrimary : Color.mError
                Layout.alignment: Qt.AlignTop
              }
            }

            // Priority
            RowLayout {
              spacing: Style.marginS
              Layout.fillWidth: true

              NText {
                text: pluginApi?.tr("panel.todo_details.label_priority")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 82 * Style.uiScaleRatio
                Layout.alignment: Qt.AlignTop
              }

              RowLayout {
                spacing: Style.marginXS

                Rectangle {
                  width: 12
                  height: 12
                  radius: 6
                  color: root.getPriorityColor(detailDialog.todoPriority)
                }

                NText {
                  text: detailDialog.todoPriority.charAt(0).toUpperCase() + detailDialog.todoPriority.slice(1)
                  font.pointSize: Style.fontSizeS
                  font.weight: Font.Medium
                  color: Color.mOnSurface
                }
              }
            }

            // Created date
            RowLayout {
              spacing: Style.marginS
              Layout.fillWidth: true

              NText {
                text: pluginApi?.tr("panel.todo_details.label_created")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                Layout.preferredWidth: 80 * Style.uiScaleRatio
                Layout.alignment: Qt.AlignTop
              }

              NText {
                text: new Date(detailDialog.todoCreatedAt).toLocaleString()
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurface
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
              }
            }
          }
        }
      }
    }
  }

  function addTodo() {
    var text = newTodoInput.text.trim();
    if (!text || !pluginApi) return;

    var todos = pluginApi.pluginSettings.todos || [];
    var currentPageId = pluginApi.pluginSettings.current_page_id || 0;

    todos.unshift({
      id: Date.now(),
      text: text,
      completed: false,
      createdAt: new Date().toISOString(),
      pageId: currentPageId,
      priority: priorityGroup.currentPriority,
      details: ""
    });

    pluginApi.pluginSettings.todos = todos;
    pluginApi.pluginSettings.count = todos.length;
    pluginApi.pluginSettings.completedCount = calculateCompletedCount();
    pluginApi.saveSettings();
    newTodoInput.text = "";
  }

  // Internal utility functions
  function updateTodo(todoId, updates) {
    if (!pluginApi) return false;

    var todos = pluginApi.pluginSettings.todos || [];
    for (var i = 0; i < todos.length; i++) {
      if (todos[i].id === todoId) {
        if (updates.text !== undefined) todos[i].text = updates.text;
        if (updates.completed !== undefined) todos[i].completed = updates.completed;
        if (updates.priority !== undefined) todos[i].priority = updates.priority;
        if (updates.details !== undefined) todos[i].details = updates.details;
        return true;
      }
    }
    return false;
  }

  // Helper function to remove a todo by ID
  function removeTodo(todoId) {
    if (!pluginApi) {
      Logger.e("Todo", "pluginApi is null, cannot delete todo");
      return false;
    }

    var todos = pluginApi.pluginSettings.todos || [];
    var indexToRemove = -1;

    for (var i = 0; i < todos.length; i++) {
      if (todos[i].id === todoId) {
        indexToRemove = i;
        break;
      }
    }

    if (indexToRemove !== -1) {
      todos.splice(indexToRemove, 1);

      pluginApi.pluginSettings.count = todos.length;
      pluginApi.pluginSettings.completedCount = calculateCompletedCount();

      pluginApi.saveSettings();

      return true;
    } else {
      Logger.e("Todo", "Todo with ID " + todoId + " not found for deletion");
      return false;
    }
  }

  // Helper function to toggle todo completion status
  function toggleTodo(todoId, currentCompletedStatus) {
    if (!pluginApi) {
      Logger.e("Todo", "pluginApi is null, cannot toggle todo");
      return false;
    }

    // Use the existing updateTodo function to update only the completion status
    var success = updateTodo(todoId, {
      completed: !currentCompletedStatus
    });

    if (success) {
      pluginApi.pluginSettings.completedCount = calculateCompletedCount();

      moveTodoToCorrectPosition(todoId);

      pluginApi.saveSettings();
      return true;
    } else {
      Logger.e("Todo", "Failed to toggle todo with ID " + todoId);
      return false;
    }
  }

  // Helper function to clear completed todos for the current page
  function clearCompletedTodos() {
    if (!pluginApi) {
      Logger.e("Todo", "pluginApi is null, cannot clear completed todos");
      return false;
    }

    var todos = pluginApi.pluginSettings.todos || [];
    var currentPageId = pluginApi.pluginSettings.current_page_id || 0;

    // Only clear completed todos for the current page
    var activeTodos = todos.filter(function(todo) {
      return !(todo.completed && todo.pageId === currentPageId);
    });

    pluginApi.pluginSettings.todos = activeTodos;

    // Update counts
    pluginApi.pluginSettings.completedCount = calculateCompletedCount();
    pluginApi.pluginSettings.count = activeTodos.length;

    pluginApi.saveSettings();
    return true;
  }

  function calculateCompletedCount() {
    if (!pluginApi) return 0;

    var todos = pluginApi.pluginSettings.todos || [];
    var completedCount = 0;
    for (var j = 0; j < todos.length; j++) {
      if (todos[j].completed) {
        completedCount++;
      }
    }
    return completedCount;
  }

  function findPageIndexInTodos(pageTodos, targetItem) {
    for (var i = 0; i < pageTodos.length; i++) {
      if (pageTodos[i].id === targetItem.id) {
        return i;
      }
    }
    return -1;
  }

  function moveTodoItem(fromIndex, toIndex) {
    if (fromIndex === toIndex)
      return;

    var currentPageId = pluginApi?.pluginSettings?.current_page_id || 0;
    var pluginTodos = root.rawTodos;

    // Filter todos for the current page
    var pageTodos = pluginTodos.filter(function(todo) {
      return todo.pageId === currentPageId;
    });

    if (fromIndex < 0 || fromIndex >= pageTodos.length)
      return;
    if (toIndex < 0 || toIndex >= pageTodos.length)
      return;

    // Create a copy of the full todos array
    var newTodos = pluginTodos.slice();

    // Find the item in the full array using the fromIndex from the pageTodos
    var itemToMove = pageTodos[fromIndex];

    // Find the index of this item in the full array
    var fromGlobalIndex = -1;
    for (var i = 0; i < newTodos.length; i++) {
      if (newTodos[i].id === itemToMove.id) {
        fromGlobalIndex = i;
        break;
      }
    }

    if (fromGlobalIndex === -1) return;

    // Remove the item from its current position
    var movedItem = newTodos.splice(fromGlobalIndex, 1)[0];

    // Find the target position in the full array
    var toGlobalIndex = -1;

    // If moving down, we need to account for the item being removed
    if (fromIndex < toIndex) {
      // Adjust target index since we removed an item before the target
      var adjustedPageIndex = toIndex;
      var count = 0;
      for (var i = 0; i < newTodos.length; i++) {
        if (newTodos[i].pageId === currentPageId) {
          if (count === adjustedPageIndex) {
            toGlobalIndex = i;
            break;
          }
          count++;
        }
      }
    } else {
      // Moving up, target position stays the same relative to global array
      var count = 0;
      for (var i = 0; i < newTodos.length; i++) {
        if (newTodos[i].pageId === currentPageId) {
          if (count === toIndex) {
            toGlobalIndex = i;
            break;
          }
          count++;
        }
      }
    }

    // Insert the item at the new position
    if (toGlobalIndex === -1) {
      // If target index is at the end of the page's items
      var lastPageIndex = -1;
      var count = 0;
      for (var i = 0; i < newTodos.length; i++) {
        if (newTodos[i].pageId === currentPageId) {
          lastPageIndex = i;
          count++;
        }
      }
      if (count === toIndex + 1) {
        toGlobalIndex = lastPageIndex + 1;
      } else {
        return;
      }
    }

    newTodos.splice(toGlobalIndex, 0, movedItem);

    // Update the plugin settings
    if (pluginApi) {
      pluginApi.pluginSettings.todos = newTodos;
      pluginApi.saveSettings();
    }
  }

  function moveTodoToCorrectPosition(todoId) {
    if (!pluginApi) return;

    var todos = pluginApi.pluginSettings.todos || [];
    var currentPageId = pluginApi?.pluginSettings?.current_page_id || 0;

    var todoIndex = -1;
    for (var i = 0; i < todos.length; i++) {
      if (todos[i].id === todoId) {
        todoIndex = i;
        break;
      }
    }

    if (todoIndex === -1) return;

    var movedTodo = todos[todoIndex];

    // Only reorder if todo belongs to current page
    if (movedTodo.pageId !== currentPageId) return;

    todos.splice(todoIndex, 1);

    if (movedTodo.completed) {
      // Place completed items at the end of the page
      var insertIndex = todos.length;
      for (var j = todos.length - 1; j >= 0; j--) {
        if (todos[j].pageId === currentPageId && todos[j].completed) {
          insertIndex = j + 1;
          break;
        }
      }
      todos.splice(insertIndex, 0, movedTodo);
    } else {
      // Place uncompleted items at the beginning of the page
      var insertIndex = 0;
      for (; insertIndex < todos.length; insertIndex++) {
        if (todos[insertIndex].pageId === currentPageId) {
          if (todos[insertIndex].completed) break;
        }
      }
      todos.splice(insertIndex, 0, movedTodo);
    }

    pluginApi.saveSettings();
  }

  // Helper function to get priority color
  function getPriorityColor(priority) {
    // Validate priority
    var validPriorities = ["high", "medium", "low"];
    if (!priority || validPriorities.indexOf(priority) === -1) {
      priority = "medium";
    }

    if (!pluginApi) {
      return getThemeColor(priority);
    }

    var useCustomColors = pluginApi?.pluginSettings?.useCustomColors;
    if (useCustomColors) {
      var customColors = pluginApi?.pluginSettings?.priorityColors;
      if (customColors && customColors[priority]) {
        return customColors[priority];
      }
    }

    return getThemeColor(priority);
  }

  // Helper function to get theme color
  function getThemeColor(priority) {
    if (priority === "high") return Color.mError;
    if (priority === "low") return Color.mOnSurfaceVariant;
    return Color.mPrimary;
  }

  // Helper function to get page name by ID
  function getPageName(pageId) {
    var pages = pluginApi?.pluginSettings?.pages || [];
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].id === pageId) {
        return pages[i].name;
      }
    }
    return "Unknown";
  }

   // Function to open the detailed view for a todo item
  function openTodoDetails(todo) {
    detailsEditMode = false;

    // Fill the detail dialog with the todo's information
    detailDialog.todoId = todo.id;
    detailDialog.todoText = todo.text;
    detailDialog.todoCompleted = todo.completed;
    detailDialog.todoCreatedAt = todo.createdAt;
    detailDialog.todoPageId = todo.pageId;
    detailDialog.todoPriority = todo.priority;
    detailDialog.todoDetails = todo.details || "";

    detailDialog.open();
  }

  function loadTodos() {
    // Store the current scroll position and visible item
    var currentScrollPos = todoListView ? todoListView.contentY : 0;
    var currentVisibleIndex = todoListView ? todoListView.currentIndex : -1;

    // Clear model
    filteredTodosModel.clear();

    var pluginTodos = root.rawTodos;
    var currentPageId = root.currentPageId;

    // Process todos in a single pass and populate models directly
    for (var i = 0; i < pluginTodos.length; i++) {
      var todo = pluginTodos[i];
      if (todo.pageId === currentPageId) {
        var todoItem = {
          id: todo.id,
          text: todo.text,
          completed: todo.completed === true,
          createdAt: todo.createdAt,
          pageId: todo.pageId,
          priority: todo.priority,
          details: todo.details
        };

        // Add to filtered model if applicable
        if (root.showCompleted || !todo.completed) {
          filteredTodosModel.append(todoItem);
        }
      }
    }

    // Restore the scroll position and visible item
    if (todoListView) {
      Qt.callLater(function() {
        if (currentVisibleIndex >= 0 && currentVisibleIndex < filteredTodosModel.count) {
          todoListView.positionViewAtIndex(currentVisibleIndex, ListView.Beginning);
        } else if (currentScrollPos > 0) {
          todoListView.contentY = currentScrollPos;
        }
      });
    }

    // Check if the model is empty
    root.showEmptyState = (filteredTodosModel.count === 0);

    // Restore the scroll position
    if (todoListView) {
      Qt.callLater(function() {
        todoListView.contentY = currentScrollPos;
      });
    }

    // Check if the model is empty
    root.showEmptyState = (filteredTodosModel.count === 0);
  }

}
