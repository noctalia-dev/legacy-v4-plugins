import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.Compositor

Item {
  id: root
  property var pluginApi: null


  Component.onCompleted: {
    if (pluginApi && !parserStarted) {
      checkAndParse();
    }
  }

  onPluginApiChanged: {
    if (pluginApi && !parserStarted) {
      checkAndParse();
    }
  }

  // Check if compositor changed since last parse, and re-parse if needed
  function checkAndParse() {
    var currentCompositor = getCurrentCompositor();
    var savedCompositor = pluginApi?.pluginSettings?.detectedCompositor || "";
    var hasData = (pluginApi?.pluginSettings?.cheatsheetData || []).length > 0;

    // Re-parse if:
    // 1. No data cached yet, OR
    // 2. Compositor changed since last parse
    if (!hasData || currentCompositor !== savedCompositor) {
      parserStarted = true;
      runParser();
    } else {
      parserStarted = true; // Mark as done, using cache
    }
  }

  // Get current compositor name
  function getCurrentCompositor() {
    if (CompositorService.isHyprland) return "hyprland";
    if (CompositorService.isNiri) return "niri";
    if (CompositorService.isSway) return "sway";
    if (CompositorService.isLabwc) return "labwc";
    if (CompositorService.isMango) return "mango";
    return "unknown";
  }

  // Get user-friendly message for unsupported compositors
  function getUnsupportedCompositorMessage(compositor) {
    var messages = {
      "sway": {
        short: pluginApi?.tr("keybind-cheatsheet.error.sway-not-supported") || "Sway is not yet supported",
        detail: pluginApi?.tr("keybind-cheatsheet.error.sway-detail") || "Sway support may be added in a future update (similar format to Hyprland)"
      },
      "labwc": {
        short: pluginApi?.tr("keybind-cheatsheet.error.labwc-not-supported") || "LabWC is not supported",
        detail: pluginApi?.tr("keybind-cheatsheet.error.labwc-detail") || "LabWC uses XML config format which is incompatible with this plugin"
      },
      "mango": {
        short: pluginApi?.tr("keybind-cheatsheet.error.mango-not-supported") || "MangoWC is not supported",
        detail: pluginApi?.tr("keybind-cheatsheet.error.mango-detail") || "MangoWC config format is not compatible with this plugin"
      },
      "unknown": {
        short: pluginApi?.tr("keybind-cheatsheet.error.unknown-compositor") || "Unknown compositor detected",
        detail: pluginApi?.tr("keybind-cheatsheet.error.unknown-detail") || "This plugin only supports Hyprland and Niri compositors"
      }
    };

    return messages[compositor] || messages["unknown"];
  }

  property bool parserStarted: false

  // Memory leak prevention: cleanup on destruction
  Component.onDestruction: {
    clearParsingData();
    cleanupProcesses();
  }

  function cleanupProcesses() {
    if (niriGlobProcess.running) niriGlobProcess.running = false;
    if (niriReadProcess.running) niriReadProcess.running = false;
    if (hyprGlobProcess.running) hyprGlobProcess.running = false;
    if (hyprReadProcess.running) hyprReadProcess.running = false;

    // Clear process buffers
    niriGlobProcess.expandedFiles = [];
    hyprGlobProcess.expandedFiles = [];
    currentLines = [];
  }

  function clearParsingData() {
    filesToParse = [];
    parsedFiles = {};
    accumulatedLines = [];
    currentLines = [];
    collectedBinds = {};
    parseDepthCounter = 0;
  }

  // Refresh function - accessible from mainInstance
  function refresh() {
    if (!pluginApi) {
      return;
    }

    // Reset parserStarted to allow re-parsing
    parserStarted = false;
    isCurrentlyParsing = false;

    // Now run parser
    parserStarted = true;
    runParser();
  }

  // Recursive parsing support
  property var filesToParse: []
  property var parsedFiles: ({})
  property var accumulatedLines: []
  property var currentLines: []
  property var collectedBinds: ({})  // Collect keybinds from all files

  // Memory leak prevention: recursion limits
  property int maxParseDepth: 50
  property int parseDepthCounter: 0
  property bool isCurrentlyParsing: false

  function runParser() {
    if (isCurrentlyParsing) {
      return;
    }

    isCurrentlyParsing = true;
    parseDepthCounter = 0;

    // Detect compositor using CompositorService
    var compositorName = getCurrentCompositor();
    if (!CompositorService.isHyprland && !CompositorService.isNiri) {
      isCurrentlyParsing = false;

      var unsupportedMsg = getUnsupportedCompositorMessage(compositorName);
      saveToDb([{
        "title": pluginApi?.tr("keybind-cheatsheet.error.unsupported-compositor") || "Unsupported Compositor",
        "binds": [
          { "keys": compositorName.toUpperCase(), "desc": unsupportedMsg.short },
          { "keys": "INFO", "desc": unsupportedMsg.detail }
        ]
      }]);
      return;
    }

    var homeDir = Quickshell.env("HOME");
    if (!homeDir) {
      isCurrentlyParsing = false;
      saveToDb([{
        "title": "ERROR",
        "binds": [{ "keys": "ERROR", "desc": "Cannot get $HOME" }]
      }]);
      return;
    }

    // Reset recursive state
    filesToParse = [];
    parsedFiles = {};
    accumulatedLines = [];
    collectedBinds = {};

    var filePath;
    if (CompositorService.isHyprland) {
      filePath = pluginApi?.pluginSettings?.hyprlandConfigPath || (homeDir + "/.config/hypr/hyprland.conf");
      filePath = filePath.replace(/^~/, homeDir);
    } else if (CompositorService.isNiri) {
      filePath = pluginApi?.pluginSettings?.niriConfigPath || (homeDir + "/.config/niri/config.kdl");
      filePath = filePath.replace(/^~/, homeDir);
    }

    filesToParse = [filePath];

    if (CompositorService.isHyprland) {
      parseNextHyprlandFile();
    } else {
      parseNextNiriFile();
    }
  }

  function getDirectoryFromPath(filePath) {
    var lastSlash = filePath.lastIndexOf('/');
    return lastSlash >= 0 ? filePath.substring(0, lastSlash) : ".";
  }

  function resolveRelativePath(basePath, relativePath) {
    var homeDir = Quickshell.env("HOME") || "";
    var resolved = relativePath.replace(/^~/, homeDir);
    if (resolved.startsWith('/')) return resolved;
    return getDirectoryFromPath(basePath) + "/" + resolved;
  }

  function isGlobPattern(path) {
    return path.indexOf('*') !== -1 || path.indexOf('?') !== -1;
  }

  // ========== NIRI RECURSIVE PARSING ==========
  function parseNextNiriFile() {
    if (parseDepthCounter >= maxParseDepth) {
      isCurrentlyParsing = false;
      clearParsingData();
      return;
    }
    parseDepthCounter++;

    if (filesToParse.length === 0) {
      finalizeNiriBinds();
      return;
    }

    var nextFile = filesToParse.shift();

    // Handle glob patterns
    if (isGlobPattern(nextFile)) {
      niriGlobProcess.expandedFiles = []; // Clear previous results
      niriGlobProcess.command = ["sh", "-c", "for f in " + nextFile + "; do [ -f \"$f\" ] && echo \"$f\"; done"];
      niriGlobProcess.running = true;
      return;
    }

    if (parsedFiles[nextFile]) {
      parseNextNiriFile();
      return;
    }

    parsedFiles[nextFile] = true;
    currentLines = [];
    niriReadProcess.currentFilePath = nextFile;
    niriReadProcess.command = ["cat", nextFile];
    niriReadProcess.running = true;
  }

  Process {
    id: niriGlobProcess
    property var expandedFiles: []
    running: false

    stdout: SplitParser {
      onRead: data => {
        var trimmed = data.trim();
        if (trimmed.length > 0) {
          if (niriGlobProcess.expandedFiles.length < 100) {
            niriGlobProcess.expandedFiles.push(trimmed);
          }
        }
      }
    }

    onExited: {
      for (var i = 0; i < expandedFiles.length; i++) {
        var path = expandedFiles[i];
        if (!root.parsedFiles[path] && root.filesToParse.indexOf(path) === -1) {
          root.filesToParse.push(path);
        }
      }
      expandedFiles = [];
      root.parseNextNiriFile();
    }
  }

  Process {
    id: niriReadProcess
    property string currentFilePath: ""
    running: false

    stdout: SplitParser {
      onRead: data => {
        if (root.currentLines.length < 10000) {
          root.currentLines.push(data);
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && root.currentLines.length > 0) {
        // First pass: find includes
        for (var i = 0; i < root.currentLines.length; i++) {
          var line = root.currentLines[i];
          var includeMatch = line.match(/(?:include|source)\s+"([^"]+)"/i);
          if (includeMatch) {
            var includePath = includeMatch[1];
            var resolvedPath = root.resolveRelativePath(currentFilePath, includePath);
            if (!root.parsedFiles[resolvedPath] && root.filesToParse.indexOf(resolvedPath) === -1) {
              root.filesToParse.push(resolvedPath);
            }
          }
        }
        // Second pass: parse keybinds from this file
        root.parseNiriFileContent(root.currentLines.join("\n"));
      }
      root.currentLines = [];
      root.parseNextNiriFile();
    }
  }

  function parseNiriFileContent(text) {
    var lines = text.split('\n');
    var inBindsBlock = false;
    var bindsBlockDepth = 0;
    var currentCategory = null;
    var bindsFoundInFile = 0;

    // State for multiline bind parsing
    var currentBindKey = null;
    var currentBindAttributes = "";
    var currentBindAction = "";
    var bindBraceDepth = 0;

    var actionCategories = {
      "spawn": "Applications",
      "spawn-sh": "Applications",
      "focus-column": "Column Navigation",
      "focus-window": "Window Focus",
      "focus-workspace": "Workspace Navigation",
      "move-column": "Move Columns",
      "move-window": "Move Windows",
      "move-column-to-workspace": "Workspace Management",
      "move-window-to-workspace": "Workspace Management",
      "consume-window": "Window Management",
      "expel-window": "Window Management",
      "close-window": "Window Management",
      "fullscreen-window": "Window Management",
      "maximize-column": "Column Management",
      "set-column-width": "Column Width",
      "switch-preset-column-width": "Column Width",
      "reset-window-height": "Window Size",
      "screenshot": "Screenshots",
      "screenshot-window": "Screenshots",
      "screenshot-screen": "Screenshots",
      "power-off-monitors": "Power",
      "quit": "System",
      "toggle-animation": "Animations"
    };

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();

      // Skip KDL block comments: /-
      if (line.startsWith("/-")) continue;

      // Find binds block start
      if (!inBindsBlock && line.startsWith("binds") && line.includes("{")) {
        inBindsBlock = true;
        bindsBlockDepth = 1;
        continue;
      }

      if (!inBindsBlock) continue;

      // Category markers - support multiple formats:
      // //"Category Name"
      // // "Category Name"
      // // #"Category Name"
      // //#"Category Name"
      if (line.startsWith("//")) {
        var categoryMatch = line.match(/\/\/\s*#?"([^"]+)"/);
        if (categoryMatch) {
          currentCategory = categoryMatch[1];
        }
        continue;
      }

      // Skip empty lines
      if (line.length === 0) continue;

      // Track braces for binds block boundary
      var openBraces = (line.match(/\{/g) || []).length;
      var closeBraces = (line.match(/\}/g) || []).length;

      // If we're not currently parsing a multiline bind
      if (currentBindKey === null) {
        // Try to match a keybind start: Mod+Key or Mod+Key attributes { or Mod+Key { action; }
        var bindStartMatch = line.match(/^([A-Za-z0-9_+]+)\s*((?:[a-z\-]+="[^"]*"\s*)*)\{(.*)$/);

        if (bindStartMatch) {
          currentBindKey = bindStartMatch[1];
          currentBindAttributes = bindStartMatch[2].trim();
          var restOfLine = bindStartMatch[3];

          // Check if the bind is complete on this line (single-line bind)
          if (restOfLine.includes("}")) {
            // Single-line bind: Mod+H { focus-column-left; }
            currentBindAction = restOfLine.replace(/\}\s*$/, "").trim();
            finalizeBind();
          } else {
            // Multiline bind starts here
            currentBindAction = restOfLine.trim();
            bindBraceDepth = 1;
          }
        } else {
          // Not a bind start, track braces for binds block
          bindsBlockDepth += openBraces - closeBraces;
          if (bindsBlockDepth <= 0) {
            inBindsBlock = false;
          }
        }
      } else {
        // We're in a multiline bind, accumulate action content
        bindBraceDepth += openBraces - closeBraces;

        if (bindBraceDepth <= 0) {
          // Bind is complete
          currentBindAction += " " + line.replace(/\}\s*$/, "").trim();
          finalizeBind();
        } else {
          // Still in multiline bind
          currentBindAction += " " + line.trim();
        }
      }
    }

    function finalizeBind() {
      if (!currentBindKey) return;

      bindsFoundInFile++;
      var action = currentBindAction.trim().replace(/;$/, "").trim();

      var hotkeyTitle = null;
      var titleMatch = currentBindAttributes.match(/hotkey-overlay-title="([^"]+)"/);
      if (titleMatch) hotkeyTitle = titleMatch[1];

      var formattedKeys = formatNiriKeyCombo(currentBindKey);
      var category = currentCategory || getNiriCategory(action, actionCategories);
      var description = hotkeyTitle || formatNiriAction(action);

      if (!collectedBinds[category]) {
        collectedBinds[category] = [];
      }
      collectedBinds[category].push({
        "keys": formattedKeys,
        "desc": description
      });

      // Reset state
      currentBindKey = null;
      currentBindAttributes = "";
      currentBindAction = "";
      bindBraceDepth = 0;
    }
  }

  function finalizeNiriBinds() {
    var categoryOrder = [
      "Applications", "Window Management", "Column Navigation",
      "Window Focus", "Workspace Navigation", "Workspace Management",
      "Move Columns", "Move Windows", "Column Management", "Column Width",
      "Window Size", "Screenshots", "Power", "System", "Animations"
    ];

    var categories = [];
    for (var k = 0; k < categoryOrder.length; k++) {
      var catName = categoryOrder[k];
      if (collectedBinds[catName] && collectedBinds[catName].length > 0) {
        categories.push({ "title": catName, "binds": collectedBinds[catName] });
      }
    }

    // Add remaining categories
    for (var cat in collectedBinds) {
      if (categoryOrder.indexOf(cat) === -1 && collectedBinds[cat].length > 0) {
        categories.push({ "title": cat, "binds": collectedBinds[cat] });
      }
    }

    saveToDb(categories);
    isCurrentlyParsing = false;
    clearParsingData();
  }

  // ========== HYPRLAND RECURSIVE PARSING ==========
  function parseNextHyprlandFile() {
    if (parseDepthCounter >= maxParseDepth) {
      isCurrentlyParsing = false;
      clearParsingData();
      return;
    }
    parseDepthCounter++;

    if (filesToParse.length === 0) {
      if (accumulatedLines.length > 0) {
        parseHyprlandConfig(accumulatedLines.join("\n"));
      } else {
        isCurrentlyParsing = false;
      }
      return;
    }

    var nextFile = filesToParse.shift();

    // Handle glob patterns
    if (isGlobPattern(nextFile)) {
      hyprGlobProcess.expandedFiles = []; // Clear previous results
      hyprGlobProcess.command = ["sh", "-c", "for f in " + nextFile + "; do [ -f \"$f\" ] && echo \"$f\"; done"];
      hyprGlobProcess.running = true;
      return;
    }

    if (parsedFiles[nextFile]) {
      parseNextHyprlandFile();
      return;
    }

    parsedFiles[nextFile] = true;
    currentLines = [];
    hyprReadProcess.currentFilePath = nextFile;
    hyprReadProcess.command = ["cat", nextFile];
    hyprReadProcess.running = true;
  }

  Process {
    id: hyprGlobProcess
    property var expandedFiles: []
    running: false

    stdout: SplitParser {
      onRead: data => {
        var trimmed = data.trim();
        if (trimmed.length > 0) {
          if (hyprGlobProcess.expandedFiles.length < 100) {
            hyprGlobProcess.expandedFiles.push(trimmed);
          }
        }
      }
    }

    onExited: {
      for (var i = 0; i < expandedFiles.length; i++) {
        var path = expandedFiles[i];
        if (!root.parsedFiles[path] && root.filesToParse.indexOf(path) === -1) {
          root.filesToParse.push(path);
        }
      }
      expandedFiles = [];
      root.parseNextHyprlandFile();
    }
  }

  Process {
    id: hyprReadProcess
    property string currentFilePath: ""
    running: false

    stdout: SplitParser {
      onRead: data => {
        if (root.currentLines.length < 10000) {
          root.currentLines.push(data);
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && root.currentLines.length > 0) {
        for (var i = 0; i < root.currentLines.length; i++) {
          var line = root.currentLines[i];
          root.accumulatedLines.push(line);

          // Check for source directive
          var sourceMatch = line.trim().match(/^source\s*=\s*(.+)$/);
          if (sourceMatch) {
            var sourcePath = sourceMatch[1].trim();
            var commentIdx = sourcePath.indexOf('#');
            if (commentIdx > 0) sourcePath = sourcePath.substring(0, commentIdx).trim();
            var resolvedPath = root.resolveRelativePath(currentFilePath, sourcePath);
            if (!root.parsedFiles[resolvedPath] && root.filesToParse.indexOf(resolvedPath) === -1) {
              root.filesToParse.push(resolvedPath);
            }
          }
        }
      }
      root.currentLines = [];
      root.parseNextHyprlandFile();
    }
  }

  // ========== HYPRLAND PARSER ==========
  function parseHyprlandConfig(text) {
    var lines = text.split('\n');
    var categories = [];
    var currentCategory = null;

    // TUTAJ ZMIANA: Pobierz ustawioną zmienną (domyślnie $mod) i zamień na wielkie litery
    var modVar = pluginApi?.pluginSettings?.modKeyVariable || "$mod";
    var modVarUpper = modVar.toUpperCase();

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();

      // Category header: # 1. Category Name
      if (line.startsWith("#") && line.match(/#\s*\d+\./)) {
        if (currentCategory) {
          categories.push(currentCategory);
        }
        var title = line.replace(/#\s*\d+\.\s*/, "").trim();
        currentCategory = { "title": title, "binds": [] };
      }
      // Keybind: bind = $mod, T, exec, cmd #"description"
      else if (line.includes("bind") && line.includes('#"')) {
        if (currentCategory) {
          var descMatch = line.match(/#"(.*?)"$/);
          var description = descMatch ? descMatch[1] : "No description";

          var parts = line.split(',');
          if (parts.length >= 2) {
            var modPart = parts[0].split('=')[1].trim().toUpperCase();
            var rawKey = parts[1].trim().toUpperCase();
            var key = formatSpecialKey(rawKey);

            // Build modifiers list properly
            var mods = [];
            // TUTAJ ZMIANA: Sprawdzamy czy to ustawiony mod (np. $MAINMOD) albo SUPER
            if (modPart.includes(modVarUpper) || modPart.includes("SUPER")) mods.push("Super");

            if (modPart.includes("SHIFT")) mods.push("Shift");
            if (modPart.includes("CTRL") || modPart.includes("CONTROL")) mods.push("Ctrl");
            if (modPart.includes("ALT")) mods.push("Alt");

            // Build full key string
            var fullKey;
            if (mods.length > 0) {
              fullKey = mods.join(" + ") + " + " + key;
            } else {
              fullKey = key;
            }

            currentCategory.binds.push({
              "keys": fullKey,
              "desc": description
            });
          }
        }
      }
    }

    if (currentCategory) {
      categories.push(currentCategory);
    }

    saveToDb(categories);
    isCurrentlyParsing = false;
    clearParsingData();
  }

  // ========== NIRI PARSER ==========
  function parseNiriConfig(text) {
    var lines = text.split('\n');
    var inBindsBlock = false;
    var braceDepth = 0;
    var currentCategory = null;

    var actionCategories = {
      "spawn": "Applications",
      "focus-column": "Column Navigation",
      "focus-window": "Window Focus",
      "focus-workspace": "Workspace Navigation",
      "move-column": "Move Columns",
      "move-window": "Move Windows",
      "consume-window": "Window Management",
      "expel-window": "Window Management",
      "close-window": "Window Management",
      "fullscreen-window": "Window Management",
      "maximize-column": "Column Management",
      "set-column-width": "Column Width",
      "switch-preset-column-width": "Column Width",
      "reset-window-height": "Window Size",
      "screenshot": "Screenshots",
      "power-off-monitors": "Power",
      "quit": "System",
      "toggle-animation": "Animations"
    };

    var categorizedBinds = {};

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();

      // Find binds block
      if (line.startsWith("binds") && line.includes("{")) {
        inBindsBlock = true;
        braceDepth = 1;
        continue;
      }

      if (!inBindsBlock) continue;

      // Track brace depth
      for (var j = 0; j < line.length; j++) {
        if (line[j] === '{') braceDepth++;
        else if (line[j] === '}') braceDepth--;
      }

      if (braceDepth <= 0) {
        inBindsBlock = false;
        break;
      }

      // Category markers: // #"Category Name" - only these create categories
      if (line.startsWith("//")) {
        var categoryMatch = line.match(/\/\/\s*#"([^"]+)"/);
        if (categoryMatch) {
          currentCategory = categoryMatch[1];
        }
        continue;
      }

      if (line.length === 0) continue;

      // Parse: Mod+Key { action; }
      var bindMatch = line.match(/^([A-Za-z0-9_+]+)\s*(?:[a-z\-]+=\S+\s*)*\{\s*([^}]+)\s*\}/);

      if (bindMatch) {
        var keyCombo = bindMatch[1];
        var action = bindMatch[2].trim().replace(/;$/, '');

        var formattedKeys = formatNiriKeyCombo(keyCombo);
        var category = currentCategory || getNiriCategory(action, actionCategories);

        if (!categorizedBinds[category]) {
          categorizedBinds[category] = [];
        }

        categorizedBinds[category].push({
          "keys": formattedKeys,
          "desc": formatNiriAction(action)
        });
      }
    }

    // Convert to array
    var categoryOrder = [
      "Applications", "Window Management", "Column Navigation",
      "Window Focus", "Workspace Navigation", "Move Columns",
      "Move Windows", "Column Management", "Column Width",
      "Window Size", "Screenshots", "Power", "System", "Animations"
    ];

    var categories = [];
    for (var k = 0; k < categoryOrder.length; k++) {
      var catName = categoryOrder[k];
      if (categorizedBinds[catName] && categorizedBinds[catName].length > 0) {
        categories.push({
          "title": catName,
          "binds": categorizedBinds[catName]
        });
      }
    }

    // Add remaining categories
    for (var cat in categorizedBinds) {
      if (categoryOrder.indexOf(cat) === -1 && categorizedBinds[cat].length > 0) {
        categories.push({
          "title": cat,
          "binds": categorizedBinds[cat]
        });
      }
    }

    saveToDb(categories);
  }

  function formatSpecialKey(key) {
    var keyMap = {
      // Audio keys (uppercase for Hyprland)
      "XF86AUDIORAISEVOLUME": "Vol Up",
      "XF86AUDIOLOWERVOLUME": "Vol Down",
      "XF86AUDIOMUTE": "Mute",
      "XF86AUDIOMICMUTE": "Mic Mute",
      "XF86AUDIOPLAY": "Play",
      "XF86AUDIOPAUSE": "Pause",
      "XF86AUDIONEXT": "Next",
      "XF86AUDIOPREV": "Prev",
      "XF86AUDIOSTOP": "Stop",
      "XF86AUDIOMEDIA": "Media",
      // Audio keys (mixed case for Niri)
      "XF86AudioRaiseVolume": "Vol Up",
      "XF86AudioLowerVolume": "Vol Down",
      "XF86AudioMute": "Mute",
      "XF86AudioMicMute": "Mic Mute",
      "XF86AudioPlay": "Play",
      "XF86AudioPause": "Pause",
      "XF86AudioNext": "Next",
      "XF86AudioPrev": "Prev",
      "XF86AudioStop": "Stop",
      "XF86AudioMedia": "Media",
      // Brightness keys
      "XF86MONBRIGHTNESSUP": "Bright Up",
      "XF86MONBRIGHTNESSDOWN": "Bright Down",
      "XF86MonBrightnessUp": "Bright Up",
      "XF86MonBrightnessDown": "Bright Down",
      // Other common keys
      "XF86CALCULATOR": "Calc",
      "XF86MAIL": "Mail",
      "XF86SEARCH": "Search",
      "XF86EXPLORER": "Files",
      "XF86WWW": "Browser",
      "XF86HOMEPAGE": "Home",
      "XF86FAVORITES": "Favorites",
      "XF86POWEROFF": "Power",
      "XF86SLEEP": "Sleep",
      "XF86EJECT": "Eject",
      // Print screen
      "PRINT": "PrtSc",
      "Print": "PrtSc",
      // Navigation
      "PRIOR": "PgUp",
      "NEXT": "PgDn",
      "Prior": "PgUp",
      "Next": "PgDn",
      // Mouse (for Hyprland)
      "MOUSE_DOWN": "Scroll Down",
      "MOUSE_UP": "Scroll Up",
      "MOUSE:272": "Left Click",
      "MOUSE:273": "Right Click",
      "MOUSE:274": "Middle Click"
    };
    return keyMap[key] || key;
  }

  function formatNiriKeyCombo(combo) {
    // Split by + and process each part
    var parts = combo.split("+");
    var formattedParts = [];

    for (var i = 0; i < parts.length; i++) {
      var part = parts[i].trim();
      if (part.length === 0) continue;

      // Map modifier names
      if (part === "Mod" || part === "Super" || part === "Win") {
        formattedParts.push("Super");
      } else if (part === "Ctrl" || part === "Control") {
        formattedParts.push("Ctrl");
      } else if (part === "Alt") {
        formattedParts.push("Alt");
      } else if (part === "Shift") {
        formattedParts.push("Shift");
      } else {
        // It's a key - format special keys
        formattedParts.push(formatSpecialKey(part));
      }
    }

    return formattedParts.join(" + ");
  }

  function formatNiriAction(action) {
    // Handle spawn and spawn-sh commands
    if (action.startsWith("spawn")) {
      var spawnMatch = action.match(/spawn(?:-sh)?\s+"([^"]+)"/);
      if (spawnMatch) {
        return "Run: " + spawnMatch[1];
      }
      // Handle spawn with multiple arguments: spawn "cmd" "arg1" "arg2"
      var multiArgMatch = action.match(/spawn(?:-sh)?\s+"([^"]+)"/);
      if (multiArgMatch) {
        return "Run: " + multiArgMatch[1];
      }
      return action;
    }
    // Format action name: focus-column-left -> Focus Column Left
    return action.replace(/-/g, ' ').replace(/\b\w/g, function(l) { return l.toUpperCase(); });
  }

  function getNiriCategory(action, actionCategories) {
    for (var prefix in actionCategories) {
      if (action.startsWith(prefix)) {
        return actionCategories[prefix];
      }
    }
    return "Other";
  }

  function saveToDb(data) {
    if (pluginApi) {
      var compositor = getCurrentCompositor();
      pluginApi.pluginSettings.cheatsheetData = data;
      pluginApi.pluginSettings.detectedCompositor = compositor;
      pluginApi.saveSettings();
    }
  }

  IpcHandler {
    target: "plugin:keybind-cheatsheet"

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen);
        });
      }
    }
  }
}
