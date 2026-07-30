function commandWords(canonicalPrefix, alias) {
  var words = [String(canonicalPrefix || "").trim().toLowerCase()];
  var normalizedAlias = String(alias || "").trim().toLowerCase();
  if (normalizedAlias !== "" && words.indexOf(normalizedAlias) === -1)
    words.push(normalizedAlias);
  return words;
}

function matchCommand(searchText, canonicalPrefix, alias) {
  var text = String(searchText || "");
  if (text[0] !== ">")
    return {"matched": false};

  var commandEnd = text.search(/\s/);
  if (commandEnd === -1)
    commandEnd = text.length;

  var enteredPrefix = text.slice(1, commandEnd).toLowerCase();
  var words = commandWords(canonicalPrefix, alias);
  if (words.indexOf(enteredPrefix) === -1)
    return {"matched": false};

  return {
    "matched": true,
    "prefix": enteredPrefix,
    "expression": text.slice(commandEnd).trim()
  };
}

function validateAlias(alias, canonicalPrefix) {
  var normalized = String(alias || "").trim().toLowerCase();
  if (normalized === "") {
    return {
      "state": "valid",
      "normalized": ""
    };
  }

  if (!/^[a-z0-9][a-z0-9-]*$/.test(normalized)) {
    return {
      "state": "invalid",
      "code": "alias-format"
    };
  }

  if (normalized === String(canonicalPrefix || "").trim().toLowerCase()) {
    return {
      "state": "invalid",
      "code": "alias-duplicates-canonical"
    };
  }

  return {
    "state": "valid",
    "normalized": normalized
  };
}

function sessionStatus(session) {
  if (!session || !session.active) {
    return {
      "kind": "status",
      "mode": "off"
    };
  }

  if (session.remainingSeconds === null
      || session.remainingSeconds === undefined) {
    return {
      "kind": "status",
      "mode": "indefinite"
    };
  }

  return {
    "kind": "status",
    "mode": "finite",
    "seconds": Math.max(0, Math.floor(session.remainingSeconds))
  };
}

function endAction() {
  return {
    "kind": "action",
    "action": "end-session"
  };
}

function appendEndAction(entries, session) {
  if (session && session.active)
    entries.push(endAction());
  return entries;
}

function finiteAction(parsed, session, source) {
  return {
    "kind": "action",
    "action": "start-finite",
    "seconds": parsed.seconds,
    "normalized": parsed.normalized,
    "replacing": Boolean(session && session.active),
    "source": source || "expression"
  };
}

function indefiniteAction(session, source) {
  return {
    "kind": "action",
    "action": "start-indefinite",
    "replacing": Boolean(session && session.active),
    "source": source || "expression"
  };
}

function presetActions(presets, includeIndefinite, session, parseDuration) {
  var entries = [];
  var sourcePresets = Array.isArray(presets) ? presets : [];

  for (var index = 0; index < sourcePresets.length; index++) {
    var parsed = parseDuration(sourcePresets[index]);
    if (parsed && parsed.state === "valid")
      entries.push(finiteAction(parsed, session, "preset"));
  }

  if (includeIndefinite)
    entries.push(indefiniteAction(session, "preset"));
  return entries;
}

function actionsFor(expression, session, presets, includeIndefinite,
                    parseDuration) {
  var text = String(expression || "").trim();
  var keyword = text.toLowerCase();

  if (text === "") {
    var blankEntries = [];
    if (session && session.active) {
      blankEntries.push(sessionStatus(session));
      blankEntries.push(endAction());
    }
    return blankEntries.concat(
      presetActions(presets, includeIndefinite, session, parseDuration)
    );
  }

  if (keyword === "status")
    return appendEndAction([sessionStatus(session)], session);

  if (keyword === "off" || keyword === "stop" || keyword === "cancel") {
    if (session && session.active)
      return [endAction()];
    return [sessionStatus(session)];
  }

  if (keyword === "on" || keyword === "forever"
      || keyword === "indefinite" || keyword === "∞") {
    return appendEndAction([indefiniteAction(session)], session);
  }

  var parsed = parseDuration(text);
  if (parsed.state === "valid") {
    return appendEndAction(
      [finiteAction(parsed, session, "expression")],
      session
    );
  }

  return appendEndAction([{
    "kind": parsed.state,
    "code": parsed.code
  }], session);
}
