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
        short: pluginApi?.tr("error.sway-not-supported"),
        detail: pluginApi?.tr("error.sway-detail")
      },
      "labwc": {
        short: pluginApi?.tr("error.labwc-not-supported"),
        detail: pluginApi?.tr("error.labwc-detail")
      },
      "unknown": {
        short: pluginApi?.tr("error.unknown-compositor"),
        detail: pluginApi?.tr("error.unknown-detail")
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
    if (mangoGlobProcess.running) mangoGlobProcess.running = false;
    if (mangoReadProcess.running) mangoReadProcess.running = false;

    // Clear process buffers
    niriGlobProcess.expandedFiles = [];
    hyprGlobProcess.expandedFiles = [];
    mangoGlobProcess.expandedFiles = [];
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
    if (!CompositorService.isHyprland && !CompositorService.isNiri && !CompositorService.isMango) {
      isCurrentlyParsing = false;

      var unsupportedMsg = getUnsupportedCompositorMessage(compositorName);
      saveToDb([{
        "title": pluginApi?.tr("error.unsupported-compositor"),
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
    } else if (CompositorService.isNiri) {
      filePath = pluginApi?.pluginSettings?.niriConfigPath || (homeDir + "/.config/niri/config.kdl");
    } else if (CompositorService.isMango) {
      filePath = pluginApi?.pluginSettings?.mangoConfigPath || (homeDir + "/.config/mango/config.conf");
    }
    filePath = filePath.replace(/^~/, homeDir);

    filesToParse = [filePath];

    if (CompositorService.isHyprland) {
      parseNextHyprlandFile();
    } else if (CompositorService.isNiri) {
      parseNextNiriFile();
    } else if (CompositorService.isMango) {
      parseNextMangoFile();
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
      niriGlobProcess.command = ["sh", "-c", 'for f in $1; do [ -f "$f" ] && echo "$f"; done', "sh", nextFile];
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
        var bindStartMatch = line.match(/^([A-Za-z0-9_+]+)\s*((?:[a-z\-]+=(?:"[^"]*"|[1-9][0-9]*|true|false)\s*)*)\{(.*)$/);

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
      "Noctalia", "Applications", "Window Management", "Column Navigation",
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
      hyprGlobProcess.command = ["sh", "-c", 'for f in $1; do [ -f "$f" ] && echo "$f"; done', "sh", nextFile];
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
    var hasCategories = false; // Track if we found any category headers

    var modVar = pluginApi?.pluginSettings?.modKeyVariable || "$mod";
    var modVarUpper = modVar.toUpperCase();

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();

      // Category header: # 1. Category Name
      if (line.startsWith("#") && line.match(/#\s*\d+\./)) {
        hasCategories = true; // Found at least one category
        if (currentCategory) {
          categories.push(currentCategory);
        }
        var title = line.replace(/#\s*\d+\.\s*/, "").trim();
        currentCategory = { "title": title, "binds": [] };
      }
      // Keybind: bind = $mod, T, exec, cmd #"description"
      else if (line.includes("bind") && line.includes('#"')) {
        // If no categories found yet, create default category
        if (!currentCategory && !hasCategories) {
          var defaultCategoryName = pluginApi?.tr("default-category");
          currentCategory = { "title": defaultCategoryName, "binds": [] };
        }

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

  // ========== MANGO RECURSIVE PARSING ==========
  function parseNextMangoFile() {
    if (parseDepthCounter >= maxParseDepth) {
      isCurrentlyParsing = false;
      clearParsingData();
      return;
    }
    parseDepthCounter++;

    if (filesToParse.length === 0) {
      if (accumulatedLines.length > 0) {
        parseMangoConfig(accumulatedLines.join("\n"));
      } else {
        isCurrentlyParsing = false;
      }
      return;
    }

    var nextFile = filesToParse.shift();

    if (isGlobPattern(nextFile)) {
      mangoGlobProcess.expandedFiles = [];
      mangoGlobProcess.command = ["sh", "-c", 'for f in $1; do [ -f "$f" ] && echo "$f"; done', "sh", nextFile];
      mangoGlobProcess.running = true;
      return;
    }

    if (parsedFiles[nextFile]) {
      parseNextMangoFile();
      return;
    }

    parsedFiles[nextFile] = true;
    currentLines = [];
    mangoReadProcess.currentFilePath = nextFile;
    mangoReadProcess.command = ["cat", nextFile];
    mangoReadProcess.running = true;
  }

  Process {
    id: mangoGlobProcess
    property var expandedFiles: []
    running: false

    stdout: SplitParser {
      onRead: data => {
        var trimmed = data.trim();
        if (trimmed.length > 0 && mangoGlobProcess.expandedFiles.length < 100) {
          mangoGlobProcess.expandedFiles.push(trimmed);
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
      root.parseNextMangoFile();
    }
  }

  Process {
    id: mangoReadProcess
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

          // source=path (optionally source-optional=path)
          var sourceMatch = line.trim().match(/^source(?:-optional)?\s*=\s*(.+)$/);
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
      root.parseNextMangoFile();
    }
  }

  // ========== MANGO PARSER ==========
  //
  // Format: bind=MODS,KEY,ACTION[,ARGS...]          (and axisbind= for scroll binds)
  // Modifiers: SUPER, SHIFT, CTRL, ALT, NONE; combined with +  e.g. SUPER+SHIFT
  // Categories: # Title  or  # N. Title  (horizontal-rule dashes stripped)
  // Optional per-bind description: trailing  #"description"
  function parseMangoConfig(text) {
    var lines = text.split('\n');
    var categories = [];
    var currentCategory = null;
    var defaultCategoryName = pluginApi?.tr("default-category") || "Keybinds";

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.length === 0) continue;

      if (line.charAt(0) === "#") {
        var catName = extractMangoCategory(line);
        if (catName) {
          if (currentCategory && currentCategory.binds.length > 0) {
            categories.push(currentCategory);
          }
          currentCategory = { "title": catName, "binds": [] };
        }
        continue;
      }

      var bindMatch = line.match(/^(bind|axisbind|mousebind)\s*=\s*(.+)$/);
      if (!bindMatch) continue;

      var directiveKind = bindMatch[1]; // "bind" | "axisbind" | "mousebind"
      var rest = bindMatch[2];

      var explicitDesc = null;
      var descMatch = rest.match(/#"([^"]*)"\s*$/);
      if (descMatch) {
        explicitDesc = descMatch[1];
        rest = rest.substring(0, descMatch.index).trim();
      }

      var commentIdx = findMangoUnquotedComment(rest);
      if (commentIdx >= 0) {
        rest = rest.substring(0, commentIdx).trim();
      }
      rest = rest.replace(/,\s*$/, "");

      var fields = rest.split(',');
      for (var f = 0; f < fields.length; f++) fields[f] = fields[f].trim();
      if (fields.length < 3) continue;

      var modPart = fields[0];
      var rawKey = fields[1];
      var action = fields[2];
      var args = fields.slice(3);

      if (!currentCategory) {
        currentCategory = { "title": defaultCategoryName, "binds": [] };
      }

      var formattedKeys = formatMangoKeyCombo(modPart, rawKey, directiveKind);
      var description = explicitDesc || formatMangoAction(action, args);

      currentCategory.binds.push({
        "keys": formattedKeys,
        "desc": description
      });
    }

    if (currentCategory && currentCategory.binds.length > 0) {
      categories.push(currentCategory);
    }

    saveToDb(categories);
    isCurrentlyParsing = false;
    clearParsingData();
  }

  function extractMangoCategory(line) {
    var stripped = line.replace(/^#+\s*/, "").trim();
    stripped = stripped.replace(/^[─—━–\-=_]+\s*/, "").replace(/\s*[─—━–\-=_]+$/, "").trim();
    var numbered = stripped.match(/^\d+\.\s*(.+)$/);
    if (numbered) stripped = numbered[1].trim();
    if (stripped.length === 0 || stripped.length > 100) return null;
    // Skip parenthetical continuations and lines with flow arrows
    if (stripped.charAt(0) === "(") return null;
    if (stripped.indexOf("→") !== -1 || stripped.indexOf("←") !== -1) return null;
    return stripped;
  }

  function findMangoUnquotedComment(str) {
    var inQuotes = false;
    for (var i = 0; i < str.length; i++) {
      var c = str.charAt(i);
      if (c === '"') { inQuotes = !inQuotes; continue; }
      if (c === '#' && !inQuotes) {
        if (str.charAt(i + 1) !== '"') return i;
      }
    }
    return -1;
  }

  // kind: "bind" | "axisbind" | "mousebind"
  function formatMangoKeyCombo(modStr, key, kind) {
    var mods = [];
    var modUpper = (modStr || "").toUpperCase();
    if (modUpper.indexOf("SUPER") !== -1 || modUpper.indexOf("LOGO") !== -1) mods.push("Super");
    if (modUpper.indexOf("SHIFT") !== -1) mods.push("Shift");
    if (modUpper.indexOf("CTRL") !== -1 || modUpper.indexOf("CONTROL") !== -1) mods.push("Ctrl");
    if (modUpper.indexOf("ALT") !== -1 || modUpper.indexOf("MOD1") !== -1) mods.push("Alt");

    var k = key || "";
    var kUp = k.toUpperCase();

    if (kind === "axisbind" && mangoAxisMap[kUp]) {
      k = mangoAxisMap[kUp];
    } else if (kind === "mousebind" && mangoButtonMap[kUp]) {
      k = mangoButtonMap[kUp];
    } else if (!/^code:/i.test(k)) {
      // code:NN keycodes kept verbatim so users see the raw keycode.
      k = formatSpecialKey(k);
      if (mangoKeyNameMap[k]) k = mangoKeyNameMap[k];
    }

    if (mods.length === 0) return k;
    return mods.join(" + ") + " + " + k;
  }

  // Mango action -> human-readable description
  function formatMangoAction(action, args) {
    // spawn / spawn_shell: Noctalia IPC or generic command
    if (action === "spawn" || action === "spawn_shell" || action === "spawn-sh") {
      var cmd = args.join(",").trim();
      if (cmd.indexOf("noctalia-shell") !== -1 && cmd.indexOf("ipc") !== -1) {
        var ipcMatch = cmd.match(/ipc\s+call\s+([\w:.\-]+)\s+(\w+)/);
        if (ipcMatch) {
          var target = ipcMatch[1];
          var fn = ipcMatch[2];
          var ipcKey = target + " " + fn;
          if (noctaliaIpcLabels[ipcKey]) return noctaliaIpcLabels[ipcKey];
          // plugin:<name> targets: format as "Plugin Name: Function"
          var pluginMatch = target.match(/^plugin:(.+)$/);
          if (pluginMatch) {
            var pname = pluginMatch[1].replace(/[_\-]/g, ' ').replace(/\b\w/g, function(l) { return l.toUpperCase(); });
            var fLabel = fn.replace(/([A-Z])/g, ' $1').replace(/^./, function(l) { return l.toUpperCase(); }).trim();
            return pname + ": " + fLabel;
          }
          return target.replace(/([A-Z])/g, ' $1').trim() + ": " +
                 fn.replace(/([A-Z])/g, ' $1').trim();
        }
      }
      var first = cmd.split(/\s+/)[0] || cmd;
      var basename = first.split('/').pop();
      // Strip nix store hash prefix: abc123xyz-pkgname -> pkgname
      var stripHash = basename.match(/^[a-z0-9]{32,}-(.+)$/);
      if (stripHash) basename = stripHash[1];
      return "Run: " + (basename || cmd);
    }

    if (mangoNoArgActions[action]) return mangoNoArgActions[action];

    if (mangoDirActions[action] && args.length > 0) {
      var dir = args[0];
      return mangoDirActions[action] + " " + dir.charAt(0).toUpperCase() + dir.slice(1);
    }

    if (action === "focusstack" && args.length > 0) {
      if (args[0] === "next") return "Focus Next Window";
      if (args[0] === "prev") return "Focus Previous Window";
    }

    if (action === "view" && args.length > 0) return "Workspace " + args[0];
    if (action === "tag" && args.length > 0) return "Send to Workspace " + args[0];
    if (action === "toggletag" && args.length > 0) return "Toggle Workspace " + args[0];
    if (action === "toggleview" && args.length > 0) return "Toggle View Workspace " + args[0];

    if (action === "set_proportion" && args.length > 0) {
      var v = parseFloat(args[0]);
      if (!isNaN(v)) return "Column width " + Math.round(v * 100) + "%";
    }

    if (action === "toggle_named_scratchpad" && args.length > 0) {
      return "Scratchpad: " + args[0];
    }

    // moveresize etc. for mousebind
    if (action === "moveresize" && args.length > 0) {
      var mr = args[0];
      if (mr === "curmove") return "Move window";
      if (mr === "curresize") return "Resize window";
      return "Move/Resize: " + mr;
    }

    var formatted = action.replace(/[_\-]/g, ' ').replace(/\b\w/g, function(l) { return l.toUpperCase(); });
    if (args.length > 0) formatted += " " + args.join(", ");
    return formatted;
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

  // Mango lookup tables, hoisted to module level to avoid per-bind allocation.
  readonly property var mangoKeyNameMap: ({
    "Return": "Enter", "return": "Enter",
    "equal": "=", "minus": "-", "plus": "+",
    "space": "Space", "comma": ",", "period": ".",
    "semicolon": ";", "apostrophe": "'", "grave": "`",
    "slash": "/", "backslash": "\\",
    "bracketleft": "[", "bracketright": "]",
    "Escape": "Esc", "escape": "Esc"
  })
  readonly property var mangoAxisMap: ({
    "UP": "Scroll Up", "DOWN": "Scroll Down",
    "LEFT": "Scroll Left", "RIGHT": "Scroll Right"
  })
  readonly property var mangoButtonMap: ({
    "BTN_LEFT": "Left Click", "BTN_RIGHT": "Right Click",
    "BTN_MIDDLE": "Middle Click", "BTN_SIDE": "Mouse Side",
    "BTN_EXTRA": "Mouse Extra"
  })
  readonly property var mangoNoArgActions: ({
    "killclient": "Close window",
    "togglefullscreen": "Toggle fullscreen",
    "togglemaximizescreen": "Maximize",
    "togglefloating": "Toggle floating",
    "reload_config": "Reload config",
    "toggleoverview": "Toggle overview",
    "quit": "Quit compositor",
    "switch_proportion_preset": "Cycle column width",
    "switch_keyboard_layout": "Switch keyboard layout",
    "zoom": "Zoom",
    "restart": "Restart",
    "incnmaster": "Increase masters",
    "switch_layout": "Switch layout"
  })
  readonly property var mangoDirActions: ({
    "focusdir": "Focus",
    "exchange_client": "Swap",
    "focusmon": "Focus Monitor",
    "tagmon": "Send to Monitor"
  })

  // Map Noctalia IPC target+function to human-readable descriptions
  property var noctaliaIpcLabels: ({
    "launcher toggle": "Launcher",
    "launcher clipboard": "Clipboard History",
    "launcher command": "Command Palette",
    "launcher emoji": "Emoji Picker",
    "launcher windows": "Window Switcher",
    "launcher settings": "Launcher Settings",
    "controlCenter toggle": "Control Center",
    "settings toggle": "Settings",
    "settings open": "Open Settings",
    "sessionMenu toggle": "Session Menu",
    "sessionMenu lock": "Lock & Session Menu",
    "lockScreen lock": "Lock Screen",
    "volume increase": "Volume Up",
    "volume decrease": "Volume Down",
    "volume muteOutput": "Mute Output",
    "volume muteInput": "Mute Input",
    "volume increaseInput": "Input Volume Up",
    "volume decreaseInput": "Input Volume Down",
    "brightness increase": "Brightness Up",
    "brightness decrease": "Brightness Down",
    "media playPause": "Play / Pause",
    "media next": "Next Track",
    "media previous": "Previous Track",
    "media play": "Play",
    "media pause": "Pause",
    "media stop": "Stop",
    "media toggle": "Media Panel",
    "notifications toggleDND": "Do Not Disturb",
    "notifications toggleHistory": "Notification History",
    "notifications clear": "Clear Notifications",
    "notifications dismissAll": "Dismiss All",
    "wallpaper refresh": "Refresh Wallpaper",
    "wallpaper toggle": "Wallpaper Panel",
    "wallpaper toggleAutomation": "Toggle Wallpaper Automation",
    "darkMode toggle": "Toggle Dark Mode",
    "darkMode setDark": "Dark Mode",
    "darkMode setLight": "Light Mode",
    "nightLight toggle": "Toggle Night Light",
    "dock toggle": "Toggle Dock",
    "bar toggle": "Toggle Bar",
    "desktopWidgets toggle": "Toggle Desktop Widgets",
    "desktopWidgets edit": "Edit Desktop Widgets",
    "calendar toggle": "Calendar",
    "systemMonitor toggle": "System Monitor",
    "idleInhibitor toggle": "Toggle Idle Inhibitor",
    "monitors off": "Monitors Off",
    "monitors on": "Monitors On",
    "wifi toggle": "Toggle WiFi",
    "bluetooth toggle": "Toggle Bluetooth",
    "airplaneMode toggle": "Toggle Airplane Mode",
    "powerProfile cycle": "Cycle Power Profile",
    "battery togglePanel": "Battery Panel",
    "network togglePanel": "Network Panel"
  })

  function formatNiriAction(action) {
    // Detect Noctalia IPC commands in two formats:
    // 1. spawn-sh "qs -c noctalia-shell ipc call target function"
    // 2. spawn "qs" "-c" "noctalia-shell" "ipc" "call" "target" "function"
    if (action.indexOf("noctalia-shell") !== -1 && action.indexOf("ipc") !== -1) {
      // Extract target and function from either format:
      // spawn-sh: ipc call target function (words separated by spaces)
      // spawn multi-arg: "ipc" "call" "target" "function" (words wrapped in quotes)
      var ipcMatch = action.match(/ipc\s+call\s+(\w+)\s+(\w+)/) ||
                     action.match(/"ipc"\s+"call"\s+"(\w+)"\s+"(\w+)"/);
      if (ipcMatch) {
        var ipcKey = ipcMatch[1] + " " + ipcMatch[2];
        if (noctaliaIpcLabels[ipcKey]) {
          return noctaliaIpcLabels[ipcKey];
        }
        // Fallback: format target + function nicely
        return ipcMatch[1].replace(/([A-Z])/g, ' $1').trim() + ": " +
               ipcMatch[2].replace(/([A-Z])/g, ' $1').trim();
      }
    }

    // Handle spawn and spawn-sh commands
    if (action.startsWith("spawn")) {
      var spawnMatch = action.match(/spawn(?:-sh)?\s+"([^"]+)"/);
      if (spawnMatch) {
        return "Run: " + spawnMatch[1];
      }
      return action;
    }
    // Format action name: focus-column-left -> Focus Column Left
    return action.replace(/-/g, ' ').replace(/\b\w/g, function(l) { return l.toUpperCase(); });
  }

  function getNiriCategory(action, actionCategories) {
    // Noctalia IPC commands get their own category
    if (action.indexOf("noctalia-shell") !== -1 && action.indexOf("ipc") !== -1) {
      return "Noctalia";
    }
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
