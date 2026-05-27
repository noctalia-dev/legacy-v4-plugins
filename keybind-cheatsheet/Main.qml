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

  // Bug 4 fix: version counter so Panel.qml can react to data updates
  property int cheatsheetDataVersion: 0

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
    if (hyprDetectProcess.running) hyprDetectProcess.running = false;
    if (hyprLuaReadProcess.running) hyprLuaReadProcess.running = false;
    if (hyprctlBindsProcess.running) hyprctlBindsProcess.running = false;

    // Clear process buffers
    niriGlobProcess.expandedFiles = [];
    hyprGlobProcess.expandedFiles = [];
    mangoGlobProcess.expandedFiles = [];
    hyprctlChunks = [];
    currentLines = [];
  }

  function clearParsingData() {
    filesToParse = [];
    parsedFiles = {};
    accumulatedLines = [];
    currentLines = [];
    collectedBinds = {};
    parseDepthCounter = 0;
    luaCategoryHeaders = [];
    descToCategory = ({});
    prefixToCategory = [];
    hyprctlChunks = [];
    if (mangoGlobProcess.running) mangoGlobProcess.running = false;
    if (mangoReadProcess.running) mangoReadProcess.running = false;
    mangoGlobProcess.expandedFiles = [];
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

      Logger.w("KeybindCheatsheet", "Unsupported compositor:", compositorName);
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
      Logger.e("KeybindCheatsheet", "Cannot resolve $HOME environment variable");
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
      hyprConfPath = (pluginApi?.pluginSettings?.hyprlandConfigPath || (homeDir + "/.config/hypr/hyprland.conf")).replace(/^~/, homeDir);
      hyprLuaPath = (pluginApi?.pluginSettings?.hyprlandLuaConfigPath || (homeDir + "/.config/hypr/hyprland.lua")).replace(/^~/, homeDir);

      var mode = pluginApi?.pluginSettings?.hyprlandParserMode || "auto";
      if (mode === "conf") {
        startHyprlandConfTor();
      } else if (mode === "lua") {
        startHyprlandLuaTor();
      } else {
        // auto: prefer lua if hyprland.lua exists, else fall back to .conf
        hyprDetectProcess.command = ["sh", "-c", '[ -f "$1" ] && echo lua || echo conf', "sh", hyprLuaPath];
        hyprDetectProcess.running = true;
      }
      return;
    }

    if (CompositorService.isNiri) {
      filePath = pluginApi?.pluginSettings?.niriConfigPath || (homeDir + "/.config/niri/config.kdl");
    } else if (CompositorService.isMango) {
      filePath = pluginApi?.pluginSettings?.mangoConfigPath || (homeDir + "/.config/mango/config.conf");
    }

    filePath = filePath.replace(/^~/, homeDir);
    filesToParse = [filePath];

    if (CompositorService.isNiri) {
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
      Logger.w("KeybindCheatsheet", "Niri parser hit max recursion depth (" + maxParseDepth + "), aborting");
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
        // First pass: find includes (Bug 1: skip commented-out lines)
        for (var i = 0; i < root.currentLines.length; i++) {
          var line = root.currentLines[i];
          // Bug 1 fix: skip lines starting with // (they are comments, not active includes)
          if (line.trim().startsWith("//")) continue;
          var includeMatch = line.match(/(?:include|source)\s+"([^"]+)"/i);
          if (includeMatch) {
            var includePath = includeMatch[1];
            var resolvedPath = root.resolveRelativePath(currentFilePath, includePath);
            if (!root.parsedFiles[resolvedPath] && root.filesToParse.indexOf(resolvedPath) === -1) {
              root.filesToParse.push(resolvedPath);
            }
          }
        }

        // Bug 2 fix: auto-discover standard Noctalia/common keybind files from the config dir
        var configDir = root.getDirectoryFromPath(currentFilePath);
        var standardFiles = [
          configDir + "/keybindings.common.kdl",
          configDir + "/keybindings.noctalia.kdl"
        ];
        for (var s = 0; s < standardFiles.length; s++) {
          var sf = standardFiles[s];
          if (!root.parsedFiles[sf] && root.filesToParse.indexOf(sf) === -1) {
            // We optimistically add them; parseNextNiriFile will skip if the cat fails
            root.filesToParse.push(sf);
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
        // Try to match a keybind start: Mod+Key or "Mod+Key" attributes { or Mod+Key { action; }
        // Bug 3 fix: support optional surrounding quotes on the key combo (e.g. "Mod+Return")
        var bindStartMatch = line.match(/^"?([A-Za-z0-9_+]+)"?\s*((?:[a-z\-]+=(?:"[^"]*"|[1-9][0-9]*|true|false)\s*)*)\{(.*)$/);

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

      // Extract verb (first whitespace-separated token of action)
      var verbMatch = action.match(/^([A-Za-z0-9_\-]+)/);
      var verb = verbMatch ? verbMatch[1] : "";

      // Decompose key combo into modifier set + main key for merge/filter logic
      var rawParts = currentBindKey.split("+");
      var mods = [];
      var mainKey = "";
      for (var p = 0; p < rawParts.length; p++) {
        var rp = rawParts[p].trim();
        if (rp === "Mod" || rp === "Super" || rp === "Win" ||
            rp === "Ctrl" || rp === "Control" ||
            rp === "Alt" || rp === "Shift") {
          mods.push(rp === "Mod" || rp === "Win" ? "Super" : (rp === "Control" ? "Ctrl" : rp));
        } else if (rp.length > 0) {
          mainKey = rp;
        }
      }

      if (!collectedBinds[category]) {
        collectedBinds[category] = [];
      }
      collectedBinds[category].push({
        "keys": formattedKeys,
        "desc": description,
        "_verb": verb,
        "_mods": mods.join("+"),
        "_mainKey": mainKey
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

    if (categories.length === 0) {
      Logger.w("KeybindCheatsheet", "Niri parser produced no binds; check config path and binds {} block");
    }

    if (pluginApi?.pluginSettings?.mergeSequentialBinds ?? true) {
      categories = mergeSequentialBindsInCategories(categories);
    }

    saveToDb(categories);
    isCurrentlyParsing = false;
    clearParsingData();
  }

  // ========== MERGE SEQUENTIAL KEYBINDS ==========
  // Detects runs of consecutive numeric binds with identical modifiers, identical
  // verb, and descriptions that differ only by the integer.
  // Example: Super+1..5 → "Workspace 1", "Workspace 2", ... → "Workspace 1-5"
  function mergeSequentialBindsInCategories(cats) {
    if (!cats || cats.length === 0) return cats;
    var out = [];
    for (var c = 0; c < cats.length; c++) {
      var cat = cats[c];
      out.push({ "title": cat.title, "binds": mergeBindsList(cat.binds || []) });
    }
    return out;
  }

  function mergeBindsList(binds) {
    if (!binds || binds.length < 2) return binds;

    // Build a list of merge tokens for each bind:
    //   token = mods + "|" + verb + "|" + descriptionTemplate
    // descriptionTemplate replaces standalone integers with "%N%"
    var tokens = [];
    var nums = [];
    for (var i = 0; i < binds.length; i++) {
      var b = binds[i];
      var mainKey = b._mainKey || "";
      var asInt = parseInt(mainKey, 10);
      var keyIsInteger = !isNaN(asInt) && /^\d+$/.test(mainKey);
      var descTemplate = (b.desc || "").replace(/\b\d+\b/g, "%N%");
      tokens.push({
        mods: b._mods || "",
        verb: b._verb || "",
        descTemplate: descTemplate,
        keyIsInteger: keyIsInteger,
        num: keyIsInteger ? asInt : NaN,
        bind: b
      });
      nums.push(keyIsInteger ? asInt : NaN);
    }

    var result = [];
    var i = 0;
    while (i < tokens.length) {
      var startTok = tokens[i];
      if (!startTok.keyIsInteger) {
        result.push(startTok.bind);
        i++;
        continue;
      }

      // Try to extend a run as long as next bind has same mods/verb/descTemplate
      // and num is exactly previous + 1
      var runEnd = i;
      while (runEnd + 1 < tokens.length) {
        var nextTok = tokens[runEnd + 1];
        if (!nextTok.keyIsInteger) break;
        if (nextTok.mods !== startTok.mods) break;
        if (nextTok.verb !== startTok.verb) break;
        if (nextTok.descTemplate !== startTok.descTemplate) break;
        if (nextTok.num !== tokens[runEnd].num + 1) break;
        runEnd++;
      }

      var runLen = runEnd - i + 1;
      if (runLen >= 3) {
        // Collapse the run into a single ranged entry.
        var firstBind = startTok.bind;
        var lastBind = tokens[runEnd].bind;
        var lo = startTok.num;
        var hi = tokens[runEnd].num;
        var rangeStr = lo + "-" + hi;

        // Reconstruct keys with the range token. Keep the modifier prefix from
        // the first bind exactly as displayed (it already contains " + ").
        var firstKeys = firstBind.keys || "";
        var lastPlus = firstKeys.lastIndexOf(" + ");
        var prefix = lastPlus >= 0 ? firstKeys.substring(0, lastPlus + 3) : "";
        var mergedKeys = prefix + rangeStr;

        // Replace the integer in the description template with the range
        var mergedDesc = (firstBind.desc || "").replace(/\b\d+\b/, rangeStr);

        result.push({
          "keys": mergedKeys,
          "desc": mergedDesc,
          "_verb": firstBind._verb,
          "_mods": firstBind._mods,
          "_mainKey": rangeStr,
          "_merged": true
        });
        i = runEnd + 1;
      } else {
        result.push(startTok.bind);
        i++;
      }
    }
    return result;
  }

  // ========== HYPRLAND TOR SELECTION ==========
  property string hyprConfPath: ""
  property string hyprLuaPath: ""

  Process {
    id: hyprDetectProcess
    running: false
    property string result: ""
    stdout: SplitParser {
      onRead: data => { hyprDetectProcess.result = data.trim(); }
    }
    onExited: {
      if (result === "lua") {
        root.startHyprlandLuaTor();
      } else {
        root.startHyprlandConfTor();
      }
    }
  }

  function startHyprlandConfTor() {
    filesToParse = [hyprConfPath];
    parseNextHyprlandFile();
  }

  function startHyprlandLuaTor() {
    // Read hyprland.lua + required modules to recover category headers,
    // then query hyprctl for the authoritative (loop/require-expanded) binds.
    luaCategoryHeaders = [];
    descToCategory = ({});
    prefixToCategory = [];
    filesToParse = [hyprLuaPath];
    parseNextHyprLuaFile();
  }

  // ========== HYPRLAND LUA TOR (hyprctl binds -j) ==========
  property var luaCategoryHeaders: []   // ordered category titles from `-- N. NAME`
  property var descToCategory: ({})     // exact description -> category
  property var prefixToCategory: []     // [{prefix, category}] for loop-built binds
  property var hyprctlChunks: []

  function parseNextHyprLuaFile() {
    if (parseDepthCounter >= maxParseDepth) {
      runHyprctlBinds();
      return;
    }
    parseDepthCounter++;

    if (filesToParse.length === 0) {
      runHyprctlBinds();
      return;
    }

    var nextFile = filesToParse.shift();
    if (parsedFiles[nextFile]) {
      parseNextHyprLuaFile();
      return;
    }
    parsedFiles[nextFile] = true;
    currentLines = [];
    hyprLuaReadProcess.currentFilePath = nextFile;
    hyprLuaReadProcess.command = ["cat", nextFile];
    hyprLuaReadProcess.running = true;
  }

  Process {
    id: hyprLuaReadProcess
    property string currentFilePath: ""
    running: false

    stdout: SplitParser {
      onRead: data => {
        if (root.currentLines.length < 10000) root.currentLines.push(data);
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && root.currentLines.length > 0) {
        var currentCategory = null;
        for (var i = 0; i < root.currentLines.length; i++) {
          var line = root.currentLines[i];

          // require("a.b.c") / require 'a/b/c' -> a/b/c.lua relative to current file.
          // Lua module names use dots as path separators; literal paths (with /) and
          // .lua suffixes are passed through unchanged.
          var reqMatch = line.match(/require\s*\(?\s*["']([^"']+)["']/);
          if (reqMatch) {
            var mod = reqMatch[1];
            if (!mod.endsWith(".lua")) {
              if (mod.indexOf("/") === -1) mod = mod.replace(/\./g, "/");
              mod = mod + ".lua";
            }
            var resolved = root.resolveRelativePath(currentFilePath, mod);
            if (!root.parsedFiles[resolved] && root.filesToParse.indexOf(resolved) === -1) {
              root.filesToParse.push(resolved);
            }
          }

          // Category header: -- 1. NAME
          var headMatch = line.match(/^\s*--\s*\d+\.\s*(.+?)\s*$/);
          if (headMatch) {
            currentCategory = headMatch[1].trim();
            if (root.luaCategoryHeaders.indexOf(currentCategory) === -1) {
              root.luaCategoryHeaders.push(currentCategory);
            }
            continue;
          }

          // description = "..." / desc = '...'
          var dMatch = line.match(/(?:description|desc)\s*=\s*["']([^"']*)["']/);
          if (dMatch && currentCategory) {
            var lit = dMatch[1];
            if (line.indexOf("..") !== -1) {
              // Concatenated/dynamic description (e.g. "Workspace " .. i)
              var pfx = lit.trim();
              if (pfx.length > 0) root.prefixToCategory.push({ prefix: pfx, category: currentCategory });
            } else if (lit.length > 0 && root.descToCategory[lit] === undefined) {
              root.descToCategory[lit] = currentCategory;
            }
          }
        }
      }
      root.currentLines = [];
      root.parseNextHyprLuaFile();
    }
  }

  function runHyprctlBinds() {
    hyprctlChunks = [];
    hyprctlBindsProcess.command = ["hyprctl", "binds", "-j"];
    hyprctlBindsProcess.running = true;
  }

  Process {
    id: hyprctlBindsProcess
    running: false

    stdout: SplitParser {
      onRead: data => {
        if (root.hyprctlChunks.length < 20000) root.hyprctlChunks.push(data);
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 || root.hyprctlChunks.length === 0) {
        Logger.e("keybind-cheatsheet", "hyprctl binds -j failed (exit " + exitCode + ")");
        root.hyprctlChunks = [];
        root.saveToDb([{
          "title": root.pluginApi?.tr("error.unsupported-compositor"),
          "binds": [{ "keys": "hyprctl", "desc": root.pluginApi?.tr("error.hyprctl-failed") }]
        }]);
        root.isCurrentlyParsing = false;
        root.clearParsingData();
        return;
      }

      var binds = [];
      try {
        binds = JSON.parse(root.hyprctlChunks.join("\n"));
      } catch (e) {
        Logger.e("keybind-cheatsheet", "hyprctl JSON parse failed: " + e);
        binds = [];
      }
      root.hyprctlChunks = [];
      root.buildCategoriesFromHyprctl(binds);
    }
  }

  // Hyprland modifier bitmask (see HL_MODIFIER_*)
  function decodeModmask(mask) {
    var m = [];
    if (mask & 64) m.push("Super");   // LOGO / SUPER / META
    if (mask & 1)  m.push("Shift");
    if (mask & 4)  m.push("Ctrl");
    if (mask & 8)  m.push("Alt");
    if (mask & 16) m.push("Mod2");
    if (mask & 32) m.push("Mod3");
    if (mask & 128) m.push("Mod5");
    return m;
  }

  function computeBindId(b) {
    // `arg` is an unstable lua registry ref for __lua binds — exclude it there.
    var disp = (b.dispatcher === "__lua") ? "__lua" : (b.dispatcher + ":" + (b.arg || ""));
    var flags = (b.release ? 1 : 0) + "" + (b.mouse ? 1 : 0) + (b.longPress ? 1 : 0);
    return [b.submap || "", b.modmask, b.key, flags, disp].join("|");
  }

  function categoryForDesc(desc) {
    if (descToCategory[desc] !== undefined) return descToCategory[desc];
    for (var i = 0; i < prefixToCategory.length; i++) {
      if (desc.indexOf(prefixToCategory[i].prefix) === 0) return prefixToCategory[i].category;
    }
    return null;
  }

  function buildCategoriesFromHyprctl(binds) {
    var overrides = pluginApi?.pluginSettings?.bindOverrides || ({});
    var showUndescribed = pluginApi?.pluginSettings?.showUndescribedBinds ?? true;

    var byCat = ({});
    var otherTitle = pluginApi?.tr("panel.other");
    var undescTitle = pluginApi?.tr("panel.undescribed");

    for (var i = 0; i < binds.length; i++) {
      var b = binds[i];
      if (!b || b.key === undefined) continue;

      var bindId = computeBindId(b);
      var ov = overrides[bindId];
      if (ov && ov.hidden === true) continue;

      var rawDesc = (b.has_description && b.description) ? b.description : "";
      if (ov && ov.desc) rawDesc = ov.desc;
      var undescribed = (rawDesc === "");

      if (undescribed && !showUndescribed) continue;

      var keyName = formatSpecialKey(b.key);
      if (keyName === b.key) keyName = formatSpecialKey(String(b.key).toUpperCase());
      var mods = decodeModmask(b.modmask);
      var fullKey = mods.length > 0 ? (mods.join(" + ") + " + " + keyName) : keyName;

      var cat;
      if (undescribed) {
        cat = undescTitle;
      } else {
        cat = categoryForDesc(rawDesc) || otherTitle;
      }

      if (!byCat[cat]) byCat[cat] = [];
      byCat[cat].push({
        "keys": fullKey,
        "desc": undescribed ? "" : rawDesc,
        "bindId": bindId,
        "undescribed": undescribed
      });
    }

    // Emit categories in lua header order, then Other, then Undescribed last.
    var categories = [];
    for (var h = 0; h < luaCategoryHeaders.length; h++) {
      var t = luaCategoryHeaders[h];
      if (byCat[t] && byCat[t].length > 0) {
        categories.push({ "title": t, "binds": byCat[t] });
        delete byCat[t];
      }
    }
    if (byCat[otherTitle] && byCat[otherTitle].length > 0) {
      categories.push({ "title": otherTitle, "binds": byCat[otherTitle] });
      delete byCat[otherTitle];
    }
    var undesc = byCat[undescTitle];
    if (undesc && undesc.length > 0) delete byCat[undescTitle];
    // Any leftover categories (shouldn't normally happen)
    for (var k in byCat) {
      if (byCat[k] && byCat[k].length > 0) categories.push({ "title": k, "binds": byCat[k] });
    }
    if (undesc && undesc.length > 0) {
      categories.push({ "title": undescTitle, "binds": undesc });
    }

    saveToDb(categories);
    isCurrentlyParsing = false;
    clearParsingData();
  }

  // ========== HYPRLAND RECURSIVE PARSING ==========
  function parseNextHyprlandFile() {
    if (parseDepthCounter >= maxParseDepth) {
      Logger.w("KeybindCheatsheet", "Hyprland parser hit max recursion depth (" + maxParseDepth + "), aborting");
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
    var skippedNoDesc = 0;

    var modVar = pluginApi?.pluginSettings?.modKeyVariable || "$mod";
    var modVarUpper = modVar.toUpperCase();
    var includeUndescribed = pluginApi?.pluginSettings?.showUndescribedBinds ?? false;

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
      // Any bind directive (bind, bindm, binde, bindr, bindl, etc.)
      else if (/^bind[a-z]*\s*=/.test(line)) {
        var hasDesc = line.includes('#"');
        if (!hasDesc && !includeUndescribed) {
          skippedNoDesc++;
          continue;
        }

        // If no categories found yet, create default category
        if (!currentCategory && !hasCategories) {
          var defaultCategoryName = pluginApi?.tr("default-category");
          currentCategory = { "title": defaultCategoryName, "binds": [] };
        }

        if (currentCategory) {
          var description;
          if (hasDesc) {
            var descMatch = line.match(/#"(.*?)"$/);
            description = descMatch ? descMatch[1] : "No description";
          } else {
            description = "";
          }

          // Strip the trailing #"..." comment so it doesn't pollute parts splitting
          var bindLine = hasDesc ? line.replace(/\s*#".*?"\s*$/, "") : line;

          var eqIdx = bindLine.indexOf("=");
          if (eqIdx < 0) continue;
          var rhs = bindLine.substring(eqIdx + 1);
          var parts = rhs.split(',');
          if (parts.length >= 2) {
            var modPart = parts[0].trim().toUpperCase();
            var rawKey = parts[1].trim().toUpperCase();
            var key = formatSpecialKey(rawKey);

            var verb = parts.length >= 3 ? parts[2].trim().toLowerCase() : "";
            var param = parts.length >= 4 ? parts.slice(3).join(",").trim() : "";

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

            // Auto-generate description for undescribed binds when included
            if (!hasDesc && includeUndescribed) {
              description = verb ? (verb + (param ? " " + param : "")) : pluginApi?.tr("panel.no-description");
            }

            currentCategory.binds.push({
              "keys": fullKey,
              "desc": description,
              "_verb": verb,
              "_param": param,
              "_mods": mods.join("+"),
              "_mainKey": rawKey
            });
          }
        }
      }
    }

    if (currentCategory) {
      categories.push(currentCategory);
    }

    if (skippedNoDesc > 0) {
      Logger.w("KeybindCheatsheet", "Skipped " + skippedNoDesc + " Hyprland binds without #\"description\" suffix (enable showUndescribedBinds to include)");
    }

    if (categories.length === 0 || categories.every(function(c) { return !c.binds || c.binds.length === 0; })) {
      Logger.w("KeybindCheatsheet", "Hyprland parser produced no binds; check config path and #\"description\" annotations");
    }

    if (pluginApi?.pluginSettings?.mergeSequentialBinds ?? true) {
      categories = mergeSequentialBindsInCategories(categories);
    }

    saveToDb(categories);
    isCurrentlyParsing = false;
    clearParsingData();
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
      // Bug 4 fix: bump version counter so Panel.qml re-evaluates its data binding
      cheatsheetDataVersion++;
    }
  }

  // ========== MANGO LOOKUP TABLES ==========
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

  // ========== MANGO RECURSIVE PARSING ==========
  function parseNextMangoFile() {
    if (parseDepthCounter >= maxParseDepth) {
      Logger.w("KeybindCheatsheet", "Mango parser hit max recursion depth (" + maxParseDepth + "), aborting");
      isCurrentlyParsing = false;
      clearParsingData();
      return;
    }
    parseDepthCounter++;

    if (filesToParse.length === 0) {
      finalizeMangoBinds();
      return;
    }

    var nextFile = filesToParse.shift();

    // Handle glob patterns
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
        if (trimmed.length > 0) {
          if (mangoGlobProcess.expandedFiles.length < 100) {
            mangoGlobProcess.expandedFiles.push(trimmed);
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
        // First pass: find source/source-optional includes
        for (var i = 0; i < root.currentLines.length; i++) {
          var line = root.currentLines[i].trim();
          // Skip commented lines
          var commentPos = root.findMangoUnquotedComment(line);
          var effectiveLine = commentPos >= 0 ? line.substring(0, commentPos).trim() : line;

          var srcMatch = effectiveLine.match(/^source-optional\s*=\s*(.+)$/) ||
                         effectiveLine.match(/^source\s*=\s*(.+)$/);
          if (srcMatch) {
            var srcPath = srcMatch[1].trim();
            var resolvedSrc = root.resolveRelativePath(currentFilePath, srcPath);
            if (isGlobPattern(resolvedSrc)) {
              if (root.filesToParse.indexOf(resolvedSrc) === -1) {
                root.filesToParse.push(resolvedSrc);
              }
            } else if (!root.parsedFiles[resolvedSrc] && root.filesToParse.indexOf(resolvedSrc) === -1) {
              root.filesToParse.push(resolvedSrc);
            }
          }
        }
        // Second pass: parse keybinds from this file
        root.parseMangoConfig(root.currentLines.join("\n"));
      }
      root.currentLines = [];
      root.parseNextMangoFile();
    }
  }

  function findMangoUnquotedComment(str) {
    var inSingle = false;
    var inDouble = false;
    for (var i = 0; i < str.length; i++) {
      var ch = str[i];
      if (ch === "'" && !inDouble) { inSingle = !inSingle; continue; }
      if (ch === '"' && !inSingle) { inDouble = !inDouble; continue; }
      if (ch === '#' && !inSingle && !inDouble) {
        // Per-bind description suffix: #"description" — not a comment
        if (str.charAt(i + 1) === '"') continue;
        return i;
      }
    }
    return -1;
  }

  function parseMangoConfig(text) {
    var lines = text.split('\n');
    var currentCategory = null;
    var defaultCat = pluginApi?.tr("default-category");

    for (var i = 0; i < lines.length; i++) {
      var rawLine = lines[i];
      var commentPos = findMangoUnquotedComment(rawLine);
      var effectiveLine = commentPos >= 0 ? rawLine.substring(0, commentPos).trim() : rawLine.trim();

      // Pure-comment lines: only candidate for category detection (# Title)
      if (effectiveLine.length === 0) {
        var categoryCandidate = extractMangoCategory(rawLine);
        if (categoryCandidate !== null) {
          currentCategory = categoryCandidate;
        }
        continue;
      }

      // Extract optional per-bind description: trailing #"description"
      var perBindDesc = null;
      var descMatch = effectiveLine.match(/#"([^"]*)"\s*$/);
      if (descMatch) {
        perBindDesc = descMatch[1];
        effectiveLine = effectiveLine.substring(0, descMatch.index).trim();
        if (effectiveLine.length === 0) continue;
      }

      // bind=MODS,KEY,ACTION,ARGS  (also `binds=` — keysym-based variant
      // used by layout-aware setups like AZERTY)
      var bindMatch = effectiveLine.match(/^binds?\s*=\s*(.+)$/);
      if (bindMatch) {
        var parts = bindMatch[1].split(',');
        if (parts.length >= 3) {
          var modStr = parts[0].trim();
          var key = parts[1].trim();
          var action = parts[2].trim();
          var args = parts.length >= 4 ? parts.slice(3).join(',').trim() : "";
          var cat = currentCategory || defaultCat;
          var formattedKeys = formatMangoKeyCombo(modStr, key, "bind");
          var description = perBindDesc || formatMangoAction(action, args);

          if (!collectedBinds[cat]) collectedBinds[cat] = [];
          collectedBinds[cat].push({ "keys": formattedKeys, "desc": description });
        }
        continue;
      }

      // axisbind=MODS,AXIS,ACTION,ARGS  (also `axisbinds=` keysym variant)
      var axisMatch = effectiveLine.match(/^axisbinds?\s*=\s*(.+)$/);
      if (axisMatch) {
        var axisParts = axisMatch[1].split(',');
        if (axisParts.length >= 3) {
          var aModStr = axisParts[0].trim();
          var axis = axisParts[1].trim().toUpperCase();
          var aAction = axisParts[2].trim();
          var aArgs = axisParts.length >= 4 ? axisParts.slice(3).join(',').trim() : "";
          var aCat = currentCategory || defaultCat;
          var aKey = mangoAxisMap[axis] || axis;
          var aCombo = formatMangoKeyCombo(aModStr, aKey, "axis");
          var aDesc = perBindDesc || formatMangoAction(aAction, aArgs);

          if (!collectedBinds[aCat]) collectedBinds[aCat] = [];
          collectedBinds[aCat].push({ "keys": aCombo, "desc": aDesc });
        }
        continue;
      }

      // mousebind=MODS,BTN,ACTION,ARGS  (also `mousebinds=` keysym variant)
      var mouseMatch = effectiveLine.match(/^mousebinds?\s*=\s*(.+)$/);
      if (mouseMatch) {
        var mouseParts = mouseMatch[1].split(',');
        if (mouseParts.length >= 3) {
          var mModStr = mouseParts[0].trim();
          var btn = mouseParts[1].trim().toUpperCase();
          var mAction = mouseParts[2].trim();
          var mArgs = mouseParts.length >= 4 ? mouseParts.slice(3).join(',').trim() : "";
          var mCat = currentCategory || defaultCat;
          var mKey = mangoButtonMap[btn] || btn;
          var mCombo = formatMangoKeyCombo(mModStr, mKey, "mouse");
          var mDesc = perBindDesc || formatMangoAction(mAction, mArgs);

          if (!collectedBinds[mCat]) collectedBinds[mCat] = [];
          collectedBinds[mCat].push({ "keys": mCombo, "desc": mDesc });
        }
      }
    }
  }

  function extractMangoCategory(line) {
    var trimmed = line.trim();
    // A category line is a standalone comment: # Category Name
    if (!trimmed.startsWith('#')) return null;
    // Strip leading hashes (#, ##, ###, ...)
    var rest = trimmed.replace(/^#+/, '').trim();
    if (rest.length === 0) return null;

    // Length cap — categories shouldn't be paragraphs ("# TODO fix later" etc.)
    if (rest.length > 100) return null;

    // Pure horizontal rule (only decorative chars): ────, ====, ----, ****
    if (/^[─━═=\-_*#/\\\s]+$/.test(rest)) return null;

    // Reject paren/bracket continuation: "(continued)", "(see above)", "[note]"
    if (/^[\(\[]/.test(rest)) return null;

    // Reject flow arrows: "→ next step", "->", "=>"
    if (/^[→←↑↓⇒⇐➜➔►▶]/.test(rest)) return null;
    if (rest.indexOf('->') === 0 || rest.indexOf('=>') === 0) return null;

    // Reject keyword-prefixed notes: "# TODO ...", "# FIXME ...", "# NOTE ..."
    if (/^(TODO|FIXME|NOTE|HACK|XXX|BUG|WIP)\b/i.test(rest)) return null;

    // Strip trailing horizontal-rule decoration: "Category ────" -> "Category"
    rest = rest.replace(/[─━═=\-_*]{3,}\s*$/, '').trim();
    if (rest.length === 0) return null;

    // Numbered list extraction: "1. Foo" -> "Foo"
    var numbered = rest.match(/^\d+\.\s*(.+)$/);
    if (numbered) return numbered[1].trim();

    return rest;
  }

  function formatMangoKeyCombo(modStr, key, kind) {
    var mods = [];
    var modUpper = modStr.toUpperCase();
    // SUPER aliases: SUPER, LOGO
    if (modUpper.indexOf("SUPER") !== -1 || modUpper.indexOf("LOGO") !== -1) mods.push("Super");
    if (modUpper.indexOf("SHIFT") !== -1) mods.push("Shift");
    if (modUpper.indexOf("CTRL") !== -1 || modUpper.indexOf("CONTROL") !== -1) mods.push("Ctrl");
    // ALT aliases: ALT, MOD1
    if (modUpper.indexOf("ALT") !== -1 || modUpper.indexOf("MOD1") !== -1) mods.push("Alt");

    // Map the key name. For bind keys, prefer XF86 special-key formatting (Vol Up, Mute, ...).
    var mappedKey;
    if (kind === "bind") {
      var specialMapped = formatSpecialKey(key);
      mappedKey = (specialMapped !== key) ? specialMapped : (mangoKeyNameMap[key] || key);
    } else {
      mappedKey = key;
    }

    if (mods.length > 0) {
      return mods.join(" + ") + " + " + mappedKey;
    }
    return mappedKey;
  }

  function formatMangoAction(action, args) {
    // Check Noctalia IPC calls: spawn_shell with qs ipc call ...
    if (args.indexOf("noctalia-shell") !== -1 && args.indexOf("ipc") !== -1) {
      var ipcMatch = args.match(/ipc\s+call\s+(\w+)\s+(\w+)/);
      if (ipcMatch) {
        var ipcKey = ipcMatch[1] + " " + ipcMatch[2];
        if (noctaliaIpcLabels[ipcKey]) return noctaliaIpcLabels[ipcKey];
        return ipcMatch[1] + ": " + ipcMatch[2];
      }
    }

    // No-arg actions
    if (mangoNoArgActions[action]) return mangoNoArgActions[action];

    // Direction actions
    if (mangoDirActions[action]) {
      var dir = args ? args.toUpperCase() : "";
      return mangoDirActions[action] + (dir ? " " + dir : "");
    }

    // spawn / spawn_shell
    if (action === "spawn" || action === "spawn_shell") {
      return args ? "Run: " + args : "Run command";
    }

    // workspace / move to workspace
    if (action === "workspace") return args ? "Workspace " + args : "Switch workspace";
    if (action === "movetoworkspace") return args ? "Move to workspace " + args : "Move to workspace";
    if (action === "movetoworkspacesilent") return args ? "Move (silent) to workspace " + args : "Move to workspace";

    // Generic fallback: convert snake_case / camelCase to readable
    return action.replace(/_/g, ' ').replace(/([A-Z])/g, ' $1').trim()
                 .replace(/\b\w/g, function(l) { return l.toUpperCase(); });
  }

  function finalizeMangoBinds() {
    var categories = [];
    for (var cat in collectedBinds) {
      if (collectedBinds[cat].length > 0) {
        categories.push({ "title": cat, "binds": collectedBinds[cat] });
      }
    }

    if (categories.length === 0) {
      Logger.w("KeybindCheatsheet", "Mango parser produced no binds; check config path and bind= directives");
    }

    saveToDb(categories);
    isCurrentlyParsing = false;
    clearParsingData();
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

    function refresh() {
      root.refresh();
    }
  }
}
