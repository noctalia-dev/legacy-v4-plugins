import QtQuick
import Quickshell
import Quickshell.Io
import "AdvancedMath.js" as AdvancedMath
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var settings: pluginApi?.pluginSettings ?? ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

    readonly property bool showBarValue: settings.showBarValue ?? defaults.showBarValue ?? true
    readonly property int precision: Math.max(0, Math.min(settings.precision ?? defaults.precision ?? 8, 10))

    // Max digits before JS double precision loses accuracy
    readonly property int _maxInputLength: 18

    property var tokens: []
    property string currentInput: "0"
    property bool shouldResetInput: false
    property bool justEvaluated: false
    property bool errorState: false
    property string lastExpression: ""

    readonly property bool hasExpression: tokens.length > 0 || currentInput !== "0" || justEvaluated
    readonly property string displayText: errorState ? pluginApi?.tr("state.error") : currentInput
    readonly property string expressionText: expressionPreview()
    readonly property string badgeText: !showBarValue ? "" : compactDisplay(displayText, 9)
    readonly property bool hasCopyableResult: !errorState && displayText !== "" && (justEvaluated || displayText !== "0" || tokens.length > 0)

    function _isOperator(token) {
        return token === "+" || token === "-" || token === "*" || token === "/";
    }

    function _normalizeOperator(op) {
        if (op === "x" || op === "X") return "*";
        if (_isOperator(op)) return op;
        return "";
    }

    function _sanitizeCurrentInput() {
        if (currentInput === "" || currentInput === "-") return "0";
        if (currentInput.endsWith(".")) return currentInput + "0";
        return currentInput;
    }

    function _numberToString(value) {
        if (!Number.isFinite(value)) return null;

        let rounded = value;
        if (precision >= 0) {
            rounded = Number(value.toFixed(precision));
        }
        if (Object.is(rounded, -0)) rounded = 0;

        let text = rounded.toString();
        if (text.indexOf("e") >= 0 || text.indexOf("E") >= 0) {
            return text.replace("e+", "e");
        }

        if (text.length > 16 && rounded !== 0) {
            text = rounded.toExponential(Math.max(0, Math.min(precision, 6))).replace("e+", "e");
        }
        return text;
    }

    function compactDisplay(text, maxLength) {
        if (!text) return "";
        if (text.length <= maxLength) return text;
        const numeric = Number(text);
        if (!Number.isNaN(numeric) && Number.isFinite(numeric)) {
            const exp = numeric.toExponential(Math.max(0, Math.min(precision, 3))).replace("e+", "e");
            if (exp.length <= maxLength) return exp;
        }
        return text.slice(0, Math.max(1, maxLength - 1)) + "~";
    }

    function clearAll() {
        tokens = [];
        currentInput = "0";
        shouldResetInput = false;
        justEvaluated = false;
        errorState = false;
        lastExpression = "";
    }

    function _setError() {
        tokens = [];
        currentInput = "0";
        shouldResetInput = false;
        justEvaluated = false;
        errorState = true;
        lastExpression = "";
    }

    function appendDigit(digit) {
        if (errorState) clearAll();

        if (justEvaluated && tokens.length === 0 && !shouldResetInput) {
            clearAll();
        }

        if (shouldResetInput) {
            currentInput = digit;
            shouldResetInput = false;
            justEvaluated = false;
            errorState = false;
            return;
        }

        if (currentInput === "0") {
            currentInput = digit;
        } else if (currentInput === "-0") {
            currentInput = "-" + digit;
        } else if (currentInput.length < _maxInputLength) {
            currentInput += digit;
        }

        justEvaluated = false;
        errorState = false;
    }

    function appendDecimal() {
        if (errorState) clearAll();

        if (justEvaluated && tokens.length === 0 && !shouldResetInput) {
            clearAll();
        }

        if (shouldResetInput) {
            currentInput = "0.";
            shouldResetInput = false;
            justEvaluated = false;
            return;
        }

        if (currentInput.indexOf(".") === -1) {
            currentInput += ".";
        }
        justEvaluated = false;
    }

    function deleteLastChar() {
        if (errorState) {
            clearAll();
            return;
        }
        if (justEvaluated) {
            clearAll();
            return;
        }
        if (shouldResetInput) {
            currentInput = "0";
            shouldResetInput = false;
            return;
        }

        if (currentInput.length <= 1 || (currentInput.length === 2 && currentInput.startsWith("-"))) {
            currentInput = "0";
            return;
        }

        currentInput = currentInput.slice(0, currentInput.length - 1);
    }

    function toggleSign() {
        if (errorState) return;

        if (shouldResetInput) {
            currentInput = "0";
            shouldResetInput = false;
        }

        if (currentInput.startsWith("-")) {
            currentInput = currentInput.slice(1);
        } else {
            currentInput = "-" + currentInput;
        }

        if (currentInput === "-0") {
            justEvaluated = false;
            return;
        }

        justEvaluated = false;
    }

    function applyPercent() {
        if (errorState) return;

        const numeric = Number(_sanitizeCurrentInput());
        if (Number.isNaN(numeric)) {
            _setError();
            return;
        }

        const formatted = _numberToString(numeric / 100);
        if (formatted === null) {
            _setError();
            return;
        }

        currentInput = formatted;
        shouldResetInput = false;
        justEvaluated = false;
    }

    function applyOperator(op) {
        if (errorState) return;

        const operator = _normalizeOperator(op);
        if (!operator) return;

        if (justEvaluated && tokens.length === 0) {
            tokens = [currentInput, operator];
            shouldResetInput = true;
            justEvaluated = false;
            lastExpression = "";
            return;
        }

        if (shouldResetInput) {
            if (tokens.length > 0 && _isOperator(tokens[tokens.length - 1])) {
                const updated = tokens.slice(0, tokens.length - 1);
                updated.push(operator);
                tokens = updated;
            } else {
                tokens = tokens.concat([operator]);
            }
            lastExpression = "";
            return;
        }

        tokens = tokens.concat([_sanitizeCurrentInput(), operator]);
        shouldResetInput = true;
        justEvaluated = false;
        lastExpression = "";
    }

    function _buildEvaluationTokens() {
        const built = Array.from(tokens);
        if (!shouldResetInput || built.length === 0 || !_isOperator(built[built.length - 1])) {
            built.push(_sanitizeCurrentInput());
        }
        while (built.length > 0 && _isOperator(built[built.length - 1])) {
            built.pop();
        }
        return built;
    }

    function _buildDisplayTokens() {
        const built = Array.from(tokens);
        if (!shouldResetInput || built.length === 0 || !_isOperator(built[built.length - 1])) {
            built.push(_sanitizeCurrentInput());
        }
        return built;
    }

    function _evaluateExpression(expressionStr) {
        try {
            return AdvancedMath.evaluate(expressionStr);
        } catch (e) {
            return null;
        }
    }

    function _formatExpression(tokensToFormat) {
        const parts = [];
        for (let i = 0; i < tokensToFormat.length; i++) {
            const token = tokensToFormat[i];
            if (token === "*") parts.push("x");
            else parts.push(String(token));
        }
        return parts.join(" ");
    }

    function expressionPreview() {
        if (errorState) return lastExpression || "";
        if (justEvaluated && lastExpression) return lastExpression;

        const built = _buildDisplayTokens();
        if (built.length === 0 || (built.length === 1 && built[0] === "0" && !hasExpression)) {
            return "";
        }
        return _formatExpression(built);
    }

    function evaluate() {
        if (errorState) return;

        const evaluationTokens = _buildEvaluationTokens();
        if (evaluationTokens.length === 0) return;

        const expression = _formatExpression(evaluationTokens);
        const expressionStr = evaluationTokens.join(" ");
        const result = _evaluateExpression(expressionStr);
        if (result === null) {
            _setError();
            return;
        }

        const formatted = _numberToString(result);
        if (formatted === null) {
            _setError();
            return;
        }

        currentInput = formatted;
        tokens = [];
        shouldResetInput = false;
        justEvaluated = true;
        errorState = false;
        lastExpression = expression;
    }

    function pressButton(action) {
        if (action >= "0" && action <= "9") {
            appendDigit(action);
            return;
        }

        if (action === "decimal") appendDecimal();
        else if (action === "add") applyOperator("+");
        else if (action === "subtract") applyOperator("-");
        else if (action === "multiply") applyOperator("*");
        else if (action === "divide") applyOperator("/");
        else if (action === "equals") evaluate();
        else if (action === "percent") applyPercent();
        else if (action === "sign") toggleSign();
        else if (action === "clear") clearAll();
        else if (action === "delete") deleteLastChar();
    }

    readonly property var _operatorActionMap: ({
        "+": "add", "-": "subtract", "/": "divide",
        "*": "multiply", "x": "multiply", "X": "multiply"
    })

    function actionForKeyEvent(event) {
        if ((event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.MetaModifier)) {
            return "";
        }

        const text = event.text ?? "";
        if (text >= "0" && text <= "9") return text;
        if (text === "." || text === ",") return "decimal";
        if (text in _operatorActionMap) return _operatorActionMap[text];
        if (text === "%") return "percent";
        if (text === "=") return "equals";

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) return "equals";
        if (event.key === Qt.Key_Backspace) return "delete";
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Delete) return "clear";
        if (event.key === Qt.Key_F9) return "sign";

        return "";
    }

    function handleKeyEvent(event) {
        const action = actionForKeyEvent(event);
        if (action === "") return false;

        pressButton(action);
        return true;
    }

    function copyResult() {
        if (!hasCopyableResult) return;
        const value = displayText;
        const escaped = value.replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
        const shown = value.length > 24 ? value.slice(0, 24) + "…" : value;
        if (pluginApi) {
            ToastService.showNotice(pluginApi.tr("toast.copied", { "value": shown }));
        }
    }

    IpcHandler {
        target: "plugin:noctalia-calculator"
        function toggle() {
            if (pluginApi) {
                pluginApi.withCurrentScreen(screen => {
                    pluginApi.togglePanel(screen);
                });
            }
        }
    }
}
