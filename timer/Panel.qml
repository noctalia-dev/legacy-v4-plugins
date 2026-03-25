import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Commons
import qs.Services.System
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: (compactMode ? 340 : 380) * Style.uiScaleRatio
  property real contentPreferredHeight: (compactMode ? 230 : 350) * Style.uiScaleRatio
  readonly property bool allowAttach: true



  readonly property bool compactMode: 
      pluginApi?.pluginSettings?.compactMode ?? 
      pluginApi?.manifest?.metadata?.defaultSettings?.compactMode ?? 
      false



  anchors.fill: parent
  
  readonly property var mainInstance: pluginApi?.mainInstance
  
  readonly property bool isRunning: mainInstance ? mainInstance.timerRunning : false
  property bool isStopwatchMode: mainInstance ? mainInstance.timerStopwatchMode : false
  readonly property int remainingSeconds: mainInstance ? mainInstance.timerRemainingSeconds : 0
  readonly property int totalSeconds: mainInstance ? mainInstance.timerTotalSeconds : 0
  readonly property int elapsedSeconds: mainInstance ? mainInstance.timerElapsedSeconds : 0
  readonly property bool soundPlaying: mainInstance ? mainInstance.timerSoundPlaying : false
  
  function startTimer() { if (mainInstance) mainInstance.timerStart(); }
  function pauseTimer() { if (mainInstance) mainInstance.timerPause(); }
  function resetTimer() { 
      if (mainInstance) {
          mainInstance.timerReset();
          // Do not apply default duration here. User wants 00:00:00 on reset.
      }
  }
  
  function setTimerStopwatchMode(mode) { 
    if (mainInstance) {
      mainInstance.timerStopwatchMode = mode;
    } 
  }
  
  function setTimerRemainingSeconds(seconds) {
      if (mainInstance) mainInstance.cdRemainingSeconds = seconds;
  }

  function formatTime(seconds, totalTimeSeconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;

    if (seconds === 0 && totalTimeSeconds > 0) {
      return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    if (!totalTimeSeconds || totalTimeSeconds === 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    if (totalTimeSeconds < 3600) {
      return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  function formatTimeFromDigits(digits) {
    const len = digits.length;
    let seconds = 0;
    let minutes = 0;
    let hours = 0;

    if (len > 0) {
      seconds = parseInt(digits.substring(Math.max(0, len - 2))) || 0;
    }
    if (len > 2) {
      minutes = parseInt(digits.substring(Math.max(0, len - 4), len - 2)) || 0;
    }
    if (len > 4) {
      hours = parseInt(digits.substring(0, len - 4)) || 0;
    }

    seconds = Math.min(59, seconds);
    minutes = Math.min(59, minutes);
    hours = Math.min(99, hours);

    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  function parseDigitsToTime(digits) {
    const len = digits.length;
    let seconds = 0;
    let minutes = 0;
    let hours = 0;

    if (len > 0) {
      seconds = parseInt(digits.substring(Math.max(0, len - 2))) || 0;
    }
    if (len > 2) {
      minutes = parseInt(digits.substring(Math.max(0, len - 4), len - 2)) || 0;
    }
    if (len > 4) {
      hours = parseInt(digits.substring(0, len - 4)) || 0;
    }

    seconds = Math.min(59, seconds);
    minutes = Math.min(59, minutes);
    hours = Math.min(99, hours);

    setTimerRemainingSeconds((hours * 3600) + (minutes * 60) + seconds);
  }

  Component.onCompleted: {
      // Do not auto-set default duration on load
  }

  function applyTimeFromBuffer() {
    if (timerDisplayItem.inputBuffer !== "") {
      parseDigitsToTime(timerDisplayItem.inputBuffer);
      timerDisplayItem.inputBuffer = "";
    }
  }

  onVisibleChanged: {
    if (visible) {
      if (!isRunning && !isStopwatchMode && totalSeconds === 0) {
        timerInput.forceActiveFocus();
      }
    }
  }

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

      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
          id: content
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM
          clip: true

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: isStopwatchMode ? "clock" : "hourglass"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            NText {
              text: pluginApi?.tr("panel.title") || "Timer"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }
          }

      Item {
        id: timerDisplayItem
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter

        property string inputBuffer: ""
        property bool isEditing: false

        WheelHandler {
          target: timerDisplayItem
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          enabled: !isRunning && !isStopwatchMode && totalSeconds === 0
          onWheel: function (event) {
            if (!enabled || !mainInstance) {
              return;
            }
            const step = 5;
            if (event.angleDelta.y > 0) {
              mainInstance.cdRemainingSeconds = Math.max(0, mainInstance.cdRemainingSeconds + step);
              event.accepted = true;
            } else if (event.angleDelta.y < 0) {
              mainInstance.cdRemainingSeconds = Math.max(0, mainInstance.cdRemainingSeconds - step);
              event.accepted = true;
            }
          }
        }

        Rectangle {
          id: textboxBorder
          anchors.centerIn: parent
          width: Math.max(timerInput.implicitWidth + Style.marginM * 2, parent.width * 0.8)
          height: timerInput.implicitHeight + Style.marginM * 2
          radius: Style.iRadiusM
          color: Color.mSurfaceVariant
          border.color: (timerInput.activeFocus || timerDisplayItem.isEditing) ? Color.mPrimary : Color.mOutline
          border.width: Style.borderS
          visible: !isRunning && !isStopwatchMode && totalSeconds === 0
          z: 0

          Behavior on border.color {
            ColorAnimation {
              duration: Style.animationFast
            }
          }
        }

        Canvas {
          id: progressRing
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height) * 1.0
          height: width
          visible: !isStopwatchMode && totalSeconds > 0 && !compactMode && (isRunning || elapsedSeconds > 0)
          z: -1

          property real progressRatio: {
            if (totalSeconds <= 0)
              return 0;
            const ratio = remainingSeconds / totalSeconds;
            return Math.max(0, Math.min(1, ratio));
          }

          onProgressRatioChanged: requestPaint()

          onPaint: {
            var ctx = getContext("2d");
            if (width <= 0 || height <= 0) {
              return;
            }

            var centerX = width / 2;
            var centerY = height / 2;
            var radius = Math.min(width, height) / 2 - 5;

            if (radius <= 0) {
              return;
            }

            ctx.reset();

            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
            ctx.lineWidth = 10;
            ctx.strokeStyle = Qt.alpha(Color.mOnSurface, 0.1);
            ctx.stroke();

            if (progressRatio > 0) {
              ctx.beginPath();
              ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + progressRatio * 2 * Math.PI);
              ctx.lineWidth = 10;
              ctx.strokeStyle = Color.mPrimary;
              ctx.lineCap = "round";
              ctx.stroke();
            }
          }
        }

        Item {
          id: timerContainer
          anchors.centerIn: parent
          width: timerInput.implicitWidth
          height: timerInput.implicitHeight + 8 

          TextInput {
            id: timerInput
            anchors.centerIn: parent
            width: Math.max(implicitWidth, timerDisplayItem.width * 0.8)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            selectByMouse: false
            cursorVisible: false
            cursorDelegate: Item {} 
            readOnly: isStopwatchMode || isRunning || totalSeconds > 0
            enabled: !isRunning && !isStopwatchMode && totalSeconds === 0
            font.family: Settings.data.ui.fontFixed

            readonly property bool showingHours: {
              if (isStopwatchMode) {
                return elapsedSeconds >= 3600;
              }
              if (timerDisplayItem.isEditing) {
                return true;
              }
              return totalSeconds >= 3600;
            }

            font.pointSize: {
              const scale = compactMode ? 0.8 : 1.0;
              if (totalSeconds === 0) {
                return Style.fontSizeXXXL * 1.5 * scale;
              }
              return (showingHours ? Style.fontSizeXXL * 1.3 : (Style.fontSizeXXL * 1.8)) * scale;
            }

            font.weight: Style.fontWeightBold
            color: {
              if (totalSeconds > 0) {
                return Color.mPrimary;
              }
              if (timerDisplayItem.isEditing) {
                return Color.mPrimary;
              }
              return Color.mOnSurface;
            }

            property string _cachedText: ""
            property int _textUpdateCounter: 0

            function updateText() {
              if (isStopwatchMode) {
                _cachedText = formatTime(elapsedSeconds, elapsedSeconds);
              } else if (timerDisplayItem.isEditing && totalSeconds === 0 && timerDisplayItem.inputBuffer !== "") {
                _cachedText = formatTimeFromDigits(timerDisplayItem.inputBuffer);
              } else if (timerDisplayItem.isEditing && totalSeconds === 0) {
                _cachedText = formatTime(0, 0);
              } else {
                _cachedText = formatTime(remainingSeconds, totalSeconds);
              }
              _textUpdateCounter = _textUpdateCounter + 1;
            }

            text: {
              const counter = _textUpdateCounter;
              return _cachedText;
            }

            Connections {
              target: root
              function onRemainingSecondsChanged() { timerInput.updateText(); }
              function onTotalSecondsChanged() { timerInput.updateText(); }
              function onIsRunningChanged() { timerInput.updateText(); Qt.callLater(() => { timerInput.updateText(); }); }
              function onElapsedSecondsChanged() { timerInput.updateText(); }
              function onIsStopwatchModeChanged() { timerInput.updateText(); }
            }
            
            Connections {
             target: timerDisplayItem
             function onIsEditingChanged() {
               timerInput.updateText();
             }
           }

            Component.onCompleted: updateText()

            Keys.onPressed: event => {
              if (isRunning || isStopwatchMode || totalSeconds > 0) {
                if (event.key === Qt.Key_Space) {
                  if (isRunning) mainInstance.timerPause();
                  else mainInstance.timerStart();
                  event.accepted = true;
                  return;
                }
                event.accepted = true;
                return;
              }
              
              const keyText = event.text.toLowerCase();

              if (event.key === Qt.Key_Backspace) {
                if (timerDisplayItem.isEditing && timerDisplayItem.inputBuffer.length > 0) {
                  timerDisplayItem.inputBuffer = timerDisplayItem.inputBuffer.slice(0, -1);
                  if (timerDisplayItem.inputBuffer !== "") {
                    parseDigitsToTime(timerDisplayItem.inputBuffer);
                  } else {
                    setTimerRemainingSeconds(0);
                  }
                }
                event.accepted = true;
                return;
              }

              if (event.key === Qt.Key_Delete) {
                if (timerDisplayItem.isEditing) {
                  timerDisplayItem.inputBuffer = "";
                  setTimerRemainingSeconds(0);
                }
                event.accepted = true;
                return;
              }

              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                applyTimeFromBuffer();
                timerDisplayItem.isEditing = false;
                timerInput.focus = false;
                if (remainingSeconds > 0) {
                  mainInstance.timerStart();
                }
                event.accepted = true;
                return;
              }

              if (event.key === Qt.Key_Escape) {
                timerDisplayItem.inputBuffer = "";
                setTimerRemainingSeconds(0);
                timerDisplayItem.isEditing = false;
                timerInput.focus = false;
                event.accepted = true;
                return;
              }

              if (keyText === 'h' || keyText === 'm' || keyText === 's') {
                if (timerDisplayItem.inputBuffer.length > 0) {
                  let val = parseInt(timerDisplayItem.inputBuffer) || 0;
                  let secs = 0;
                  if (keyText === 'h') secs = val * 3600;
                  else if (keyText === 'm') secs = val * 60;
                  else if (keyText === 's') secs = val;
                  
                  setTimerRemainingSeconds(Math.min(99 * 3600 + 59 * 60 + 59, secs));
                  timerDisplayItem.inputBuffer = "";
                  timerDisplayItem.isEditing = false;
                  timerInput.focus = false;
                }
                event.accepted = true;
                return;
              }

              const isDigitKey = event.key >= Qt.Key_0 && event.key <= Qt.Key_9;
              const isDigitText = keyText.length === 1 && keyText >= '0' && keyText <= '9';

              if (isDigitKey && isDigitText) {
                if (timerDisplayItem.inputBuffer.length >= 6) {
                  event.accepted = true;
                  return;
                }
                timerDisplayItem.inputBuffer += keyText;
                parseDigitsToTime(timerDisplayItem.inputBuffer);
                event.accepted = true;
              } else {
                event.accepted = true;
              }
            }
            
            onActiveFocusChanged: {
                if (activeFocus) {
                  timerDisplayItem.isEditing = true;
                  timerDisplayItem.inputBuffer = "";
                } else {
                  applyTimeFromBuffer();
                  timerDisplayItem.isEditing = false;
                  timerDisplayItem.inputBuffer = "";
                }
            }

            MouseArea {
              anchors.fill: parent
              enabled: !isRunning && !isStopwatchMode && totalSeconds === 0
              cursorShape: enabled ? Qt.IBeamCursor : Qt.ArrowCursor
              preventStealing: true
              onPressed: (mouse) => {
                if (!isRunning && !isStopwatchMode && totalSeconds === 0) {
                  timerInput.forceActiveFocus();
                  mouse.accepted = true;
                }
              }
            }
          }
        }
      }

      RowLayout {
        id: buttonRow
        Layout.fillWidth: true
        spacing: Style.marginS

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 0
          implicitHeight: startButton.implicitHeight
          color: "transparent"

          NButton {
            id: startButton
            anchors.fill: parent
            text: {
              if (isRunning) return pluginApi?.tr("panel.pause") || "Pause";
              if (isStopwatchMode && elapsedSeconds > 0) return pluginApi?.tr("panel.resume") || "Resume";
              if (!isStopwatchMode && totalSeconds > 0) return pluginApi?.tr("panel.resume") || "Resume";
              return pluginApi?.tr("panel.start") || "Start";
            }
            icon: isRunning ? "player-pause" : "player-play"
            enabled: isStopwatchMode || remainingSeconds > 0
            onClicked: {
              if (isRunning) {
                pauseTimer();
              } else {
                startTimer();
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 0
          implicitHeight: resetButton.implicitHeight
          color: "transparent"

          NButton {
            id: resetButton
            anchors.fill: parent
            text: pluginApi?.tr("panel.reset") || "Reset"
            icon: "refresh"
            enabled: (isStopwatchMode && (elapsedSeconds > 0 || isRunning)) || (!isStopwatchMode && (remainingSeconds > 0 || isRunning || soundPlaying))
            onClicked: {
              resetTimer();
            }
          }
        }
      }

      NTabBar {
        id: modeTabBar
        Layout.fillWidth: true
        Layout.preferredHeight: Style.baseWidgetSize
        currentIndex: isStopwatchMode ? 1 : 0
        margins: 0
        distributeEvenly: true
        onCurrentIndexChanged: {
          const newMode = currentIndex === 1;
          if (newMode !== isStopwatchMode) {
             timerInput.focus = false;
             setTimerStopwatchMode(newMode);
          }
        }
        spacing: Style.marginS
        

        Component.onCompleted: {
             Qt.callLater(() => {
               if (modeTabBar.children && modeTabBar.children.length > 0) {
                 for (var i = 0; i < modeTabBar.children.length; i++) {
                   var child = modeTabBar.children[i];
                   if (child && typeof child.spacing !== 'undefined' && child.anchors) {
                     child.anchors.margins = 0;
                     break;
                   }
                 }
               }
             });
        }

        NTabButton {
          text: pluginApi?.tr("panel.countdown") || "Timer"
          tabIndex: 0
          checked: !isStopwatchMode
          radius: Style.iRadiusS
        }

        NTabButton {
          text: pluginApi?.tr("panel.stopwatch") || "Stopwatch"
          tabIndex: 1
          checked: isStopwatchMode
          radius: Style.iRadiusS
        }
      }
        }
      }
    }
  }

  Shortcut {
    sequence: "Space"
    onActivated: {
      if (!timerInput.activeFocus) {
        if (isRunning) mainInstance.timerPause();
        else if (isStopwatchMode || remainingSeconds > 0) mainInstance.timerStart();
      }
    }
  }
}

