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

  // Translation state
  property string translatedText: ""
  property bool isTranslating: false
  property string translationError: ""

  // Cache directory for state (messages, activeTab) - use global noctalia cache
  readonly property string cacheDir: typeof Settings !== 'undefined' && Settings.cacheDir ? Settings.cacheDir + "plugins/assistant-panel/" : ""
  readonly property string stateCachePath: cacheDir + "state.json"
  property string activeTab: "ai"  // UI state - persisted to cache

  // Provider configurations
  readonly property var providers: ({
      [Constants.Providers.GOOGLE]: {
        "name": "Google Gemini",
        "defaultModel": "gemini-2.5-flash",
        "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?key={apiKey}",
        "streamEndpoint": "https://generativelanguage.googleapis.com/v1beta/models/{model}:streamGenerateContent?alt=sse&key={apiKey}"
      },
      [Constants.Providers.OPENAI]: {
        "name": "OpenAI",
        "defaultModel": "gpt-4o-mini",
        "endpoint": "https://api.openai.com/v1/chat/completions"
      },
      [Constants.Providers.OPENROUTER]: {
        "name": "OpenRouter",
        "defaultModel": "anthropic/claude-3.5-sonnet",
        "endpoint": "https://openrouter.ai/api/v1/chat/completions"
      },
      [Constants.Providers.OLLAMA]: {
        "name": "Ollama (Local)",
        "defaultModel": "llama3.2",
        "endpoint": "http://localhost:11434/v1/chat/completions"
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
      [Constants.Providers.OPENAI]: Quickshell.env("NOCTALIA_AP_OPENAI_API_KEY") || "",
      [Constants.Providers.OPENROUTER]: Quickshell.env("NOCTALIA_AP_OPENROUTER_API_KEY") || ""
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

  Component.onCompleted: {
    Logger.i("AssistantPanel", "Plugin initialized");
    // State loading is handled by FileView onLoaded
    ensureCacheDir();
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
    try {
      var content = stateCacheFile.text();
      if (!content || content.trim() === "") {
        Logger.d("AssistantPanel", "Empty cache file, starting fresh");
        return;
      }

      var cached = JSON.parse(content);
      root.messages = cached.messages || [];
      root.activeTab = cached.activeTab || "ai";
      Logger.d("AssistantPanel", "Loaded " + root.messages.length + " messages from cache");
    } catch (e) {
      Logger.e("AssistantPanel", "Failed to parse state cache: " + e);
    }
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
      var toSave = root.messages.slice(-maxHistory);

      var stateData = {
        messages: toSave,
        activeTab: root.activeTab,
        timestamp: Math.floor(Date.now() / 1000)
      };

      stateCacheFile.setText(JSON.stringify(stateData, null, 2));
      Logger.d("AssistantPanel", "Saved " + toSave.length + " messages to cache");
    } catch (e) {
      Logger.e("AssistantPanel", "Failed to save state cache: " + e);
    }
  }

  // Add a message to the chat
  function addMessage(role, content) {
    var newMessage = {
      "id": Date.now().toString(),
      "role": role,
      "content": content,
      "timestamp": new Date().toISOString()
    };
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

  // Send a message to the AI
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
    if (provider !== Constants.Providers.OLLAMA && (!apiKey || apiKey.trim() === "")) {
      root.errorMessage = pluginApi?.tr("errors.noApiKey") || "Please configure your API key in settings";
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

    if (provider === Constants.Providers.GOOGLE) {
      Logger.i("AssistantPanel", "Calling sendGeminiRequest()");
      sendGeminiRequest();
    } else if (provider === Constants.Providers.OPENAI || provider === Constants.Providers.OPENROUTER || provider === Constants.Providers.OLLAMA) {
      Logger.i("AssistantPanel", "Calling sendOpenAIRequest() for " + provider);
      sendOpenAIRequest();
    } else {
      Logger.e("AssistantPanel", "Unknown provider: " + provider);
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

      if (provider === Constants.Providers.GOOGLE) {
        sendGeminiRequest();
      } else if (provider === Constants.Providers.OPENAI || provider === Constants.Providers.OPENROUTER || provider === Constants.Providers.OLLAMA) {
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

    root.isGenerating = false;
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
      history.push({
        "role": msg.role,
        "content": msg.content
      });
    }
    return history;
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
      if (!data)
        return;
      var line = data.trim();
      if (line === "")
        return;

      // -----------------------------
      // Standard SSE Stream
      // -----------------------------
      if (line.startsWith("data: ")) {
        var jsonStr = line.substring(6).trim();
        if (jsonStr === "[DONE]")
          return;
        try {
          var json = JSON.parse(jsonStr);
          if (json.candidates && json.candidates[0] && json.candidates[0].content) {
            var parts = json.candidates[0].content.parts;
            if (parts && parts[0] && parts[0].text) {
              root.currentResponse += parts[0].text;
            }
          }
        } catch (e) {
          Logger.e("AssistantPanel", "Error parsing SSE: " + e);
        }
        return;
      }

      // -----------------------------
      // Non-SSE JSON (Immediate Error)
      // -----------------------------
      // If we get a raw JSON object, it's likely an error.
      try {
        geminiProcess.buffer += line;
        var errorJson = JSON.parse(geminiProcess.buffer);

        if (errorJson.error) {
          root.errorMessage = errorJson.error.message || "API error";
        }
        geminiProcess.buffer = "";
      } catch (e) {
        // Incomplete JSON, wait for more data
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }

      root.isGenerating = false;
      geminiProcess.buffer = "";

      if (exitCode !== 0 && root.currentResponse === "") {
        if (root.errorMessage === "") {
          root.errorMessage = pluginApi?.tr("errors.requestFailed") || "Request failed";
        }
        return;
      }

      if (root.currentResponse.trim() !== "") {
        root.addMessage("assistant", root.currentResponse.trim());
      }
    }
  }

  function sendGeminiRequest() {
    var endpoint = providers[Constants.Providers.GOOGLE].streamEndpoint.replace("{model}", model).replace("{apiKey}", apiKey);
    var history = buildConversationHistory();
    var payload = ProviderLogic.buildGeminiPayload(systemPrompt, history, temperature);

    Logger.i("AssistantPanel", "sendGeminiRequest: endpoint=" + endpoint);
    Logger.i("AssistantPanel", "sendGeminiRequest: payload=" + JSON.stringify(payload));
    geminiProcess.buffer = "";
    geminiProcess.command = ["curl", "-s", "--no-buffer", "-X", "POST", "-H", "Content-Type: application/json", "-d", JSON.stringify(payload), endpoint];
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
      if (!data)
        return;
      var line = data.trim();
      if (line === "")
        return;

      // Standard SSE Stream
      if (line.startsWith("data: ")) {
        var jsonStr = line.substring(6).trim();
        if (jsonStr === "[DONE]")
          return;
        try {
          var json = JSON.parse(jsonStr);
          if (json.choices && json.choices[0]) {
            if (json.choices[0].delta && json.choices[0].delta.content) {
              root.currentResponse += json.choices[0].delta.content;
            } else if (json.choices[0].message && json.choices[0].message.content) {
              root.currentResponse = json.choices[0].message.content;
            }
          }
        } catch (e) {
          Logger.e("AssistantPanel", "Error parsing SSE JSON: " + e);
        }
        return;
      }

      // Buffer accumulation for non-SSE data (likely multiline error JSON)
      openaiProcess.buffer += line;
      try {
        var errorJson = JSON.parse(openaiProcess.buffer);
        if (errorJson.error) {
          root.errorMessage = errorJson.error.message || "API error";
        }
        // If parsed successfully (whether error or not), clear buffer to avoid stale data
        openaiProcess.buffer = "";
      } catch (e) {
        // Incomplete JSON, keep buffering
      }
    }

    onExited: function (exitCode, exitStatus) {
      if (root.isManuallyStopped) {
        root.isManuallyStopped = false;
        return;
      }

      root.isGenerating = false;

      if (exitCode !== 0 && root.currentResponse === "") {
        if (root.errorMessage === "") {
          if (provider === Constants.Providers.OLLAMA) {
            root.errorMessage = pluginApi?.tr("errors.ollamaNotRunning") || "Ollama is not running. Please start it with 'ollama serve'";
          } else {
            root.errorMessage = pluginApi?.tr("errors.requestFailed") || "Request failed";
          }
        }
        return;
      }

      if (root.currentResponse.trim() !== "") {
        root.addMessage("assistant", root.currentResponse.trim());
      }

      openaiProcess.buffer = "";
    }
  }

  function sendOpenAIRequest() {
    var history = buildConversationHistory();
    var payload = ProviderLogic.buildOpenAIPayload(model, systemPrompt, history, temperature);

    var endpoint = providers[provider] && providers[provider].endpoint ? providers[provider].endpoint : providers[Constants.Providers.OPENAI].endpoint;
    Logger.i("AssistantPanel", "sendOpenAIRequest: endpoint=" + endpoint);
    Logger.i("AssistantPanel", "sendOpenAIRequest: payload=" + JSON.stringify(payload));
    openaiProcess.buffer = "";

    var cmd = ["curl", "-s", "-S", "--no-buffer", "-X", "POST", "-H", "Content-Type: application/json"];

    if (apiKey && apiKey.trim() !== "") {
      cmd.push("-H", "Authorization: Bearer " + apiKey);
    }

    cmd.push("-d", JSON.stringify(payload));
    cmd.push(endpoint);

    openaiProcess.command = cmd;
    Logger.i("AssistantPanel", "sendOpenAIRequest: starting process");
    openaiProcess.running = true;
  }

  // =====================
  // Ollama API (Local)
  // =====================
  // Ollama Process removed (consolidated into OpenAI logic)

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
        root.translationError = pluginApi?.tr("errors.translationFailed") || "Translation failed";
      }
    }
  }

  function translateGoogle(text, targetLang, sourceLang) {
    var url = "https://translate.google.com/translate_a/single?client=gtx" + "&sl=" + encodeURIComponent(sourceLang || "auto") + "&tl=" + encodeURIComponent(targetLang) + "&dt=t&q=" + encodeURIComponent(text);

    translateProcess.command = ["curl", "-s", url];
    translateProcess.running = true;
  }

  function translateDeepL(text, targetLang) {
    if (!deeplApiKey || deeplApiKey.trim() === "") {
      root.isTranslating = false;
      root.translationError = pluginApi?.tr("errors.noDeeplKey") || "Please configure your DeepL API key";
      return;
    }

    var host = deeplApiKey.endsWith(":fx") ? "api-free.deepl.com" : "api.deepl.com";
    var url = "https://" + host + "/v2/translate";

    translateProcess.command = ["curl", "-s", "-X", "POST", url, "-H", "Authorization: DeepL-Auth-Key " + deeplApiKey, "-H", "Content-Type: application/x-www-form-urlencoded", "-d", "text=" + encodeURIComponent(text) + "&target_lang=" + targetLang.toUpperCase()];
    translateProcess.running = true;
  }

  function handleTranslationResponse(responseText) {
    if (!responseText || responseText.trim() === "") {
      root.translationError = pluginApi?.tr("errors.emptyResponse") || "Empty response";
      return;
    }

    try {
      if (translatorBackend === "google") {
        var response = JSON.parse(responseText);
        var result = "";
        if (response && response[0]) {
          for (var i = 0; i < response[0].length; i++) {
            if (response[0][i] && response[0][i][0]) {
              result += response[0][i][0];
            }
          }
        }
        root.translatedText = result;
      } else if (translatorBackend === "deepl") {
        var deeplResponse = JSON.parse(responseText);
        if (deeplResponse.translations && deeplResponse.translations[0]) {
          root.translatedText = deeplResponse.translations[0].text;
        } else if (deeplResponse.message) {
          root.translationError = deeplResponse.message;
        }
      }
    } catch (e) {
      root.translationError = pluginApi?.tr("errors.parseError") || "Failed to parse response";
      Logger.e("AssistantPanel", "Translation parse error: " + e);
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
        ToastService.showNotice(pluginApi?.tr("toast.messageSent") || "Message sent");
      }
    }

    function clear() {
      root.clearMessages();
      ToastService.showNotice(pluginApi?.tr("toast.historyCleared") || "Chat history cleared");
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
        ToastService.showNotice((pluginApi?.tr("toast.providerChanged") || "Provider changed to") + " " + root.providers[providerName].name);
      }
    }

    function setModel(modelName: string) {
      if (pluginApi && modelName) {
        // Save both legacy `model` and per-provider `models[provider]` for compatibility
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
        ToastService.showNotice((pluginApi?.tr("toast.modelChanged") || "Model changed to") + " " + modelName);
      }
    }
  }
}
