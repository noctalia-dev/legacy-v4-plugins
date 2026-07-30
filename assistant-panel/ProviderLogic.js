.pragma library

// ===================================
// AI Provider Logic
// ===================================

// ===================================
// Tool Support Helpers
// ===================================

function shellQuote(s) {
  return "'" + s.replace(/'/g, "'\\''") + "'";
}

function buildOpenAIToolsPayload(toolSchemas) {
  if (!toolSchemas || toolSchemas.length === 0) return null;
  return toolSchemas.map(function(schema) {
    return {
      type: "function",
      "function": {
        name: schema.name,
        description: schema.description,
        parameters: schema.parameters
      }
    };
  });
}

function buildGeminiToolsPayload(toolSchemas) {
  if (!toolSchemas || toolSchemas.length === 0) return null;
  return [{
    functionDeclarations: toolSchemas.map(function(schema) {
      return {
        name: schema.name,
        description: schema.description,
        parameters: schema.parameters
      };
    })
  }];
}

// Build the shell command to execute a tool
function buildToolExecCommand(toolDir, argsJson, timeout) {
  var runPath = toolDir + "/run";
  var timeoutSec = timeout || 30;
  return ["sh", "-c",
    "printf '%s' " + shellQuote(argsJson) +
    " | timeout " + timeoutSec + " " + shellQuote(runPath)
  ];
}

// ===================================
// Gemini API
// ===================================

function buildGeminiCommand(endpointUrl, model, apiKey, systemPrompt, history, temperature, toolSchemas) {
  var contents = [];

  // Add system prompt as first user message if provided
  if (systemPrompt && systemPrompt.trim() !== "") {
    contents.push({
      "role": "user",
      "parts": [{ "text": "System instruction: " + systemPrompt }]
    });
    contents.push({
      "role": "model",
      "parts": [{ "text": "Understood. I will follow these instructions." }]
    });
  }

  // Add conversation history with tool call support
  for (var i = 0; i < history.length; i++) {
    var msg = history[i];

    if (msg.role === "assistant" && msg.tool_calls && msg.tool_calls.length > 0) {
      // Assistant message with function calls
      var parts = [];
      if (msg.content) parts.push({ "text": msg.content });
      for (var j = 0; j < msg.tool_calls.length; j++) {
        var tc = msg.tool_calls[j];
        var tcArgs = typeof tc.arguments === "string" ? JSON.parse(tc.arguments) : (tc.arguments || {});
        parts.push({ "functionCall": { "name": tc.name, "args": tcArgs } });
      }
      contents.push({ "role": "model", "parts": parts });
    } else if (msg.role === "tool") {
      // Tool result — Gemini uses "function" role; group consecutive tool results
      var responsePart = {
        "functionResponse": {
          "name": msg.tool_name,
          "response": { "content": msg.content || "" }
        }
      };
      var lastContent = contents.length > 0 ? contents[contents.length - 1] : null;
      if (lastContent && lastContent.role === "function") {
        lastContent.parts.push(responsePart);
      } else {
        contents.push({ "role": "function", "parts": [responsePart] });
      }
    } else {
      contents.push({
        "role": msg.role === "assistant" ? "model" : "user",
        "parts": [{ "text": msg.content }]
      });
    }
  }

  var payload = {
    "contents": contents,
    "generationConfig": { "temperature": temperature }
  };

  // Add tools if available
  var tools = buildGeminiToolsPayload(toolSchemas);
  if (tools) {
    payload.tools = tools;
  }

  var finalUrl = endpointUrl.replace("{model}", model).replace("{apiKey}", apiKey);

  return {
    "url": finalUrl,
    "payload": JSON.stringify(payload),
    "args": ["curl", "-s", "--no-buffer", "-X", "POST",
             "-H", "Content-Type: application/json",
             "-d", JSON.stringify(payload), finalUrl]
  };
}

function parseGeminiStream(data) {
  if (!data) return null;
  var line = data.trim();
  if (line === "") return null;

  // Standard SSE Stream
  if (line.startsWith("data: ")) {
    var jsonStr = line.substring(6).trim();
    if (jsonStr === "[DONE]") return { done: true };

    try {
      var json = JSON.parse(jsonStr);
      if (json.candidates && json.candidates[0] && json.candidates[0].content) {
        var parts = json.candidates[0].content.parts;
        if (parts) {
          var functionCalls = [];
          var textContent = "";
          for (var i = 0; i < parts.length; i++) {
            if (parts[i].functionCall) {
              functionCalls.push(parts[i].functionCall);
            } else if (parts[i].text) {
              textContent += parts[i].text;
            }
          }
          if (functionCalls.length > 0) {
            var result = { function_calls: functionCalls };
            if (textContent) result.content = textContent;
            return result;
          }
          if (textContent) {
            return { content: textContent };
          }
        }
      }
    } catch (e) {
      return { error: "Error parsing SSE: " + e };
    }
  } else {
    // Possible raw JSON error
    if (line.startsWith("{") && line.endsWith("}")) {
      try {
        var json = JSON.parse(line);
        if (json.error) {
          return { error: json.error.message || "API error" };
        }
      } catch (e) {}
    }
    return { raw: line };
  }
  return null;
}

// ===================================
// OpenAI Compatible API
// ===================================

function buildOpenAICommand(endpointUrl, apiKey, model, systemPrompt, history, temperature, toolSchemas) {
  var messages = [];

  if (systemPrompt && systemPrompt.trim() !== "") {
    messages.push({ "role": "system", "content": systemPrompt });
  }

  // Add conversation history with tool call support
  for (var i = 0; i < history.length; i++) {
    var msg = history[i];

    if (msg.role === "assistant" && msg.tool_calls && msg.tool_calls.length > 0) {
      var tcArr = msg.tool_calls.map(function(tc) {
        return {
          id: tc.id,
          type: "function",
          "function": {
            name: tc.name,
            arguments: typeof tc.arguments === "string" ? tc.arguments : JSON.stringify(tc.arguments || {})
          }
        };
      });
      messages.push({
        "role": "assistant",
        "content": msg.content || null,
        "tool_calls": tcArr
      });
    } else if (msg.role === "tool") {
      messages.push({
        "role": "tool",
        "tool_call_id": msg.tool_call_id,
        "content": msg.content || ""
      });
    } else {
      messages.push({ "role": msg.role, "content": msg.content });
    }
  }

  var payload = {
    "model": model,
    "messages": messages,
    "temperature": temperature,
    "stream": true
  };

  // Add tools if available
  var tools = buildOpenAIToolsPayload(toolSchemas);
  if (tools) {
    payload.tools = tools;
    payload.tool_choice = "auto";
  }

  var args = ["curl", "-s", "-S", "--no-buffer", "-X", "POST",
              "-H", "Content-Type: application/json"];
  if (apiKey && apiKey.trim() !== "") {
    args.push("-H", "Authorization: Bearer " + apiKey);
  }
  args.push("-d", JSON.stringify(payload));
  args.push(endpointUrl);

  return {
    "url": endpointUrl,
    "payload": JSON.stringify(payload),
    "args": args
  };
}

function parseOpenAIStream(data) {
  if (!data) return null;
  var line = data.trim();
  if (line === "") return null;

  if (line.startsWith("data: ")) {
    var jsonStr = line.substring(6).trim();
    if (jsonStr === "[DONE]") return { done: true };

    try {
      var json = JSON.parse(jsonStr);
      if (json.choices && json.choices[0]) {
        var choice = json.choices[0];

        // Check for tool calls in delta
        if (choice.delta && choice.delta.tool_calls) {
          var tcs = choice.delta.tool_calls;
          var chunks = [];
          for (var i = 0; i < tcs.length; i++) {
            var tc = tcs[i];
            chunks.push({
              index: tc.index,
              id: tc.id || null,
              name: (tc["function"] && tc["function"].name) || null,
              arguments: (tc["function"] && tc["function"].arguments) || ""
            });
          }
          var result = { tool_call_chunks: chunks };
          if (choice.delta.content) result.content = choice.delta.content;
          // Include finish_reason if present on same chunk
          if (choice.finish_reason === "tool_calls") result.finish_reason = "tool_calls";
          return result;
        }

        // Check finish reason (standalone chunk with empty delta)
        if (choice.finish_reason === "tool_calls") {
          return { finish_reason: "tool_calls" };
        }

        // Regular content
        if (choice.delta && choice.delta.content) {
          return { content: choice.delta.content };
        } else if (choice.message && choice.message.content) {
          return { content: choice.message.content };
        }
      }
    } catch (e) {
      return { error: "Error parsing SSE JSON: " + e };
    }
  } else {
    return { raw: line };
  }
  return null;
}

// ===================================
// Translation Logic
// ===================================

function buildGoogleTranslateCommand(text, targetLang, sourceLang) {
  var url = "https://translate.google.com/translate_a/single?client=gtx"
    + "&sl=" + encodeURIComponent(sourceLang || "auto")
    + "&tl=" + encodeURIComponent(targetLang)
    + "&dt=t&q=" + encodeURIComponent(text);

  return { "args": ["curl", "-s", url] };
}

function buildDeepLTranslateCommand(text, targetLang, apiKey) {
  if (!apiKey || apiKey.trim() === "") {
    return { error: "Please configure your DeepL API key" };
  }

  var host = apiKey.endsWith(":fx") ? "api-free.deepl.com" : "api.deepl.com";
  var url = "https://" + host + "/v2/translate";

  return {
    "args": ["curl", "-s", "-X", "POST", url,
             "-H", "Authorization: DeepL-Auth-Key " + apiKey,
             "-H", "Content-Type: application/x-www-form-urlencoded",
             "-d", "text=" + encodeURIComponent(text) + "&target_lang=" + targetLang.toUpperCase()]
  };
}

function parseTranslateResponse(backend, responseText) {
  if (!responseText || responseText.trim() === "") {
    return { error: "Empty response" };
  }

  try {
    if (backend === "google") {
      var response = JSON.parse(responseText);
      var result = "";
      if (response && response[0]) {
        for (var i = 0; i < response[0].length; i++) {
          if (response[0][i] && response[0][i][0]) {
            result += response[0][i][0];
          }
        }
      }
      return { text: result };
    } else if (backend === "deepl") {
      var deeplResponse = JSON.parse(responseText);
      if (deeplResponse.translations && deeplResponse.translations[0]) {
        return { text: deeplResponse.translations[0].text };
      } else if (deeplResponse.message) {
        return { error: deeplResponse.message };
      }
    }
  } catch (e) {
    return { error: "Failed to parse response" };
  }
  return { error: "Unknown backend or format" };
}

// ===================================
// State Management
// ===================================

function processLoadedState(content) {
  if (!content || content.trim() === "") {
    return null;
  }
  try {
    var cached = JSON.parse(content);
    return {
      messages: cached.messages || [],
      activeTab: cached.activeTab || "ai",
      chatInputText: cached.chatInputText || "",
      chatInputCursorPosition: cached.chatInputCursorPosition || 0
    };
  } catch (e) {
    return { error: e.toString() };
  }
}

function prepareStateForSave(messages, activeTab, maxHistory, chatInputText, chatInputCursorPosition) {
  var maxLog = maxHistory || 100;
  var toSave = messages.slice(-maxLog);

  return JSON.stringify({
    messages: toSave,
    activeTab: activeTab,
    chatInputText: chatInputText || "",
    chatInputCursorPosition: chatInputCursorPosition || 0,
    timestamp: Math.floor(Date.now() / 1000)
  }, null, 2);
}
