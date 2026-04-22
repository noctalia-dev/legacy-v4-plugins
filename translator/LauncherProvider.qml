import QtQuick
import Quickshell
import qs.Commons
import "translatorUtils.js" as TranslatorUtils

Item {
    id: root

    property var pluginApi: null
    property var launcher: null
    property string name: "Translator"
    
    // Preview support
    property bool showPreview: pluginApi?.pluginSettings?.showPreview !== undefined ? pluginApi.pluginSettings.showPreview : true
    readonly property bool hasPreview: showPreview
    readonly property string previewComponentPath: Qt.resolvedUrl("TranslationPreview.qml")

    property var translationCache: ({})
    property var pendingTranslations: ({})

    function getDefaultLanguages() {
        var result = [];
        var translatePrefix = pluginApi?.tr("translatePrefix") || "Translate to ";
        for (var code in TranslatorUtils.languages) {
            var lang = TranslatorUtils.languages[code];
            var languageName = pluginApi?.tr("languageNames." + lang.name) || lang.name.charAt(0).toUpperCase() + lang.name.slice(1);
            var desc = translatePrefix + languageName;
            result.push({name: languageName, desc: desc, code: code});
        }
        return result;
    }

    function handleCommand(searchText) {
        return searchText.startsWith(">translate");
    }

    function commands() {
        return [{
            "name": ">translate",
            "description": pluginApi?.tr("command.description") || "Translate text",
            "icon": "language",
            "isTablerIcon": true,
            "onActivate": function() { launcher.setSearchText(">translate "); }
        }];
    }

    function getResults(searchText) {
        // Replace whitespace sequences with single spaces
        var normalizedSearchText = searchText.replace(/\s+/g, " ").trim();

        if (!normalizedSearchText.startsWith(">translate")) return [];
        var parts = normalizedSearchText.split(" ");
        if (parts.length <= 1) {
            return getDefaultLanguages().map(function(lang) {
                return {
                    "name": lang.name,
                    "description": lang.desc,
                    "icon": "language",
                    "isTablerIcon": true,
                    "onActivate": function() { launcher.setSearchText(">translate " + lang.code + " "); }
                };
            });
        }

        var targetLang = TranslatorUtils.getLanguageCode(parts[1] || "fr") || "fr";
        var textToTranslate = parts.slice(2).join(" ");

        if (!textToTranslate) {
            return [{
                "name": pluginApi?.tr("messages.enterText") || "Type text to translate...",
                "description": pluginApi?.tr("messages.targetLanguage", {code: targetLang}) || "Target language: " + targetLang,
                "icon": "language",
                "isTablerIcon": true
            }];
        }

        var backend = getBackend();
        var deeplxApiUrl = (pluginApi?.pluginSettings?.deeplxApiUrl || "").trim();
        var cacheKey = backend + "|" + deeplxApiUrl + "|" + targetLang + "|" + textToTranslate;
        var cached = translationCache[cacheKey];
        if (cached) {
            return [{
                "name": cached,
                "description": pluginApi?.tr("messages.translation", {code: targetLang}) || "Translation (" + targetLang + ")",
                "icon": "language",
                "isTablerIcon": true,
                "onActivate": function() {
                    copyToClipboard(cached);
                    launcher.close();
                }
            }];
        }

        if (!pendingTranslations[cacheKey]) {
            var realTime = pluginApi?.pluginSettings?.realTimeTranslation !== undefined ? pluginApi.pluginSettings.realTimeTranslation : true;

            if (realTime) {
                pendingTranslations[cacheKey] = true;
                translateText(textToTranslate, targetLang, cacheKey);
            } else {
                return [{
                    "name": pluginApi?.tr("messages.pressEnter") || "Press Enter to translate",
                    "description": textToTranslate,
                    "icon": "language",
                    "isTablerIcon": true,
                    "onActivate": function() {
                        pendingTranslations[cacheKey] = true;
                        if (launcher) {
                             if (typeof launcher.refreshResults === "function") launcher.refreshResults();
                             else if (typeof launcher.updateResults === "function") launcher.updateResults();
                             else if (typeof launcher.requestUpdate === "function") launcher.requestUpdate();
                        }
                        translateText(textToTranslate, targetLang, cacheKey);
                    }
                }];
            }
        }

        return [{
            "name": pluginApi?.tr("messages.translating") || "Translating...",
            "description": textToTranslate,
            "icon": "language",
            "isTablerIcon": true
        }];
    }

    function escapeForShell(text) {
        return text.replace(/'/g, "'\\''");
    }

    function copyToClipboard(text) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escapeForShell(text) + "' | wl-copy"]);
    }

    function getBackend() {
        return pluginApi?.pluginSettings?.backend || pluginApi?.manifest?.metadata?.defaultSettings?.backend || "google";
    }

    function getErrorMessage(status, fallback) {
        return fallback || pluginApi?.tr("messages.connectionError");
    }

    function translateText(text, targetLanguage, cacheKey) {
        var backend = getBackend();
        
        var callback = function(result, error) {
            delete pendingTranslations[cacheKey];
            if (error) {
                translationCache[cacheKey] = error;
            } else {
                translationCache[cacheKey] = result;
            }
            
            if (launcher) {
                if (typeof launcher.refreshResults === "function") launcher.refreshResults();
                else if (typeof launcher.updateResults === "function") launcher.updateResults();
                else if (typeof launcher.requestUpdate === "function") launcher.requestUpdate();
            }
        };

        if (backend === "google") {
            translateGoogle(text, targetLanguage, callback);
        } else if (backend === "deepl") {
            translateDeepL(text, targetLanguage, callback);
        } else if (backend === "deeplxLike") {
            translateDeepLXLike(text, targetLanguage, callback);
        } else {
            callback(null, pluginApi?.tr("messages.error"));
        }
    }

    function translateGoogle(text, targetLanguage, callback) {
        var url = "https://translate.google.com/translate_a/single?client=gtx&sl=auto&tl=" + targetLanguage + "&dt=t&q=" + encodeURIComponent(text);
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var translatedText = "";
                        if (response && response[0]) {
                            for (var i = 0; i < response[0].length; i++) {
                                if (response[0][i] && response[0][i][0]) {
                                    translatedText += response[0][i][0];
                                }
                            }
                        }
                        
                        if (translatedText) {
                            callback(translatedText, null);
                        } else {
                            callback(null, pluginApi?.tr("messages.error") || "Translation error");
                        } 
                    } catch (e) { callback(null, pluginApi?.tr("messages.error") || "Translation error"); }
                } else {
                    callback(null, getErrorMessage(xhr.status));
                }
            }
        };
        xhr.send();
    }

    function translateDeepL(text, targetLanguage, callback) {
        var apiKey = (pluginApi?.pluginSettings?.deeplApiKey || "").trim();
        if (!apiKey) {
            callback(null, pluginApi?.tr("messages.missingApiKey") || "Missing API Key");
            return;
        }
        var host = apiKey.endsWith(":fx") ? "api-free.deepl.com" : "api.deepl.com";
        var url = "https://" + host + "/v2/translate";
        var postData = "text=" + encodeURIComponent(text) + "&target_lang=" + targetLanguage.toUpperCase();
        
        var xhr = new XMLHttpRequest();
        xhr.open("POST", url);
        xhr.setRequestHeader("Authorization", "DeepL-Auth-Key " + apiKey);
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var translatedText = (response && response.translations && response.translations[0] && response.translations[0].text) || "";
                        if (translatedText) {
                            callback(translatedText, null);
                        }
                        else {
                            callback(null, pluginApi?.tr("messages.error") || "Translation error");
                        }
                    } catch (e) { 
                        callback(null, pluginApi?.tr("messages.error") || "Translation error"); 
                        }
                } else if (xhr.status === 403) {
                    callback(null, pluginApi?.tr("messages.invalidApiKey") || "Invalid API Key");
                } else {
                    callback(null, getErrorMessage(xhr.status));
                }
            }
        };
        xhr.send(postData);
    }

    function translateDeepLXLike(text, targetLanguage, callback) {
        var url = (pluginApi?.pluginSettings?.deeplxApiUrl || "").trim();
        var apiKey = (pluginApi?.pluginSettings?.deeplxApiKey || "").trim();

        if (!url) {
            callback(null, pluginApi?.tr("messages.missingApiUrl"));
            return;
        }

        var xhr = new XMLHttpRequest();
        xhr.open("POST", url);
        xhr.setRequestHeader("Content-Type", "application/json");
        if (apiKey) {
            xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText);
                        var translatedText =
                            response?.data ||
                            (response?.translations && response.translations[0] && response.translations[0].text) ||
                            "";

                        if (translatedText) {
                            callback(translatedText, null);
                        } else {
                            callback(null, pluginApi?.tr("messages.error"));
                        }
                    } catch (e) {
                        callback(null, pluginApi?.tr("messages.error"));
                    }
                } else {
                    callback(null, getErrorMessage(xhr.status));
                }
            }
        };

        xhr.send(JSON.stringify({
            text: text,
            target_lang: targetLanguage.toUpperCase()
        }));
    }
}
