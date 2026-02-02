.pragma library

function buildGeminiPayload(systemPrompt, history, temperature) {
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

    // Add conversation history
    for (var i = 0; i < history.length; i++) {
        contents.push({
            "role": history[i].role === "assistant" ? "model" : "user",
            "parts": [{ "text": history[i].content }]
        });
    }

    return {
        "contents": contents,
        "generationConfig": {
            "temperature": temperature
        }
    };
}

function buildOpenAIPayload(model, systemPrompt, history, temperature) {
    var messages = [];

    if (systemPrompt && systemPrompt.trim() !== "") {
        messages.push({
            "role": "system",
            "content": systemPrompt
        });
    }

    // Add conversation history
    for (var i = 0; i < history.length; i++) {
        messages.push(history[i]);
    }

    return {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "stream": true
    };
}
