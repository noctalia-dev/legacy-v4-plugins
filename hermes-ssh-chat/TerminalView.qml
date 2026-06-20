import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import "." as Local

Item {
  id: root

  property string rawText: ""
  property bool sessionActive: false
  property real fontSize: Style.fontSizeS
  property string fontFamily: Settings.data.ui.fontFixed
  property int rows: 32
  property int cols: 180

  signal input(string text)

  property var _ts: null

  Component.onCompleted: {
    _initTerminal();
    if (rawText.length > 0) {
      _processInput(rawText);
      root._ts.processed = rawText.length;
      _refreshDisplay();
    }
    Qt.callLater(focusTerminal);
  }
  onRowsChanged: _initTerminal()
  onColsChanged: _initTerminal()
  onVisibleChanged: if (visible) Qt.callLater(focusTerminal)
  onSessionActiveChanged: if (sessionActive) Qt.callLater(focusTerminal)

  Connections {
    target: Local.HermesSession
    function onTerminalOutput(text) {
      if (!root._ts) _initTerminal();
      _processInput(text);
      _renderTimer.restart();
    }
    function onTerminalReset() {
      _initTerminal();
      _renderTimer.restart();
    }
  }

  onRawTextChanged: {
    if (!root._ts) {
      _initTerminal();
      if (rawText.length > 0) {
        _processInput(rawText);
        root._ts.processed = rawText.length;
      }
      _refreshDisplay();
      return;
    }
    if (rawText.length < root._ts.processed) {
      _initTerminal();
      if (rawText.length > 0) {
        _processInput(rawText);
      }
      root._ts.processed = rawText.length;
      _refreshDisplay();
      return;
    }
    root._ts.processed = rawText.length;
  }

  Timer {
    id: _renderTimer
    interval: 16
    onTriggered: _refreshDisplay()
  }

  function _initTerminal() {
    const sr = Math.max(12, Math.min(80, Number(root.rows || 32)));
    const sc = Math.max(40, Math.min(240, Number(root.cols || 180)));
    root._ts = {
      screen: makeScreen(sr, sc),
      rows: sr,
      cols: sc,
      row: 0,
      col: 0,
      savedRow: 0,
      savedCol: 0,
      scrollTop: 0,
      scrollBottom: sr - 1,
      originMode: false,
      wrapPending: false,
      sgr: { fg: "", bg: "", bold: false, dim: false },
      pending: "",
      processed: 0
    };
  }

  function focusTerminal() {
    if (!root.visible) return;
    terminalDisplay.forceActiveFocus();
  }

  function htmlEscape(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/ /g, "&nbsp;")
      .replace(/\t/g, "&nbsp;&nbsp;&nbsp;&nbsp;");
  }

  function color16(code) {
    const colors = {
      30: "#2e3440", 31: "#bf616a", 32: "#a3be8c", 33: "#ebcb8b",
      34: "#81a1c1", 35: "#b48ead", 36: "#88c0d0", 37: "#e5e9f0",
      90: "#4c566a", 91: "#d08770", 92: "#8fbcbb", 93: "#f0d399",
      94: "#8ab6e6", 95: "#c895bf", 96: "#8fdbd7", 97: "#eceff4"
    };
    return colors[code] || Color.mOnSurface;
  }

  function color256(index) {
    index = Math.max(0, Math.min(255, Number(index) || 0));
    const base = [
      "#000000", "#800000", "#008000", "#808000", "#000080", "#800080", "#008080", "#c0c0c0",
      "#808080", "#ff0000", "#00ff00", "#ffff00", "#0000ff", "#ff00ff", "#00ffff", "#ffffff"
    ];
    if (index < 16) return base[index];
    if (index >= 232) {
      const level = 8 + (index - 232) * 10;
      const hex = level.toString(16).padStart(2, "0");
      return "#" + hex + hex + hex;
    }
    const n = index - 16;
    const steps = [0, 95, 135, 175, 215, 255];
    const r = steps[Math.floor(n / 36) % 6];
    const g = steps[Math.floor(n / 6) % 6];
    const b = steps[n % 6];
    return "#" + r.toString(16).padStart(2, "0") + g.toString(16).padStart(2, "0") + b.toString(16).padStart(2, "0");
  }

  function styleAttr(state) {
    let css = "";
    if (state.fg) css += "color:" + state.fg + ";";
    if (state.bg) css += "background-color:" + state.bg + ";";
    if (state.bold) css += "font-weight:700;";
    if (state.dim) css += "opacity:0.72;";
    return css.length > 0 ? " style=\"" + css + "\"" : "";
  }

  function copyState(state) {
    return { fg: state.fg, bg: state.bg, bold: state.bold, dim: state.dim };
  }

  function blankCell() {
    return { ch: " ", fg: "", bg: "", bold: false, dim: false };
  }

  function cellFrom(ch, state) {
    return { ch: ch, fg: state.fg, bg: state.bg, bold: state.bold, dim: state.dim };
  }

  function makeLine(cols) {
    const line = [];
    for (let i = 0; i < cols; i++) line.push(blankCell());
    return line;
  }

  function makeScreen(rows, cols) {
    const screen = [];
    for (let r = 0; r < rows; r++) screen.push(makeLine(cols));
    return screen;
  }

  function applySgr(params, state) {
    if (params.length === 0) params = [0];
    for (let i = 0; i < params.length; i++) {
      const code = params[i];
      if (code === 0) { state.fg = ""; state.bg = ""; state.bold = false; state.dim = false; }
      else if (code === 1) { state.bold = true; }
      else if (code === 2) { state.dim = true; }
      else if (code === 22) { state.bold = false; state.dim = false; }
      else if (code === 39) { state.fg = ""; }
      else if (code === 49) { state.bg = ""; }
      else if ((code >= 30 && code <= 37) || (code >= 90 && code <= 97)) { state.fg = color16(code); }
      else if ((code >= 40 && code <= 47) || (code >= 100 && code <= 107)) { state.bg = color16(code - 10); }
      else if ((code === 38 || code === 48) && params[i + 1] === 5 && i + 2 < params.length) {
        if (code === 38) state.fg = color256(params[i + 2]); else state.bg = color256(params[i + 2]);
        i += 2;
      }
    }
  }

  function appendSpan(out, text, state) {
    if (text.length === 0) return out;
    return out + "<span" + styleAttr(state) + ">" + htmlEscape(text) + "</span>";
  }

  function clearLine(line, start, end) {
    const from = Math.max(0, start);
    const to = Math.min(line.length - 1, end);
    for (let i = from; i <= to; i++) line[i] = blankCell();
  }

  function clearScreen(screen, cols) {
    for (let r = 0; r < screen.length; r++) screen[r] = makeLine(cols);
  }

  function parseParams(seq) {
    const cleaned = String(seq || "").replace(/[?=]/g, "");
    if (cleaned.length === 0) return [];
    return cleaned.split(";").map(function(p) { return Number(p || 0); });
  }

  function sameCellStyle(a, b) {
    return a.fg === b.fg && a.bg === b.bg && a.bold === b.bold && a.dim === b.dim;
  }

  function renderLine(line) {
    let out = "";
    let buffer = "";
    let current = { fg: "", bg: "", bold: false, dim: false };

    function flush() { out = appendSpan(out, buffer, current); buffer = ""; }

    let lastNonSpace = -1;
    for (let i = 0; i < line.length; i++) {
      if (line[i].ch !== " " || line[i].bg) lastNonSpace = i;
    }
    if (lastNonSpace === -1) return "&nbsp;";

    current = copyState(line[0]);
    for (let i = 0; i <= lastNonSpace; i++) {
      const cell = line[i];
      if (!sameCellStyle(cell, current)) { flush(); current = copyState(cell); }
      buffer += cell.ch;
    }
    flush();
    return out;
  }

  function _processInput(input) {
    const ts = root._ts;
    if (!ts || !input || input.length === 0) return;

    if (ts.pending.length > 0) {
      input = ts.pending + input;
      ts.pending = "";
    }

    function clampCursor() {
      if (ts.originMode)
        ts.row = Math.max(ts.scrollTop, Math.min(ts.scrollBottom, ts.row));
      else
        ts.row = Math.max(0, Math.min(ts.rows - 1, ts.row));
      ts.col = Math.max(0, Math.min(ts.cols - 1, ts.col));
    }

    function doScrollUp() {
      ts.screen.splice(ts.scrollTop, 1);
      ts.screen.splice(ts.scrollBottom, 0, makeLine(ts.cols));
    }

    function doScrollDown() {
      ts.screen.splice(ts.scrollBottom, 1);
      ts.screen.splice(ts.scrollTop, 0, makeLine(ts.cols));
    }

    function doLineFeed() {
      ts.col = 0;
      if (ts.row === ts.scrollBottom) doScrollUp();
      else ts.row = Math.min(ts.row + 1, ts.rows - 1);
      ts.wrapPending = false;
    }

    function doIndex() {
      if (ts.row === ts.scrollBottom) doScrollUp();
      else ts.row = Math.min(ts.row + 1, ts.rows - 1);
      ts.wrapPending = false;
    }

    function doReverseIndex() {
      if (ts.row === ts.scrollTop) doScrollDown();
      else ts.row = Math.max(ts.scrollTop, ts.row - 1);
      ts.wrapPending = false;
    }

    function putChar(ch) {
      if (ts.wrapPending) {
        doIndex();
        ts.col = 0;
      }
      ts.screen[ts.row][ts.col] = cellFrom(ch, ts.sgr);
      if (ts.col === ts.cols - 1) {
        ts.wrapPending = true;
      } else {
        ts.col++;
        ts.wrapPending = false;
      }
    }

    for (let i = 0; i < input.length; i++) {
      const ch = input[i];

      if (ch === "\x1b" || ch === "\x9b") {
        if (ch === "\x1b" && i + 1 >= input.length) {
          ts.pending = input.substring(i);
          return;
        }
        const next = ch === "\x9b" ? "[" : input[i + 1];

        if (next === "[") {
          let j = ch === "\x9b" ? i + 1 : i + 2;
          let seq = "";
          while (j < input.length && !/[@-~]/.test(input[j])) {
            seq += input[j];
            j++;
          }
          if (j >= input.length) {
            ts.pending = input.substring(i);
            return;
          }

          const command = input[j];
          const params = parseParams(seq);
          if (command === "m") {
            applySgr(params, ts.sgr);
          } else if (command === "A") {
            ts.row -= Math.max(1, params[0] || 1); ts.wrapPending = false; clampCursor();
          } else if (command === "B") {
            ts.row += Math.max(1, params[0] || 1); ts.wrapPending = false; clampCursor();
          } else if (command === "C") {
            ts.col += Math.max(1, params[0] || 1); ts.wrapPending = false; clampCursor();
          } else if (command === "D") {
            ts.col -= Math.max(1, params[0] || 1); ts.wrapPending = false; clampCursor();
          } else if (command === "E") {
            ts.row += Math.max(1, params[0] || 1); ts.col = 0; ts.wrapPending = false; clampCursor();
          } else if (command === "F") {
            ts.row -= Math.max(1, params[0] || 1); ts.col = 0; ts.wrapPending = false; clampCursor();
          } else if (command === "G") {
            ts.col = Math.max(0, (params[0] || 1) - 1); ts.wrapPending = false; clampCursor();
          } else if (command === "H" || command === "f") {
            ts.row = (params[0] || 1) - 1;
            if (ts.originMode) ts.row += ts.scrollTop;
            ts.col = Math.max(0, (params[1] || 1) - 1);
            ts.wrapPending = false;
            clampCursor();
          } else if (command === "s") {
            ts.savedRow = ts.row; ts.savedCol = ts.col;
          } else if (command === "u") {
            ts.row = ts.savedRow; ts.col = ts.savedCol; ts.wrapPending = false; clampCursor();
          } else if (command === "d") {
            ts.row = (params[0] || 1) - 1;
            if (ts.originMode) ts.row += ts.scrollTop;
            ts.wrapPending = false;
            clampCursor();
          } else if (command === "K") {
            const mode = params[0] || 0;
            if (mode === 1) clearLine(ts.screen[ts.row], 0, ts.col);
            else if (mode === 2) clearLine(ts.screen[ts.row], 0, ts.cols - 1);
            else clearLine(ts.screen[ts.row], ts.col, ts.cols - 1);
          } else if (command === "J") {
            const mode = params[0] || 0;
            if (mode === 2 || mode === 3) {
              clearScreen(ts.screen, ts.cols); ts.row = 0; ts.col = 0; ts.wrapPending = false;
            } else if (mode === 0) {
              clearLine(ts.screen[ts.row], ts.col, ts.cols - 1);
              for (let r = ts.row + 1; r < ts.rows; r++) ts.screen[r] = makeLine(ts.cols);
            } else if (mode === 1) {
              for (let r = 0; r < ts.row; r++) ts.screen[r] = makeLine(ts.cols);
              clearLine(ts.screen[ts.row], 0, ts.col);
            }
          } else if (command === "X") {
            clearLine(ts.screen[ts.row], ts.col, ts.col + Math.max(1, params[0] || 1) - 1);
          } else if (command === "P") {
            const count = Math.max(1, params[0] || 1);
            for (let c = ts.col; c < ts.cols; c++)
              ts.screen[ts.row][c] = c + count < ts.cols ? ts.screen[ts.row][c + count] : blankCell();
          } else if (command === "@") {
            const count = Math.max(1, params[0] || 1);
            for (let c = ts.cols - 1; c >= ts.col; c--)
              ts.screen[ts.row][c] = c - count >= ts.col ? ts.screen[ts.row][c - count] : blankCell();
          } else if (command === "L") {
            const count = Math.min(Math.max(1, params[0] || 1), ts.scrollBottom - ts.row + 1);
            for (let n = 0; n < count; n++) {
              ts.screen.splice(ts.scrollBottom, 1);
              ts.screen.splice(ts.row, 0, makeLine(ts.cols));
            }
          } else if (command === "M") {
            const count = Math.min(Math.max(1, params[0] || 1), ts.scrollBottom - ts.row + 1);
            for (let n = 0; n < count; n++) {
              ts.screen.splice(ts.row, 1);
              ts.screen.splice(ts.scrollBottom, 0, makeLine(ts.cols));
            }
          } else if (command === "S") {
            const count = Math.max(1, params[0] || 1);
            for (let n = 0; n < count; n++) doScrollUp();
          } else if (command === "T") {
            const count = Math.max(1, params[0] || 1);
            for (let n = 0; n < count; n++) doScrollDown();
          } else if (command === "r") {
            if (params.length === 0) {
              ts.scrollTop = 0; ts.scrollBottom = ts.rows - 1;
            } else {
              ts.scrollTop = Math.max(0, (params[0] || 1) - 1);
              ts.scrollBottom = (params.length > 1 && params[1] > 0)
                ? Math.min(ts.rows - 1, params[1] - 1) : ts.rows - 1;
              if (ts.scrollTop >= ts.scrollBottom) { ts.scrollTop = 0; ts.scrollBottom = ts.rows - 1; }
            }
            ts.row = ts.originMode ? ts.scrollTop : 0;
            ts.col = 0;
            ts.wrapPending = false;
          } else if (command === "h" || command === "l") {
            const modeNums = seq.replace(/[?]/g, "").split(";").map(function(p) { return Number(p || 0); });
            if (modeNums.some(function(n) { return n === 1049 || n === 47 || n === 1047; })) {
              clearScreen(ts.screen, ts.cols);
              ts.row = 0; ts.col = 0; ts.scrollTop = 0; ts.scrollBottom = ts.rows - 1; ts.originMode = false; ts.wrapPending = false;
            }
            if (modeNums.indexOf(6) !== -1) {
              ts.originMode = command === "h";
              if (ts.originMode) { ts.row = ts.scrollTop; ts.col = 0; ts.wrapPending = false; }
            }
          }
          i = j;

        } else if (next === "]") {
          let j = i + 2;
          while (j < input.length && input[j] !== "\x07" && !(input[j] === "\x1b" && j + 1 < input.length && input[j + 1] === "\\")) {
            j++;
          }
          if (j >= input.length) {
            ts.pending = input.substring(i);
            return;
          }
          if (input[j] === "\x1b") j++;
          i = j;

        } else if (next === "7" || next === "s") {
          ts.savedRow = ts.row; ts.savedCol = ts.col; i++;
        } else if (next === "8" || next === "u") {
          ts.row = ts.savedRow; ts.col = ts.savedCol; ts.wrapPending = false; clampCursor(); i++;
        } else if (next === "c") {
          clearScreen(ts.screen, ts.cols);
          ts.row = 0; ts.col = 0; ts.scrollTop = 0; ts.scrollBottom = ts.rows - 1; ts.originMode = false; ts.wrapPending = false; i++;
        } else if (next === "D") {
          doIndex(); i++;
        } else if (next === "E") {
          doLineFeed(); i++;
        } else if (next === "M") {
          doReverseIndex(); i++;
        } else {
          i++;
        }

      } else if (ch === "\r") {
        ts.col = 0; ts.wrapPending = false;
      } else if (ch === "\n") {
        doLineFeed();
      } else if (ch === "\x84") {
        doIndex();
      } else if (ch === "\x85") {
        doLineFeed();
      } else if (ch === "\x8d") {
        doReverseIndex();
      } else if (ch === "\b" || ch === "\x7f") {
        ts.col = Math.max(0, ts.col - 1); ts.wrapPending = false;
      } else if (ch === "\t") {
        const nextTab = Math.min(ts.cols - 1, ts.col + (8 - (ts.col % 8)));
        while (ts.col < nextTab) putChar(" ");
      } else if (ch >= " ") {
        putChar(ch);
      } else if (ch === "\x0c") {
        clearScreen(ts.screen, ts.cols);
        ts.row = 0; ts.col = 0; ts.scrollTop = 0; ts.scrollBottom = ts.rows - 1; ts.originMode = false; ts.wrapPending = false;
      }
    }
  }

  function _refreshDisplay() {
    const ts = root._ts;
    if (!ts) return;

    const cr = ts.row;
    const cc = ts.col;
    let savedCell = null;
    if (cr >= 0 && cr < ts.rows && cc >= 0 && cc < ts.cols) {
      const orig = ts.screen[cr][cc];
      savedCell = { ch: orig.ch, fg: orig.fg, bg: orig.bg, bold: orig.bold, dim: orig.dim };
      ts.screen[cr][cc] = {
        ch: orig.ch === " " ? "\u00a0" : orig.ch,
        fg: "#0b0f14",
        bg: "#d8dee9",
        bold: orig.bold,
        dim: false
      };
    }

    const lines = [];
    for (let r = 0; r < ts.rows; r++)
      lines.push(renderLine(ts.screen[r]));

    if (savedCell) ts.screen[cr][cc] = savedCell;

    terminalDisplay.text = lines.join("<br>");
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusS
    color: Color.mSurface
    border.color: terminalDisplay.activeFocus ? Color.mSecondary : Color.mOutline
    border.width: Style.borderS

    ScrollView {
      id: scrollView
      anchors.fill: parent
      anchors.margins: Style.marginM
      clip: true

      TextEdit {
        id: terminalDisplay
        width: Math.max(640, scrollView.width - Style.margin2M)
        height: Math.max(implicitHeight, scrollView.availableHeight)
        readOnly: true
        selectByMouse: true
        focus: true
        wrapMode: TextEdit.NoWrap
        textFormat: TextEdit.RichText
        color: Color.mOnSurface
        selectedTextColor: Color.mOnPrimary
        selectionColor: Color.mPrimary
        font.family: root.fontFamily
        font.pointSize: Math.max(1, root.fontSize * Style.uiScaleRatio)
        textMargin: 0

        Keys.onPressed: event => {
          if (!root.sessionActive) return;
          if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_V) {
              const clip = String(Quickshell.clipboardText || "");
              if (clip.length > 0) root.input(clip);
              event.accepted = true;
              return;
            }
            if (event.key === Qt.Key_C) { root.input("\x03"); event.accepted = true; }
            else if (event.key === Qt.Key_D) { root.input("\x04"); event.accepted = true; }
            else if (event.key === Qt.Key_L) { root.input("\x0c"); event.accepted = true; }
            return;
          }
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.input("\r"); event.accepted = true; }
          else if (event.key === Qt.Key_Backspace) { root.input("\x7f"); event.accepted = true; }
          else if (event.key === Qt.Key_Tab) { root.input("\t"); event.accepted = true; }
          else if (event.key === Qt.Key_Left) { root.input("\x1b[D"); event.accepted = true; }
          else if (event.key === Qt.Key_Right) { root.input("\x1b[C"); event.accepted = true; }
          else if (event.key === Qt.Key_Up) { root.input("\x1b[A"); event.accepted = true; }
          else if (event.key === Qt.Key_Down) { root.input("\x1b[B"); event.accepted = true; }
          else if (event.text && event.text.length > 0) { root.input(event.text); event.accepted = true; }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      propagateComposedEvents: true
      onPressed: mouse => {
        terminalDisplay.forceActiveFocus();
        mouse.accepted = false;
      }
    }
  }
}
