import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import "ProviderLogic.js" as ProviderLogic
import "Constants.js" as Constants

Item {
  // Internal flag to prevent duplicate error messages
  id: root

  property var pluginApi: null
  property string _responseBuffer: ""

  // AI Chat state
  property var messages: []
  property bool isGenerating: false
  property string currentResponse: ""
  property string errorMessage: ""
  property bool isManuallyStopped: false

  // Tool state
  property var toolSchemas: []
  property int toolCount: 0
  property bool isExecutingTools: false
  property var _pendingToolCalls: []
  property bool _hasToolCallsToProcess: false
  property var _toolCallQueue: []
  property int _currentToolCallIndex: 0
  property int _toolIterationCount: 0

  // Tool confirmation state
  property bool awaitingToolConfirmation: false
  property var pendingToolConfirmation: null  // the tool call awaiting approval

  // Tool settings accessors
  readonly property bool toolsEnabled: pluginApi?.pluginSettings?.tools?.enabled ?? true
  readonly property int maxToolIterations: pluginApi?.pluginSettings?.tools?.maxIterations ?? 10
  readonly property int toolTimeout: pluginApi?.pluginSettings?.tools?.timeout ?? 30
  readonly property string toolsDir: {
    var custom = pluginApi?.pluginSettings?.tools?.directory || "";
    if (custom !== "") return custom;
    // Default: tools/ relative to this QML file's directory
    var url = Qt.resolvedUrl("tools").toString();
    if (url.startsWith("file://")) return url.substring(7);
    return url;
  }

  // Translation state
  property string translatedText: ""
  property bool isTranslating: false
  property string translationError: ""

  // Cache directory for state (messages, activeTab) - use global noctalia cache
  readonly property string cacheDir: typeof Settings !== 'undefined' && Settings.cacheDir ? Settings.cacheDir + "plugins/assistant-panel/" : ""
  readonly property string stateCachePath: cacheDir + "state.json"

  property string activeTab: "ai"  // UI state - persisted to cache
  property string chatInputText: "" // Chat input state - persisted to cache
  property int chatInputCursorPosition: 0 // Chat input cursor position - persisted to cache

  // Provider configurations
  readonly property var providers: ({
      [Constants.Providers.GOOGLE]: {
        "name": "Google Gemini",
        "defaultModel": "gemini-2.5-flash",
        "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key={apiKey}",
        "streamEndpoint": "https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse&key={apiKey}"
      },
      [Constants.Providers.OPENAI_COMPATIBLE]: {
        "name": "OpenAI Compatible",
        "defaultModel": "gpt-4o-mini",
        // Endpoint is dynamic based on settings (openaiBaseUrl)
        "endpoint": ""
      }
    })

  // Settings accessors
  readonly property string provider: pluginApi?.pluginSettings?.ai?.provider || Constants.Providers.GOOGLE
  // Prefer per-provider mapping `ai.models[provider]` (if non-empty), fall back to provider default
  readonly property string model: {
    var saved = pluginApi?.pluginSettings?.ai?.models?.[provider];
    if (saved !== undefined && saved !== "")
      return saved;
    return providers[provider]?.defaultModel || "";
  }

  // Environment variable API keys - priority over settings
  readonly property var envApiKeys: ({
      [Constants.Providers.GOOGLE]: Quickshell.env("NOCTALIA_AP_GOOGLE_API_KEY") || "",
      [Constants.Providers.OPENAI_COMPATIBLE]: Quickshell.env("NOCTALIA_AP_OPENAI_COMPATIBLE_API_KEY") || ""
    })

  // API Key Priority: Environment Variable > Local Settings
  readonly property string envApiKey: envApiKeys[provider] || ""
  readonly property string settingsApiKey: (pluginApi?.pluginSettings?.ai?.apiKeys && pluginApi.pluginSettings.ai.apiKeys[provider]) || ""
  readonly property string apiKey: envApiKey !== "" ? envApiKey : settingsApiKey
  readonly property bool apiKeyManagedByEnv: envApiKey !== ""

  // DeepL translator env var support
  readonly property string envDeeplApiKey: Quickshell.env("NOCTALIA_AP_DEEPL_API_KEY") || ""
  readonly property real temperature: pluginApi?.pluginSettings?.ai?.temperature || 0.7
  readonly property string systemPrompt: pluginApi?.pluginSettings?.ai?.systemPrompt || ""

  // OpenAI Compatible Settings
  readonly property bool openaiLocal: pluginApi?.pluginSettings?.ai?.openaiLocal ?? false
  readonly property string openaiBaseUrl: {
    var url = pluginApi?.pluginSettings?.ai?.openaiBaseUrl || "";
    if (url === "")
      return "https://api.openai.com/v1/chat/completions";
    return url;
  }

  Component.onCompleted: {
    Logger.i("AssistantPanel", "Plugin initialized");
    // State loading is handled by FileView onLoaded
    ensureCacheDir();
    discoverTools();
  }

  // Ensure cache directory exists
  function ensureCacheDir() {
    if (cacheDir) {
      Quickshell.execDetached(["mkdir", "-p", cacheDir]);
    }
  }

  // FileView for state cache (messages, activeTab)
  FileView {
    id: stateCacheFile
    path: root.stateCachePath
    watchChanges: false

    onLoaded: {
      loadStateFromCache();
    }

    onLoadFailed: function (error) {
      if (error === 2) {
        // File doesn't exist, start fresh
        Logger.d("AssistantPanel", "No cache file found, starting fresh");
      } else {
        Logger.e("AssistantPanel", "Failed to load state cache: " + error);
      }
    }
  }

  // Load state from cache file
  function loadStateFromCache() {
    var content = stateCacheFile.text();
    var result = ProviderLogic.processLoadedState(content);

    if (!result) {
      Logger.d("AssistantPanel", "Empty cache file, starting fresh");
      return;
    }

    if (result.error) {
      Logger.e("AssistantPanel", "Failed to parse state cache: " + result.error);
      return;
    }

    root.messages = result.messages;
    root.activeTab = result.activeTab;
    root.chatInputText = result.chatInputText;
    root.chatInputCursorPosition = result.chatInputCursorPosition;
    Logger.d("AssistantPanel", "Loaded " + root.messages.length + " messages from cache");
  }

  // Debounced save timer
  Timer {
    id: saveStateTimer
    interval: 500
    onTriggered: performSaveState()
  }

  property bool saveStateQueued: false

  function saveState() {
    saveStateQueued = true;
    saveStateTimer.restart();
  }

  function performSaveState() {
    if (!saveStateQueued || !cacheDir)
      return;
    saveStateQueued = false;

    try {
      ensureCacheDir();

      var maxHistory = pluginApi?.pluginSettings?.maxHistoryLength || 100;
      var dataStr = ProviderLogic.prepareStateForSave(
        root.messages,
        root.activeTab,
        maxHistory,
        root.chatInputText,
        root.chatInputCursorPosition
      );

      stateCacheFile.setText(dataStr);
    } catch (e) {
      Logger.e("AssistantPanel", "Failed to save state cache: " + e);
    }
  }

  // Add a message to the chat
  function addMessage(role, content, extra) {
    var newMessage = {
      "id": Date.now().toString() + "_" + Math.random().toString(36).substr(2, 4),
      "role": role,
      "content": content,
      "timestamp": new Date().toISOString()
    };
    if (extra) {
      var keys = Object.keys(extra);
      for (var i = 0; i < keys.length; i++) {
        newMessage[keys[i]] = extra[keys[i]];
      }
    }
    root.messages = [...root.messages, newMessage];
    saveState();
    return newMessage;
  }

  // Clear chat history
  function clearMessages() {
    root.messages = [];
    saveState();
    Logger.i("AssistantPanel", "Chat history cleared");
  }

  // =====================
  // Tool Discovery
  // =====================
  Process {
    id: toolDiscoveryProcess

    stdout: StdioCollector {
      onStreamFinished: {
        root.handleToolDiscoveryResult(text);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          Logger.e("AssistantPanel", "Tool discovery stderr: " + text);
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        Logger.e("AssistantPanel", "Tool discovery failed with exit code " + exitCode);
      }
    }
  }

  function discoverTools() {
    Logger.i("AssistantPanel", "Discovering tools in: " + toolsDir);
    // Find all spec.json files with their parent directories, output as JSON array
    toolDiscoveryProcess.command = ["sh", "-c",
      "result='['; first=1; " +
      "for d in " + ProviderLogic.shellQuote(toolsDir) + "/*/; do " +
      "  if [ -f \"${d}spec.json\" ] && [ -x \"${d}run\" ]; then " +
      "    [ $first -eq 0 ] && result=\"${result},\"; " +
      "    spec=$(cat \"${d}spec.json\"); " +
      "    dir=$(echo \"$d\" | sed 's:/$::'); " +
      "    result=\"${result}$(echo \"$spec\" | jq -c --arg dir \"$dir\" '. + {\"_dir\": $dir}')\"; " +
      "    first=0; " +
      "  fi; " +
      "done; " +
      "echo \"${result}]\""
    ];
    toolDiscoveryProcess.running = true;
  }

  function handleToolDiscoveryResult(text) {
    if (!text || text.trim() === "") {
      Logger.i("AssistantPanel", "No tools found");
      root.toolSchemas = [];
      root.toolCount = 0;
      return;
    }

    try {
      var schemas = JSON.parse(text.trim());
      root.toolSchemas = schemas;
      root.toolCount = schemas.length;
      var names = schemas.map(function(s) { return s.name; }).join(", ");
      Logger.i("AssistantPanel", "Discovered " + schemas.length + " tools: " + names);
    } catch (e) {
      Logger.e("AssistantPanel", "Failed to parse tool discovery result: " + e);
      root.toolSchemas = [];
      root.toolCount = 0;
    }
  }

  // Get active tool schemas (only if tools are enabled)
  function getActiveToolSchemas() {
    if (!toolsEnabled || toolSchemas.length === 0) return [];
    // Strip internal _dir field for API payloads
    return toolSchemas.map(function(s) {
      return {
        name: s.name,
        description: s.description,
        parameters: s.parameters
      };
    });
  }

  // Find tool directory by name
  function findToolDir(toolName) {
    for (var i = 0; i < toolSchemas.length; i++) {
      if (toolSchemas[i].name === toolName) {
        return toolSchemas[i]._dir;
      }
    }
    return null;
  }

  // =====================
  // Tool Allowlist (with qualifier support)
  // =====================
  //
  // Allowlist keys:
  //   "clipboard"       → tool-level (tools without qualifierParam)
  //   "shell:ls"        → qualified (first word of qualifierParam value)
  //   "shell:*"         → wildcard (all qualifiers for this tool)
  //
  // Lookup order: tool:qualifier → tool:* → tool → "confirm"

  function getAllowlist() {
    return pluginApi?.pluginSettings?.tools?.allowlist || {};
  }

  function setAllowlistEntry(key, status) {
    if (!pluginApi) return;
    if (!pluginApi.pluginSettings.tools)
      pluginApi.pluginSettings.tools = {};
    if (!pluginApi.pluginSettings.tools.allowlist)
      pluginApi.pluginSettings.tools.allowlist = {};
    pluginApi.pluginSettings.tools.allowlist[key] = status;
    pluginApi.saveSettings();
    Logger.i("AssistantPanel", "Allowlist '" + key + "' set to: " + status);
  }

  function removeAllowlistEntry(key) {
    if (!pluginApi) return;
    var al = pluginApi.pluginSettings?.tools?.allowlist;
    if (!al) return;
    delete al[key];
    pluginApi.pluginSettings.tools.allowlist = al;
    pluginApi.saveSettings();
    Logger.i("AssistantPanel", "Allowlist entry removed: " + key);
  }

  // =====================
  // Command Parsing for Qualifier Extraction
  // =====================

  // Quote-aware tokenizer: split a shell command on operators (&&, ||, ;, |)
  // while respecting single/double quotes and escapes.
  // Returns array of command segments, or null if unparseable (subshells, substitutions).
  function splitShellCommand(command) {
    if (!command) return null;

    // Bail on command substitutions and subshells — can't safely analyze
    if (command.indexOf("$(") >= 0) return null;
    if (command.indexOf("`") >= 0) return null;
    if (command.indexOf("\n") >= 0) return null;

    var segments = [];
    var current = "";
    var inSingle = false;
    var inDouble = false;
    var escaped = false;

    for (var i = 0; i < command.length; i++) {
      var c = command[i];

      if (escaped) { current += c; escaped = false; continue; }
      if (c === "\\") { current += c; escaped = true; continue; }
      if (c === "'" && !inDouble) { inSingle = !inSingle; current += c; continue; }
      if (c === '"' && !inSingle) { inDouble = !inDouble; current += c; continue; }

      if (!inSingle && !inDouble) {
        var rest = command.substring(i);
        // Check two-char operators first
        if (rest.startsWith("&&") || rest.startsWith("||")) {
          if (current.trim()) segments.push(current.trim());
          current = "";
          i++; // skip second char
          continue;
        }
        // Single-char operators
        if (c === "|" || c === ";") {
          if (current.trim()) segments.push(current.trim());
          current = "";
          continue;
        }
        // Redirections — not an operator split, but note the command uses them
        // We still allow the command through, just don't split on > or <
      }

      current += c;
    }

    // Unclosed quotes = unparseable
    if (inSingle || inDouble) return null;
    if (current.trim()) segments.push(current.trim());

    return segments.length > 0 ? segments : null;
  }

  // Extract the binary (first word) from a single command segment,
  // skipping leading env assignments (KEY=VAL).
  function extractBinary(segment) {
    if (!segment) return null;
    var words = segment.trim().split(/\s+/);
    for (var i = 0; i < words.length; i++) {
      var w = words[i];
      // Skip env variable assignments (KEY=VAL)
      if (w.indexOf("=") > 0 && w.indexOf("=") < w.length - 1) continue;
      return w;
    }
    return words[0] || null;
  }

  // Extract ALL command binaries from a shell command string.
  // Returns array of binary names, or null if unparseable.
  function extractAllCommands(command) {
    var segments = splitShellCommand(command);
    if (!segments) return null;

    var binaries = [];
    for (var i = 0; i < segments.length; i++) {
      var binary = extractBinary(segments[i]);
      if (binary) binaries.push(binary);
    }
    return binaries.length > 0 ? binaries : null;
  }

  // Extract single qualifier for a tool call — used by the UI for "Allow `tool:cmd`" button.
  // Only returns a value for simple (single-command) invocations.
  function extractQualifier(tc) {
    for (var i = 0; i < toolSchemas.length; i++) {
      if (toolSchemas[i].name === tc.name && toolSchemas[i].qualifierParam) {
        var paramName = toolSchemas[i].qualifierParam;
        var args;
        try {
          args = typeof tc.arguments === "string" ? JSON.parse(tc.arguments) : (tc.arguments || {});
        } catch (e) { return null; }

        var val = args[paramName];
        if (!val || typeof val !== "string") return null;

        var binaries = extractAllCommands(val);
        // Only return qualifier for simple single-command invocations
        if (!binaries || binaries.length !== 1) return null;
        return binaries[0];
      }
    }
    return null; // No qualifierParam for this tool
  }

  // Check if a tool has a qualifierParam defined
  function toolHasQualifier(toolName) {
    for (var i = 0; i < toolSchemas.length; i++) {
      if (toolSchemas[i].name === toolName && toolSchemas[i].qualifierParam) {
        return true;
      }
    }
    return false;
  }

  // Get full approval for a tool call
  // Lookup: tool:qualifier → tool:* → tool → "confirm"
  // For compound commands (ls | grep): checks each binary individually
  function getFullToolApproval(tc) {
    var al = getAllowlist();

    // Check tool-level "never" first (blocks everything)
    if (al[tc.name] === "never") return "never";

    var qualifier = extractQualifier(tc);

    if (qualifier) {
      // Single command — check tool:qualifier
      var qualifiedKey = tc.name + ":" + qualifier;
      if (al[qualifiedKey]) return al[qualifiedKey];

      // Check tool:*
      var wildcardKey = tc.name + ":*";
      if (al[wildcardKey]) return al[wildcardKey];
    } else if (toolHasQualifier(tc.name)) {
      // Compound command or unparseable — try checking all binaries
      var args;
      try {
        args = typeof tc.arguments === "string" ? JSON.parse(tc.arguments) : (tc.arguments || {});
      } catch (e) { return "confirm"; }

      var paramName = null;
      for (var i = 0; i < toolSchemas.length; i++) {
        if (toolSchemas[i].name === tc.name && toolSchemas[i].qualifierParam) {
          paramName = toolSchemas[i].qualifierParam;
          break;
        }
      }
      if (paramName) {
        var val = args[paramName];
        var binaries = val ? extractAllCommands(val) : null;
        if (binaries && binaries.length > 1) {
          // Check each binary against allowlist; all must be approved
          var allApproved = true;
          for (var j = 0; j < binaries.length; j++) {
            var bKey = tc.name + ":" + binaries[j];
            var bWild = tc.name + ":*";
            if (al[bKey] === "never" || al[bWild] === "never") return "never";
            if (al[bKey] !== "always" && al[bWild] !== "always") {
              allApproved = false;
            }
          }
          if (allApproved) return "always";
          // Not all approved — fall through to confirm
        }
        // Unparseable command (null from extractAllCommands) — fall through to confirm
      }
    }

    // Check tool-level
    if (al[tc.name]) return al[tc.name];

    return "confirm";
  }

  function approveToolOnce() {
    var tc = root.pendingToolConfirmation;
    if (!tc) return;
    root.awaitingToolConfirmation = false;
    root.pendingToolConfirmation = null;
    runToolExec(tc);
  }

  function approveToolAlways() {
    var tc = root.pendingToolConfirmation;
    if (!tc) return;
    root.awaitingToolConfirmation = false;
    root.pendingToolConfirmation = null;
    setAllowlistEntry(tc.name, "always");
    runToolExec(tc);
  }

  // Approve a specific qualifier (e.g., "shell:ls", "shell:cat")
  function approveQualifier(qualifiedKey) {
    var tc = root.pendingToolConfirmation;
    if (!tc) return;
    root.awaitingToolConfirmation = false;
    root.pendingToolConfirmation = null;
    setAllowlistEntry(qualifiedKey, "always");
    runToolExec(tc);
  }

  function denyToolOnce() {
    var tc = root.pendingToolConfirmation;
    if (!tc) return;
    root.awaitingToolConfirmation = false;
    root.pendingToolConfirmation = null;

    addMessage("tool", "Tool call denied by user.", {
      "tool_call_id": tc.id,
      "tool_name": tc.name,
      "tool_args": tc.arguments,
      "denied": true
    });

    _currentToolCallIndex++;
    executeNextTool();
  }

  // =====================
  // Tool Execution
  // =====================
  Process {
    id: toolExecProcess

    stdout: StdioCollector {
      onStreamFinished: {
        root._toolExecStdout = text;
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        root._toolExecStderr = text;
      }
    }

    onExited: function (exitCode, exitStatus) {
      root.handleToolExecComplete(exitCode);
    }
  }

  property string _toolExecStdout: ""
  property string _toolExecStderr: ""

  function handleToolCalls(toolCalls) {
    if (!toolCalls || toolCalls.length === 0) return;

    Logger.i("AssistantPanel", "Processing " + toolCalls.length + " tool call(s)");

    // Add assistant message with tool_calls
    addMessage("assistant", root.currentResponse.trim(), { "tool_calls": toolCalls });
    root.currentResponse = "";

    _toolCallQueue = toolCalls;
    _currentToolCallIndex = 0;
    root.isExecutingTools = true;

    executeNextTool();
  }

  function executeNextTool() {
    if (_currentToolCallIndex >= _toolCallQueue.length) {
      // All tools executed — check iteration limit and re-request
      root.isExecutingTools = false;
      _toolIterationCount++;

      if (_toolIterationCount >= maxToolIterations) {
        Logger.w("AssistantPanel", "Max tool iterations reached (" + maxToolIterations + ")");
        addMessage("assistant", "(Tool use stopped: maximum iterations reached)");
        root.isGenerating = false;
        return;
      }

      continueAfterTools();
      return;
    }

    var tc = _toolCallQueue[_currentToolCallIndex];

    // Check allowlist (including shell command-level for shell tool)
    var approval = getFullToolApproval(tc);

    if (approval === "never") {
      Logger.i("AssistantPanel", "Tool '" + tc.name + "' is denied by allowlist");
      addMessage("tool", "Tool '" + tc.name + "' is blocked. Change in settings to allow.", {
        "tool_call_id": tc.id,
        "tool_name": tc.name,
        "tool_args": tc.arguments,
        "denied": true
      });
      _currentToolCallIndex++;
      executeNextTool();
      return;
    }

    if (approval !== "always") {
      // Need confirmation — pause and show prompt
      Logger.i("AssistantPanel", "Awaiting confirmation for tool: " + tc.name);
      root.pendingToolConfirmation = tc;
      root.awaitingToolConfirmation = true;
      return; // Paused — user action will resume
    }

    // Approved — run immediately
    runToolExec(tc);
  }

  function runToolExec(tc) {
    var toolDir = findToolDir(tc.name);

    if (!toolDir) {
      Logger.e("AssistantPanel", "Tool not found: " + tc.name);
      addMessage("tool", "Error: tool '" + tc.name + "' not found", {
        "tool_call_id": tc.id,
        "tool_name": tc.name,
        "tool_args": tc.arguments
      });
      _currentToolCallIndex++;
      executeNextTool();
      return;
    }

    var argsJson = typeof tc.arguments === "string" ? tc.arguments : JSON.stringify(tc.arguments || {});
    Logger.i("AssistantPanel", "Executing tool: " + tc.name + " with args: " + argsJson);

    // Store current tool info for the completion handler
    root._currentExecutingToolCall = tc;

    _toolExecStdout = "";
    _toolExecStderr = "";
    toolExecProcess.command = ProviderLogic.buildToolExecCommand(toolDir, argsJson, toolTimeout);
    toolExecProcess.running = true;
  }

  property var _currentExecutingToolCall: null

  function handleToolExecComplete(exitCode) {
    var tc = root._currentExecutingToolCall;
    if (!tc) return;

    var result = _toolExecStdout || "";
    if (exitCode !== 0) {
      if (_toolExecStderr) {
        result = result ? (result + "\n" + _toolExecStderr) : _toolExecStderr;
      }
      if (!result) result = "Tool exited with code " + exitCode;

      // Check for timeout (exit code 124 from timeout command)
      if (exitCode === 124) {
        result = "Error: tool timed out after " + toolTimeout + " seconds";
      }
    }

    // Truncate very long results
    if (result.length > 10000) {
      result = result.substring(0, 10000) + "\n...(truncated, " + result.length + " chars total)";
    }

    var argsStr = typeof tc.arguments === "string" ? tc.arguments : JSON.stringify(tc.arguments || {});
    var argsParsed;
    try { argsParsed = typeof tc.arguments === "string" ? JSON.parse(tc.arguments) : (tc.arguments || {}); }
    catch (e) { argsParsed = {}; }

    Logger.i("AssistantPanel", "Tool " + tc.name + " completed (exit=" + exitCode + ", " + result.length + " chars)");

    addMessage("tool", result, {
      "tool_call_id": tc.id,
      "tool_name": tc.name,
      "tool_args": argsParsed
    });

    _currentToolCallIndex++;
    executeNextTool();
  }

  function continueAfterTools() {
    Logger.i("AssistantPanel", "Continuing after tools (iteration " + _toolIterationCount + ")");
    root.currentResponse = "";

    if (provider === Constants.Providers.GOOGLE) {
      sendGeminiRequest();
    } else if (provider === Constants.Providers.OPENAI_COMPATIBLE) {
      sendOpenAIRequest();
    }
  }

  // =====================
  // Send Message
  // =====================
  function sendMessage(userMessage) {
    Logger.i("AssistantPanel", "sendMessage called with: " + userMessage);
    if (!userMessage || userMessage.trim() === "") {
      Logger.i("AssistantPanel", "sendMessage: empty message, abort");
      return;
    }
    if (root.isGenerating) {
      Logger.i("AssistantPanel", "sendMessage: already generating, abort");
      return;
    }

    // Check API key for non-local providers
    var requiresKey = true;
    if (provider === Constants.Providers.OPENAI_COMPATIBLE && openaiLocal) {
      requiresKey = false;
    }

    if (requiresKey && (!apiKey || apiKey.trim() === "")) {
      root.errorMessage = pluginApi?.tr("errors.noApiKey");
      Logger.e("AssistantPanel", "sendMessage: missing API key");
      ToastService.showError(root.errorMessage);
      return;
    }

    Logger.i("AssistantPanel", "Adding user message and starting generation");
    addMessage("user", userMessage.trim());

    root.isGenerating = true;
    root.isManuallyStopped = false;
    root.currentResponse = "";
    root.errorMessage = "";
    root._toolIterationCount = 0;
    root._pendingToolCalls = [];
    root._hasToolCallsToProcess = false;

    if (provider === Constants.Providers.GOOGLE) {
      Logger.i("AssistantPanel", "Calling sendGeminiRequest()");
      sendGeminiRequest();
    } else if (provider === Constants.Providers.OPENAI_COMPATIBLE) {
      Logger.i("AssistantPanel", "Calling sendOpenAIRequest() for " + provider);
      sendOpenAIRequest();
    } else {
      Logger.e("AssistantPanel", "Unknown provider: " + provider);
      root.errorMessage = "Unknown provider selected. Please check settings.";
      root.isGenerating = false;
    }
  }

  // Edit a message and regenerate from there
  function editMessage(id, newContent) {
    if (root.isGenerating)
      return;
    if (!newContent || newContent.trim() === "")
      return;
    var index = -1;
    for (var i = 0; i < root.messages.length; i++) {
      if (root.messages[i].id === id) {
        index = i;
        break;
      }
    }

    if (index === -1)
      return;

    // Truncate history to this message (exclusive)
    root.messages = root.messages.slice(0, index);

    // Add the updated message as a new user message
    sendMessage(newContent);
  }

  // Regenerate the last assistant response
  function regenerateLastResponse() {
    if (root.isGenerating)
      return;
    if (root.messages.length < 2)
      return;

    // Find and remove the last assistant message
    var lastIndex = -1;
    for (var i = root.messages.length - 1; i >= 0; i--) {
      if (root.messages[i].role === "assistant") {
        lastIndex = i;
        break;
      }
    }

    if (lastIndex >= 0) {
      root.messages = root.messages.slice(0, lastIndex);
      saveState();

      root.isGenerating = true;
      root.currentResponse = "";
      root.errorMessage = "";
      root._toolIterationCount = 0;
      root._pendingToolCalls = [];
      root._hasToolCallsToProcess = false;

      if (provider === Constants.Providers.GOOGLE) {
        sendGeminiRequest();
      } else if (provider === Constants.Providers.OPENAI_COMPATIBLE) {
        sendOpenAIRequest();
      }
    }
  }

  // Stop generation
  function stopGeneration() {
    if (!root.isGenerating)
      return;
    Logger.i("AssistantPanel", "Stopping generation");

    root.isManuallyStopped = true;
    if (geminiProcess.running)
      geminiProcess.running = false;
    if (openaiProcess.running)
      openaiProcess.running = false;
    if (toolExecProcess.running)
      toolExecProcess.running = false;

    root.isGenerating = false;
    root.isExecutingTools = false;
    // If we have a partial response, add it to chat history
    if (root.currentResponse.trim() !== "") {
      root.addMessage("assistant", root.currentResponse.trim());
    }
    root.currentResponse = "";
  }

  // Build conversation history for API
  function buildConversationHistory() {
    var history = [];
    for (var i = 0; i < root.messages.length; i++) {
      var msg = root.messages[i];
      var entry = {
        "role": msg.role,
        "content": msg.content
      };
      if (msg.tool_calls) entry.tool_calls = msg.tool_calls;
      if (msg.tool_call_id) entry.tool_call_id = msg.tool_call_id;
      if (msg.tool_name) entry.tool_name = msg.tool_name;
      history.push(entry);
    }
    return history;
  }

  // Common handler for when a provider stream completes
  function handleStreamComplete() {
    // Check if there are tool calls to process (check array regardless of flag)
    var toolCalls = [];
    for (var i = 0; i < root._pendingToolCalls.length; i++) {
      if (root._pendingToolCalls[i]) {
        toolCalls.push(root._pendingToolCalls[i]);
      }
    }

    if (toolCalls.length > 0) {
      Logger.i("AssistantPanel", "Stream complete with " + toolCalls.length + " tool call(s) to process");
      root._pendingToolCalls = [];
      root._hasToolCallsToProcess = false;
      handleToolCalls(toolCalls);
      return true; // Handled as tool calls
    }
    return false; // Normal completion
  }

  // =====================
  // Google Gemini API
  // =====================
  Process {
    id: geminiProcess

    property string buffer: ""

    stdout: SplitParser {
      onRead: function (data) {
        geminiProcess.handleStreamData(data);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          // Try to parse JSON error from stderr if possible
          try {
            var json = JSON.parse(text);
            if (json.error && json.error.message) {
              root.errorMessage = json.error.message;
            } else {
              Logger.e("AssistantPanel", "Gemini stderr: " + text);
            }
          } catch (e) {
            Logger.e("AssistantPanel", "Gemini stderr: " + text);
          }
        }
      }
    }

    function handleStreamData(data) {
      var result = ProviderLogic.parseGeminiStream(data);
      if (!result)
        return;

      if (result.content) {
        root.currentResponse += result.content;
      }

      // Handle Gemini function calls (arrive as complete objects, not chunked)
      if (result.function_calls) {
        for (var i = 0; i < result.function_calls.length; i++) {
          var fc = result.function_calls[i];
          Logger.i("AssistantPanel", "Gemini: function call: " + fc.name + " args=" + JSON.stringify(fc.args || {}));
          root._pendingToolCalls.push({
            id: "gemini_" + Date.now() + "_" + i,
            name: fc.name,
            arguments: JSON.stringify(fc.args || {})
          });
        }
        root._hasToolCallsToProcess = true;
      }

      if (result.error) {
        Logger.e("AssistantPanel", "Gemini stream error: " + result.error);
        if (!result.error.startsWith("Error parsing SSE")) {
          root.errorMessage = result.error;
        }
      } else if (result.raw) {
        geminiProcess.buffer += result.raw;
        try {
          var errorJson = JSON.parse(geminiProcess.buffer);
          if (errorJson.error) {
            root.errorMessage = errorJson.error.message || "API error";
          }
          geminiProcess.buffer = "";
        } catch (e) {
          // Incomplete
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }

      geminiProcess.buffer = "";

      // Check for tool calls before completing
      if (root.handleStreamComplete()) {
        return; // Tool execution started
      }

      root.isGenerating = false;

      if (exitCode !== 0 && root.currentResponse === "") {
        if (root.errorMessage === "") {
          root.errorMessage = pluginApi?.tr("errors.requestFailed");
        }
        return;
      }

      if (root.currentResponse.trim() !== "") {
        root.addMessage("assistant", root.currentResponse.trim());
      }
      root.chatInputText = ""; // Ensure input is cleared after successful generation
      root.chatInputCursorPosition = 0;
      root.saveState();
    }
  }

  function sendGeminiRequest() {
    var history = buildConversationHistory();
    var activeTools = getActiveToolSchemas();
    var commandData = ProviderLogic.buildGeminiCommand(
      providers[Constants.Providers.GOOGLE].streamEndpoint,
      model, apiKey, systemPrompt, history, temperature, activeTools
    );

    Logger.i("AssistantPanel", "sendGeminiRequest: endpoint=" + commandData.url);
    geminiProcess.buffer = "";
    root._pendingToolCalls = [];
    root._hasToolCallsToProcess = false;
    geminiProcess.command = commandData.args;
    Logger.i("AssistantPanel", "sendGeminiRequest: starting process");
    _responseBuffer = "";
    geminiProcess.running = true;
  }

  // =====================
  // OpenAI API
  // =====================
  Process {
    id: openaiProcess

    property string buffer: ""

    stdout: SplitParser {
      onRead: function (data) {
        openaiProcess.handleStreamData(data);
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim() !== "") {
          Logger.e("AssistantPanel", "OpenAI stderr: " + text);
        } else {
          Logger.i("AssistantPanel", "OpenAI stderr: (empty)");
        }
      }
    }

    function handleStreamData(data) {
      var result = ProviderLogic.parseOpenAIStream(data);
      if (!result)
        return;

      if (result.content) {
        root.currentResponse += result.content;
      }

      // Handle tool call chunks (streamed incrementally)
      if (result.tool_call_chunks) {
        for (var i = 0; i < result.tool_call_chunks.length; i++) {
          var chunk = result.tool_call_chunks[i];
          var idx = chunk.index;

          // Initialize slot if new
          if (!root._pendingToolCalls[idx]) {
            root._pendingToolCalls[idx] = { id: "", name: "", arguments: "" };
            Logger.i("AssistantPanel", "OpenAI: new tool call slot " + idx);
          }
          if (chunk.id) root._pendingToolCalls[idx].id = chunk.id;
          if (chunk.name) {
            root._pendingToolCalls[idx].name = chunk.name;
            Logger.i("AssistantPanel", "OpenAI: tool call " + idx + " name=" + chunk.name);
          }
          root._pendingToolCalls[idx].arguments += chunk.arguments;
        }
      }

      // Mark tool calls for processing when finish_reason indicates it
      if (result.finish_reason === "tool_calls") {
        Logger.i("AssistantPanel", "OpenAI: finish_reason=tool_calls, " + root._pendingToolCalls.length + " calls pending");
        root._hasToolCallsToProcess = true;
      }

      if (result.error) {
        Logger.e("AssistantPanel", "OpenAI stream error: " + result.error);
      } else if (result.raw) {
        openaiProcess.buffer += result.raw;
        try {
          var errorJson = JSON.parse(openaiProcess.buffer);
          if (errorJson.error) {
            root.errorMessage = errorJson.error.message || "API error";
          }
          openaiProcess.buffer = "";
        } catch (e) {
          // Incomplete JSON, keep buffering
        }
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }

      // Check for tool calls before completing
      if (root.handleStreamComplete()) {
        openaiProcess.buffer = "";
        return; // Tool execution started
      }

      root.isGenerating = false;

      if (exitCode !== 0 && root.currentResponse === "") {
        if (root.errorMessage === "") {
          if (provider === Constants.Providers.OPENAI_COMPATIBLE && openaiLocal) {
            root.errorMessage = pluginApi?.tr("errors.localNotRunning");
          } else {
            root.errorMessage = pluginApi?.tr("errors.requestFailed");
          }
        }
        return;
      }

      if (root.currentResponse.trim() !== "") {
        root.addMessage("assistant", root.currentResponse.trim());
      }
      root.chatInputText = ""; // Ensure input is cleared after successful generation
      root.chatInputCursorPosition = 0;
      root.saveState();

      openaiProcess.buffer = "";
    }
  }

  function sendOpenAIRequest() {
    var history = buildConversationHistory();
    var activeTools = getActiveToolSchemas();
    var commandData = ProviderLogic.buildOpenAICommand(
      openaiBaseUrl, apiKey, model, systemPrompt, history, temperature, activeTools
    );

    Logger.i("AssistantPanel", "sendOpenAIRequest: endpoint=" + commandData.url);
    openaiProcess.buffer = "";
    root._pendingToolCalls = [];
    root._hasToolCallsToProcess = false;
    openaiProcess.command = commandData.args;

    Logger.i("AssistantPanel", "sendOpenAIRequest: starting process");
    openaiProcess.running = true;
  }

  // =====================
  // Translation
  // =====================
  readonly property string translatorBackend: pluginApi?.pluginSettings?.translator?.backend || "google"
  readonly property string sourceLanguage: pluginApi?.pluginSettings?.translator?.sourceLanguage || "auto"
  readonly property string targetLanguage: pluginApi?.pluginSettings?.translator?.targetLanguage || "en"
  readonly property string settingsDeeplApiKey: pluginApi?.pluginSettings?.translator?.deeplApiKey || ""
  readonly property string deeplApiKey: envDeeplApiKey !== "" ? envDeeplApiKey : settingsDeeplApiKey
  readonly property bool deeplApiKeyManagedByEnv: envDeeplApiKey !== ""

  function translate(text, targetLang, sourceLang) {
    if (!text || text.trim() === "") {
      root.translatedText = "";
      return;
    }

    root.isTranslating = true;
    root.translationError = "";

    var target = targetLang || targetLanguage;
    var source = sourceLang || sourceLanguage;

    if (translatorBackend === "google") {
      translateGoogle(text.trim(), target, source);
    } else if (translatorBackend === "deepl") {
      translateDeepL(text.trim(), target);
    }
  }

  Process {
    id: translateProcess

    stdout: StdioCollector {
      onStreamFinished: {
        root.isTranslating = false;
        root.handleTranslationResponse(text);
      }
    }

    stderr: StdioCollector {}

    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        root.isTranslating = false;
        root.translationError = pluginApi?.tr("errors.translationFailed");
      }
    }
  }

  function translateGoogle(text, targetLang, sourceLang) {
    var commandData = ProviderLogic.buildGoogleTranslateCommand(text, targetLang, sourceLang);
    translateProcess.command = commandData.args;
    translateProcess.running = true;
  }

  function translateDeepL(text, targetLang) {
    var commandData = ProviderLogic.buildDeepLTranslateCommand(text, targetLang, deeplApiKey);

    if (commandData.error) {
      root.isTranslating = false;
      root.translationError = pluginApi?.tr("errors.noDeeplKey");
      return;
    }

    translateProcess.command = commandData.args;
    translateProcess.running = true;
  }

  function handleTranslationResponse(responseText) {
    var result = ProviderLogic.parseTranslateResponse(translatorBackend, responseText);

    if (result.error) {
      if (result.error === "Empty response")
        root.translationError = pluginApi?.tr("errors.emptyResponse");
      else if (result.error === "Failed to parse response")
        root.translationError = pluginApi?.tr("errors.parseError");
      else
        root.translationError = result.error;
    } else if (result.text) {
      root.translatedText = result.text;
    }
  }

  // =====================
  // IPC Handlers
  // =====================
  IpcHandler {
    target: "plugin:assistant-panel"

    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(function (screen) {
          pluginApi.togglePanel(screen);
        });
      }
    }

    function open() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(function (screen) {
          pluginApi.openPanel(screen);
        });
      }
    }

    function close() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(function (screen) {
          pluginApi.closePanel(screen);
        });
      }
    }

    function send(message: string) {
      if (message && message.trim() !== "") {
        root.sendMessage(message);
        ToastService.showNotice(pluginApi?.tr("toast.messageSent"));
      }
    }

    function clear() {
      root.clearMessages();
      ToastService.showNotice(pluginApi?.tr("toast.historyCleared"));
    }

    function translateText(text: string, targetLang: string) {
      if (text && text.trim() !== "") {
        root.translate(text, targetLang || root.targetLanguage);
      }
    }

    function setProvider(providerName: string) {
      if (pluginApi && root.providers[providerName]) {
        pluginApi.pluginSettings.ai.provider = providerName;
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi?.tr("toast.providerChanged") + " " + root.providers[providerName].name);
      }
    }

    function setModel(modelName: string) {
      if (pluginApi && modelName) {
        if (!pluginApi.pluginSettings.ai)
          pluginApi.pluginSettings.ai = {};
        pluginApi.pluginSettings.ai.model = modelName;
        try {
          var existing = pluginApi.pluginSettings.ai.models || {};
          existing[pluginApi.pluginSettings.ai.provider || provider] = modelName;
          pluginApi.pluginSettings.ai.models = existing;
        } catch (e) {
          pluginApi.pluginSettings.ai.models = {};
        }
        pluginApi.saveSettings();
        ToastService.showNotice(pluginApi?.tr("toast.modelChanged") + " " + modelName);
      }
    }

    function reloadTools() {
      root.discoverTools();
      ToastService.showNotice("Tools reloaded (" + root.toolCount + " found)");
    }
  }
}
