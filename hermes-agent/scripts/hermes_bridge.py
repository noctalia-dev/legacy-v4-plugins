#!/usr/bin/env python3
"""Local bridge state model for the Noctalia Hermes plugin."""

from __future__ import annotations

import json
import os
import secrets
import shutil
import subprocess
import sys
import time
import uuid
import argparse
from copy import deepcopy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


FALSE_VALUES = {"false", "0", "no", "off", "disabled", "paused"}


def detect_hermes_home() -> str:
    """Find the Hermes home directory. Checks env, then common paths."""
    env_home = os.environ.get("HERMES_HOME")
    if env_home:
        p = Path(env_home).expanduser()
        if p.exists() and (p / "config.yaml").exists():
            return str(p)

    candidates = [
        Path.home() / ".hermes",
        Path.home() / ".config" / "hermes",
        Path.home() / ".local" / "share" / "hermes",
        Path("/etc/hermes"),
    ]
    for c in candidates:
        if c.exists() and (c / "config.yaml").exists():
            return str(c)

    for c in candidates:
        if c.exists():
            return str(c)

    return str(Path.home() / ".hermes")


def detect_hermes_command() -> str:
    """Find the hermes binary. Checks PATH, then common install locations."""
    found = shutil.which("hermes")
    if found:
        return found

    candidates = [
        Path.home() / ".local" / "bin" / "hermes",
        Path.home() / ".hermes" / "bin" / "hermes",
        Path("/usr/local/bin/hermes"),
        Path("/usr/bin/hermes"),
    ]
    for c in candidates:
        if c.exists() and os.access(c, os.X_OK):
            return str(c)

    return "hermes"


def detect_gateway(hermes_home: str | Path) -> dict[str, Any]:
    """Read gateway_state.json and return gateway status + PID."""
    path = Path(hermes_home).expanduser() / "gateway_state.json"
    if not path.exists():
        return {"status": "offline", "pid": "", "platforms": {}}
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {"status": "unknown", "pid": "", "platforms": {}}
    pid = str(data.get("pid") or "")
    state = str(data.get("gateway_state") or data.get("status") or "unknown")
    platforms = data.get("platforms") or {}
    if isinstance(platforms, dict):
        platforms = {
            str(k): str(v.get("state") or v.get("status") or "unknown")
            for k, v in platforms.items()
            if isinstance(v, dict)
        }
    else:
        platforms = {}
    return {"status": state, "pid": pid, "platforms": platforms}


def detect_model(hermes_home: str | Path) -> dict[str, str]:
    """Read config.yaml and return the default model + provider."""
    config = scan_config_summary(hermes_home)
    return config.get("model", {"name": "", "provider": ""})


def detect_all(hermes_home: str | Path | None = None, hermes_command: str | None = None) -> dict[str, Any]:
    """Run all detection checks and return a combined result."""
    home = hermes_home or detect_hermes_home()
    cmd = hermes_command or detect_hermes_command()
    gateway = detect_gateway(home)
    model = detect_model(home)
    home_path = Path(home).expanduser()
    return {
        "hermesHome": str(home_path),
        "hermesCommand": cmd,
        "hermesHomeExists": home_path.exists(),
        "configExists": (home_path / "config.yaml").exists(),
        "gateway": gateway,
        "model": model,
        "bridgeHost": "127.0.0.1",
        "bridgePort": 19777,
        "stateFile": "~/.cache/noctalia-hermes/state.json",
    }


def now_ts() -> float:
    return time.time()


def default_summary() -> dict[str, Any]:
    return {
        "model": {"name": "", "provider": ""},
        "models": [],
        "mcp": {"enabled": 0, "total": 0, "status": "unknown"},
        "cron": {"active": 0, "total": 0, "next_run": "", "jobs": []},
        "activity": {"tool_events": 0, "running_tools": 0, "last_tool": ""},
        "gateway": {"status": "unknown", "platforms": {}},
    }


def default_state() -> dict[str, Any]:
    return {
        "bridge": {"status": "offline", "error": ""},
        "hermes": {"status": "unknown", "gateway_pid": "", "model": "", "provider": ""},
        "session": {"id": "", "stored_id": "", "title": "", "running": False, "cwd": ""},
        "messages": [],
        "events": [],
        "approval": {"pending": False, "message": "", "tool_name": "", "request": {}},
        "usage": {"input": 0, "output": 0, "total": 0, "cost_usd": None},
        "summary": default_summary(),
        "updated_at": 0,
    }


def refresh_summary(state: dict[str, Any], hermes_home: Path | str | None = None) -> dict[str, Any]:
    next_state = deepcopy(state)
    summary = default_summary()
    home = Path(hermes_home or "~/.hermes").expanduser()

    config_summary = scan_config_summary(home)
    summary["model"].update(config_summary["model"])
    summary["mcp"].update(config_summary["mcp"])
    summary["cron"].update(scan_cron_summary(home))
    summary["models"] = scan_model_options(home)
    summary["gateway"].update(scan_gateway_summary(home))
    summary["activity"].update(activity_summary(next_state.get("events", [])))

    hermes = next_state.get("hermes") if isinstance(next_state.get("hermes"), dict) else {}
    if hermes.get("model"):
        summary["model"]["name"] = str(hermes["model"])
    if hermes.get("provider"):
        summary["model"]["provider"] = str(hermes["provider"])

    next_state["summary"] = summary
    return next_state


def scan_config_summary(hermes_home: Path | str) -> dict[str, Any]:
    path = Path(hermes_home).expanduser() / "config.yaml"
    model = {"name": "", "provider": ""}
    mcp = {"enabled": 0, "total": 0, "status": "unknown"}
    if not path.exists():
        return {"model": model, "mcp": mcp}

    parsed = load_yaml_like(path)
    model_section = parsed.get("model", {}) if isinstance(parsed.get("model"), dict) else {}
    if isinstance(model_section, dict):
        model["provider"] = str(model_section.get("provider") or "")
        model["name"] = str(
            model_section.get("default")
            or model_section.get("name")
            or model_section.get("model")
            or ""
        )

    mcp_section = (
        parsed.get("mcp")
        or parsed.get("mcps")
        or parsed.get("mcp_servers")
        or parsed.get("mcpServers")
    )
    if isinstance(mcp_section, dict):
        total = 0
        enabled = 0
        for value in mcp_section.values():
            total += 1
            if section_enabled(value):
                enabled += 1
        mcp["enabled"] = enabled
        mcp["total"] = total
        mcp["status"] = "enabled" if enabled else "disabled"

    return {"model": model, "mcp": mcp}


def scan_cron_summary(hermes_home: Path | str) -> dict[str, Any]:
    cron_dir = Path(hermes_home).expanduser() / "cron"
    summary = {"active": 0, "total": 0, "next_run": "", "jobs": []}
    if not cron_dir.exists():
        return summary

    jobs_path = cron_dir / "jobs.json"
    if jobs_path.exists():
        try:
            data = json.loads(jobs_path.read_text())
        except (OSError, json.JSONDecodeError):
            data = {}
        jobs = data.get("jobs") if isinstance(data, dict) else []
        if isinstance(jobs, list):
            next_runs: list[str] = []
            normalized_jobs: list[dict[str, Any]] = []
            for job in jobs:
                if not isinstance(job, dict):
                    continue
                summary["total"] += 1
                active = section_enabled(job)
                if active:
                    summary["active"] += 1
                next_run = str(job.get("next_run_at") or "")
                if next_run:
                    next_runs.append(next_run)
                normalized_jobs.append(normalize_cron_job(job, active))
            summary["next_run"] = sorted(next_runs)[0] if next_runs else ""
            summary["jobs"] = sorted(
                normalized_jobs,
                key=lambda item: (
                    0 if item.get("active") else 1,
                    str(item.get("next_run") or "9999"),
                    str(item.get("name") or ""),
                ),
            )[:4]
            return summary

    for path in cron_dir.iterdir():
        if path.name.startswith(".") or not path.is_file() or path.suffix.lower() not in {".json", ".yaml", ".yml"}:
            continue
        data = load_data_file(path)
        summary["total"] += 1
        if section_enabled(data):
            summary["active"] += 1
    return summary


def normalize_cron_job(job: dict[str, Any], active: bool) -> dict[str, Any]:
    schedule = job.get("schedule")
    schedule_display = ""
    if isinstance(schedule, dict):
        schedule_display = str(schedule.get("display") or schedule.get("expr") or "")
    return {
        "id": str(job.get("id") or ""),
        "name": str(job.get("name") or job.get("id") or "Unnamed job"),
        "active": active,
        "state": str(job.get("state") or ("scheduled" if active else "paused")),
        "schedule": str(job.get("schedule_display") or schedule_display),
        "next_run": str(job.get("next_run_at") or ""),
        "last_status": str(job.get("last_status") or ""),
    }


def scan_model_options(hermes_home: Path | str) -> list[dict[str, str]]:
    """Return available model options for the plugin settings picker.

    Merges all three sources Hermes uses:
    1. Provider config ``models:`` sections from config.yaml
    2. Provider models cache (Hermes model catalog)
    3. models.json (user favorites/history)
    """
    home = Path(hermes_home).expanduser()
    options: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()

    # 1. Models from configured provider definitions in config.yaml.
    config = load_yaml_like(home / "config.yaml")
    providers = config.get("providers", {}) if isinstance(config, dict) else {}
    if isinstance(providers, dict):
        for name, cfg in providers.items():
            if not isinstance(cfg, dict):
                continue
            models = cfg.get("models")
            if isinstance(models, dict):
                for model_name in models:
                    add_model_option(options, seen, str(name), str(model_name), str(model_name))

    # 2. Models from the Hermes model catalog cache.
    cache_path = home / "provider_models_cache.json"
    if cache_path.exists():
        try:
            cache_data = json.loads(cache_path.read_text())
        except (OSError, json.JSONDecodeError):
            cache_data = {}
        if isinstance(cache_data, dict):
            for provider, payload in cache_data.items():
                models = payload.get("models") if isinstance(payload, dict) else []
                if not isinstance(models, list):
                    continue
                for model in models:
                    add_model_option(options, seen, str(provider), str(model), str(model))

    # 3. models.json favorites.
    models_path = home / "models.json"
    if models_path.exists():
        try:
            models_data = json.loads(models_path.read_text())
        except (OSError, json.JSONDecodeError):
            models_data = []
        if isinstance(models_data, list):
            for entry in models_data:
                if not isinstance(entry, dict):
                    continue
                add_model_option(
                    options, seen,
                    str(entry.get("provider") or ""),
                    str(entry.get("model") or ""),
                    str(entry.get("name") or entry.get("model") or ""),
                )

    return options


def add_model_option(
    options: list[dict[str, str]],
    seen: set[tuple[str, str]],
    provider: str,
    model: str,
    name: str,
) -> None:
    if not model:
        return
    key = (provider, model)
    if key in seen:
        return
    seen.add(key)
    label = name or model
    if provider:
        label = f"{label} ({provider})"
    options.append({"provider": provider, "model": model, "name": label})


def scan_gateway_summary(hermes_home: Path | str) -> dict[str, Any]:
    path = Path(hermes_home).expanduser() / "gateway_state.json"
    summary = {"status": "unknown", "platforms": {}}
    if not path.exists():
        return summary
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return summary
    if not isinstance(data, dict):
        return summary
    summary["status"] = str(data.get("gateway_state") or data.get("status") or "unknown")
    platforms = data.get("platforms")
    if isinstance(platforms, dict):
        summary["platforms"] = {
            str(name): str(value.get("state") or value.get("status") or "unknown")
            for name, value in platforms.items()
            if isinstance(value, dict)
        }
    return summary


def activity_summary(events: Any) -> dict[str, Any]:
    if not isinstance(events, list):
        return {"tool_events": 0, "running_tools": 0, "last_tool": ""}

    tool_events = [event for event in events if isinstance(event, dict) and str(event.get("type", "")).startswith("tool.")]
    starts: dict[str, int] = {}
    completes: dict[str, int] = {}
    last_tool = ""
    for event in tool_events:
        name = str(event.get("name") or "")
        if name:
            last_tool = name
        if event.get("type") == "tool.start":
            starts[name] = starts.get(name, 0) + 1
        elif event.get("type") == "tool.complete":
            completes[name] = completes.get(name, 0) + 1

    running = 0
    for name, count in starts.items():
        running += max(0, count - completes.get(name, 0))
    return {"tool_events": len(tool_events), "running_tools": running, "last_tool": last_tool}


def load_data_file(path: Path) -> Any:
    if path.suffix.lower() == ".json":
        try:
            return json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            return {}
    return load_yaml_like(path)


def load_yaml_like(path: Path) -> dict[str, Any]:
    text = path.read_text()
    try:
        import yaml  # type: ignore
    except Exception:
        try:
            from ruamel.yaml import YAML  # type: ignore
        except Exception:
            return parse_simple_yaml(text)
        data = YAML(typ="safe").load(text) or {}
        return data if isinstance(data, dict) else {}
    data = yaml.safe_load(text) or {}
    return data if isinstance(data, dict) else {}


def parse_simple_yaml(text: str) -> dict[str, Any]:
    root: dict[str, Any] = {}
    stack: list[tuple[int, dict[str, Any]]] = [(-1, root)]
    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip() or ":" not in line:
            continue
        indent = len(line) - len(line.lstrip(" "))
        key, value = line.strip().split(":", 1)
        key = key.strip().strip("'\"")
        value = value.strip()
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1]
        if value == "":
            child: dict[str, Any] = {}
            parent[key] = child
            stack.append((indent, child))
        else:
            parent[key] = parse_scalar(value)
    return root


def parse_scalar(value: str) -> Any:
    cleaned = value.strip().strip("'\"")
    lowered = cleaned.lower()
    if lowered in {"true", "yes", "on"}:
        return True
    if lowered in FALSE_VALUES:
        return False
    return cleaned


def section_enabled(value: Any) -> bool:
    if isinstance(value, dict):
        if "enabled" in value:
            return bool(value["enabled"])
        if "disabled" in value:
            return not bool(value["disabled"])
        if "paused" in value:
            return not bool(value["paused"])
        if str(value.get("state") or "").lower() in FALSE_VALUES:
            return False
        if value.get("paused_at"):
            return False
        return True
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() not in FALSE_VALUES
    return value is not None


def health_payload(state: dict[str, Any]) -> dict[str, Any]:
    snapshot = deepcopy(state)
    snapshot["bridge"]["status"] = "online"
    return {"bridge": snapshot["bridge"]}


def atomic_write_json(path: Path | str, data: dict[str, Any]) -> None:
    target = Path(path).expanduser()
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(f"{target.name}.{uuid.uuid4().hex}.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    os.chmod(tmp, 0o600)
    tmp.replace(target)


def load_or_create_token(token_path: Path) -> str:
    """Load the bridge auth token, or generate one if none exists."""
    token_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        existing = token_path.read_text().strip()
        if existing:
            return existing
    except (FileNotFoundError, OSError):
        pass
    token = secrets.token_urlsafe(32)
    tmp = token_path.with_name(f"{token_path.name}.{uuid.uuid4().hex}.tmp")
    tmp.write_text(token + "\n")
    os.chmod(tmp, 0o600)
    tmp.replace(token_path)
    os.chmod(token_path, 0o600)
    return token


def preferred_hermes_python(
    hermes_home: Path | str,
    current_executable: str | Path | None = None,
) -> Path | None:
    venv_python = Path(hermes_home).expanduser() / "hermes-agent" / "venv" / "bin" / "python"
    if not venv_python.exists() or not os.access(venv_python, os.X_OK):
        return None

    current = Path(current_executable or sys.executable)
    try:
        if current.resolve() == venv_python.resolve():
            return None
    except OSError:
        if str(current) == str(venv_python):
            return None
    return venv_python


def reexec_with_hermes_python(args: argparse.Namespace, argv: list[str]) -> None:
    if os.environ.get("NOCTALIA_HERMES_BRIDGE_REEXEC") == "1":
        return
    python = preferred_hermes_python(args.hermes_home)
    if python is None:
        return
    env = os.environ.copy()
    env["NOCTALIA_HERMES_BRIDGE_REEXEC"] = "1"
    os.execve(str(python), [str(python), str(Path(__file__).resolve()), *argv], env)


class HermesState:
    def __init__(self, state_file: Path | str, hermes_home: Path | str | None = None):
        self.state_file = Path(state_file).expanduser()
        self.hermes_home = Path(hermes_home or "~/.hermes").expanduser()
        self._state = default_state()
        self._active_assistant_id: str | None = None

    def snapshot(self) -> dict[str, Any]:
        return refresh_summary(self._state, self.hermes_home)

    def write(self) -> None:
        self._state["updated_at"] = now_ts()
        atomic_write_json(self.state_file, self.snapshot())

    def apply_event(self, obj: dict[str, Any]) -> None:
        params = obj.get("params", {}) if isinstance(obj, dict) else {}
        event_type = params.get("type", "")
        payload = params.get("payload", {}) or {}
        if not isinstance(payload, dict):
            payload = {"text": str(payload)}

        if event_type == "message.start":
            self._start_message()
        elif event_type == "message.delta":
            self._append_message_delta(str(payload.get("text") or ""))
        elif event_type == "message.complete":
            self._complete_message()
        elif event_type in {"tool.start", "tool.complete"}:
            self._append_tool_event(event_type, payload)
        elif event_type == "approval.request":
            self._set_approval(payload)
        elif event_type == "session.info":
            self._apply_session_info(payload)
        elif event_type == "status.update":
            self._append_status_event(payload)
        elif event_type == "error":
            self._state["bridge"]["error"] = str(payload.get("message") or "")
            self._append_status_event({"kind": "error", "text": self._state["bridge"]["error"]})

        self._state["updated_at"] = now_ts()

    def _start_message(self) -> None:
        message = {
            "id": f"msg-{uuid.uuid4().hex}",
            "role": "assistant",
            "text": "",
            "streaming": True,
            "ts": now_ts(),
        }
        self._state["messages"].append(message)
        self._active_assistant_id = message["id"]
        self._state["session"]["running"] = True
        self._state["hermes"]["status"] = "busy"

    def _append_message_delta(self, text: str) -> None:
        if not self._active_assistant_id:
            self._start_message()
        message = self._find_message(self._active_assistant_id)
        if message is not None:
            message["text"] += text

    def _complete_message(self) -> None:
        message = self._find_message(self._active_assistant_id)
        if message is not None:
            message["streaming"] = False
        self._active_assistant_id = None
        self._state["session"]["running"] = False
        if not self._state["approval"]["pending"]:
            self._state["hermes"]["status"] = "idle"

    def _find_message(self, message_id: str | None) -> dict[str, Any] | None:
        if not message_id:
            return None
        for message in self._state["messages"]:
            if message.get("id") == message_id:
                return message
        return None

    def _append_tool_event(self, event_type: str, payload: dict[str, Any]) -> None:
        self._state["events"].append({
            "id": f"evt-{uuid.uuid4().hex}",
            "type": event_type,
            "name": str(payload.get("name") or payload.get("tool_name") or ""),
            "text": str(payload.get("text") or payload.get("message") or ""),
            "ts": now_ts(),
        })
        self._state["hermes"]["status"] = "busy"

    def _set_approval(self, payload: dict[str, Any]) -> None:
        self._state["approval"] = {
            "pending": True,
            "message": str(payload.get("message") or ""),
            "tool_name": str(payload.get("tool_name") or payload.get("name") or ""),
            "request": deepcopy(payload),
        }
        self._state["hermes"]["status"] = "attention"

    def _apply_session_info(self, payload: dict[str, Any]) -> None:
        info = payload.get("info", payload)
        if not isinstance(info, dict):
            return
        self._state["hermes"]["model"] = str(info.get("model") or self._state["hermes"]["model"])
        self._state["hermes"]["provider"] = str(info.get("provider") or self._state["hermes"]["provider"])
        self._state["session"]["cwd"] = str(info.get("cwd") or self._state["session"]["cwd"])

    def _append_status_event(self, payload: dict[str, Any]) -> None:
        text = str(payload.get("text") or payload.get("message") or "")
        if not text:
            return
        self._state["events"].append({
            "id": f"evt-{uuid.uuid4().hex}",
            "type": "status.update",
            "name": str(payload.get("kind") or "status"),
            "text": text,
            "ts": now_ts(),
        })

    def set_session_from_create(self, result: dict[str, Any]) -> None:
        self._state["session"]["id"] = str(result.get("session_id") or "")
        self._state["session"]["stored_id"] = str(result.get("stored_session_id") or "")
        self._state["session"]["running"] = False
        info = result.get("info") or {}
        if isinstance(info, dict):
            self._state["session"]["cwd"] = str(info.get("cwd") or self._state["session"]["cwd"])
            self._state["hermes"]["model"] = str(info.get("model") or self._state["hermes"]["model"])
            self._state["hermes"]["provider"] = str(info.get("provider") or self._state["hermes"]["provider"])
        self._state["hermes"]["status"] = "idle"
        self._state["messages"] = []
        self._state["events"] = []
        self._state["approval"] = {"pending": False, "message": "", "tool_name": "", "request": {}}
        self._state["updated_at"] = now_ts()

    def set_session_from_resume(self, result: dict[str, Any]) -> None:
        self.set_session_from_create(result)
        messages = result.get("messages")
        if isinstance(messages, list):
            normalized = []
            for item in messages:
                if not isinstance(item, dict):
                    continue
                normalized.append({
                    "id": f"msg-{uuid.uuid4().hex}",
                    "role": str(item.get("role") or ""),
                    "text": str(item.get("text") or item.get("content") or ""),
                    "streaming": False,
                    "ts": now_ts(),
                })
            self._state["messages"] = normalized

    def append_user_message(self, text: str) -> None:
        self._state["messages"].append({
            "id": f"msg-{uuid.uuid4().hex}",
            "role": "user",
            "text": text,
            "streaming": False,
            "ts": now_ts(),
        })
        self._state["session"]["running"] = True
        self._state["hermes"]["status"] = "busy"
        self._state["updated_at"] = now_ts()

    def append_assistant_message(self, text: str) -> None:
        self._state["messages"].append({
            "id": f"msg-{uuid.uuid4().hex}",
            "role": "assistant",
            "text": text,
            "streaming": False,
            "ts": now_ts(),
        })
        self._state["session"]["running"] = False
        if not self._state["approval"]["pending"]:
            self._state["hermes"]["status"] = "idle"
        self._state["updated_at"] = now_ts()

    def clear_approval(self) -> None:
        self._state["approval"] = {"pending": False, "message": "", "tool_name": "", "request": {}}
        if not self._state["session"]["running"]:
            self._state["hermes"]["status"] = "idle"
        self._state["updated_at"] = now_ts()

    def set_model(self, provider: str, model: str) -> None:
        self._state["hermes"]["provider"] = provider
        self._state["hermes"]["model"] = model
        self._state["updated_at"] = now_ts()

    def fail_request(self, message: str) -> None:
        self._state["bridge"]["error"] = message
        self._state["session"]["running"] = False
        self._state["hermes"]["status"] = "error"
        self._append_status_event({"kind": "error", "text": message})
        self._state["updated_at"] = now_ts()


class StateTransport:
    def __init__(self, state: HermesState):
        self.state = state

    def write(self, obj: dict[str, Any]) -> bool:
        self.state.apply_event(obj)
        self.state.write()
        return True


class HermesRpcClient:
    def __init__(self, state: HermesState, hermes_home: str | Path | None = None):
        self.state = state
        self.hermes_home = Path(hermes_home or "~/.hermes").expanduser()
        self.transport = StateTransport(state)
        self._server = None

    def dispatch(self, method: str, params: dict[str, Any]) -> dict[str, Any]:
        server = self._load_server()
        request = {
            "jsonrpc": "2.0",
            "id": f"noctalia-{uuid.uuid4().hex}",
            "method": method,
            "params": params,
        }
        response = server.dispatch(request, self.transport)
        return response or {"result": {"status": "accepted"}}

    def _load_server(self):
        if self._server is not None:
            return self._server

        agent_dir = self.hermes_home / "hermes-agent"
        if agent_dir.exists():
            sys.path.insert(0, str(agent_dir))
        os.environ.setdefault("HERMES_HOME", str(self.hermes_home))

        try:
            from tui_gateway import server as tui_server
        except Exception as exc:  # pragma: no cover - depends on local Hermes install
            raise RuntimeError(f"hermes_unavailable: {exc}") from exc

        self._server = tui_server
        return self._server


class BridgeRequestHandler(BaseHTTPRequestHandler):
    server_version = "HermesNoctaliaBridge/0.1"

    MAX_BODY_BYTES = 1_048_576  # ponytail: 1MB cap, prevents memory exhaustion

    def _check_token(self) -> bool:
        token = getattr(self.server, "bridge_token", "")
        if not token:
            return True
        provided = self.headers.get("X-Bridge-Token", "")
        return secrets.compare_digest(token, provided)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, health_payload(self.server.state.snapshot()))
            return
        if self.path == "/detect":
            detected = detect_all(
                self.server.state.hermes_home,
                self.server.hermes_command,
            )
            self._send_json(200, detected)
            return
        if not self._check_token():
            self._send_json(403, {"error": "forbidden"})
            return
        if self.path == "/state":
            self._send_json(200, self.server.state.snapshot())
            return
        if self.path == "/sessions":
            try:
                response = self.server.rpc.dispatch("session.list", {"limit": 10})
                result = response.get("result", response)
                self._send_json(200, result if isinstance(result, dict) else {"sessions": []})
            except Exception:
                self._send_json(200, {"sessions": []})
            return
        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if not self._check_token():
            self._send_json(403, {"error": "forbidden"})
            return
        payload = self._read_json()
        if payload is None:
            return

        try:
            if self.path == "/session/create":
                self._handle_session_create(payload)
            elif self.path == "/session/resume":
                self._handle_session_resume(payload)
            elif self.path == "/prompt":
                self._handle_prompt(payload)
            elif self.path == "/interrupt":
                self._handle_interrupt()
            elif self.path == "/approval":
                self._handle_approval(payload)
            elif self.path == "/model":
                self._handle_model(payload)
            elif self.path == "/oneshot":
                self._handle_oneshot(payload)
            elif self.path == "/refresh":
                self.server.state.write()
                self._send_json(200, self.server.state.snapshot())
            elif self.path == "/gateway/start":
                self._handle_gateway_start()
            elif self.path == "/gateway/stop":
                self._handle_gateway_stop()
            else:
                self._send_json(404, {"error": "not_found"})
        except Exception as exc:
            self.server.state.fail_request(str(exc))
            self.server.state.write()
            self._send_json(500, {"error": "bridge_error"})

    def log_message(self, _format: str, *_args: Any) -> None:
        return

    def _handle_session_create(self, payload: dict[str, Any]) -> None:
        params = {}
        if payload.get("cwd"):
            params["cwd"] = str(payload["cwd"])
        response = self.server.rpc.dispatch("session.create", params)
        result = response.get("result", response)
        if isinstance(result, dict):
            self.server.state.set_session_from_create(result)
            self.server.state.write()
        self._send_json(200, self.server.state.snapshot())

    def _handle_session_resume(self, payload: dict[str, Any]) -> None:
        session_id = str(payload.get("session_id") or "").strip()
        if not session_id:
            self._send_json(400, {"error": "missing_session_id"})
            return
        # Load messages directly from the SessionDB for instant UI feedback.
        db_path = self.server.state.hermes_home / "state.db"
        loaded = False
        if db_path.exists():
            try:
                import sqlite3
                conn = sqlite3.connect(str(db_path))
                conn.row_factory = sqlite3.Row
                rows = conn.execute(
                    "SELECT role, content FROM messages WHERE session_id = ? ORDER BY timestamp",
                    (session_id,),
                ).fetchall()
                if rows:
                    normalized = [
                        {
                            "id": f"msg-{uuid.uuid4().hex}",
                            "role": str(dict(r).get("role") or ""),
                            "text": str(dict(r).get("content") or ""),
                            "streaming": False,
                            "ts": 0,
                        }
                        for r in rows
                    ]
                    self.server.state._state["messages"] = normalized
                    self.server.state._state["session"]["id"] = ""
                    self.server.state._state["session"]["stored_id"] = session_id
                    self.server.state._state["session"]["running"] = False
                    self.server.state._state["hermes"]["status"] = "idle"
                    self.server.state._state["approval"] = (
                        {"pending": False, "message": "", "tool_name": "", "request": {}}
                    )
                    loaded = True
            except Exception:
                pass
        # Also dispatch session.resume to the gateway so it creates a proper
        # session object. The gateway needs this for prompt.submit to work.
        self.server.rpc.dispatch("session.resume", {"session_id": session_id})
        self.server.state.write()
        self._send_json(200, {"state": self.server.state.snapshot()})

    def _handle_prompt(self, payload: dict[str, Any]) -> None:
        text = str(payload.get("text") or "").strip()
        if not text:
            self._send_json(400, {"error": "empty_prompt"})
            return

        session_id = self.server.state.snapshot()["session"]["id"]
        existing_messages = list(self.server.state._state["messages"])
        if not session_id:
            create_response = self.server.rpc.dispatch("session.create", {})
            create_result = create_response.get("result", create_response)
            if isinstance(create_result, dict):
                self.server.state.set_session_from_create(create_result)
                session_id = self.server.state.snapshot()["session"]["id"]
                # Restore messages from a resumed session that were loaded from DB.
                # set_session_from_create clears messages so only the new prompt
                # would appear; we want the full history.
                if existing_messages:
                    self.server.state._state["messages"] = existing_messages

        params = {"session_id": session_id, "text": text}
        self.server.state.append_user_message(text)
        self.server.state.write()
        response = self.server.rpc.dispatch("prompt.submit", params)
        self._send_json(200, {"result": response.get("result", response), "state": self.server.state.snapshot()})

    def _handle_interrupt(self) -> None:
        session_id = self.server.state.snapshot()["session"]["id"]
        response = self.server.rpc.dispatch("session.interrupt", {"session_id": session_id})
        self.server.state._state["session"]["running"] = False
        self.server.state._state["hermes"]["status"] = "idle"
        self.server.state.write()
        self._send_json(200, {"result": response.get("result", response), "state": self.server.state.snapshot()})

    def _handle_approval(self, payload: dict[str, Any]) -> None:
        session_id = self.server.state.snapshot()["session"]["id"]
        params = {
            "session_id": session_id,
            "choice": str(payload.get("choice") or "deny"),
            "all": bool(payload.get("all", False)),
        }
        response = self.server.rpc.dispatch("approval.respond", params)
        self.server.state.clear_approval()
        self.server.state.write()
        self._send_json(200, {"result": response.get("result", response), "state": self.server.state.snapshot()})

    def _handle_model(self, payload: dict[str, Any]) -> None:
        model = str(payload.get("model") or "").strip()
        provider = str(payload.get("provider") or "").strip()
        persist = bool(payload.get("persist", False))
        if not model:
            self._send_json(400, {"error": "empty_model"})
            return

        value_parts = [model]
        if provider:
            value_parts.extend(["--provider", provider])
        if persist:
            value_parts.append("--global")

        params = {
            "key": "model",
            "value": " ".join(value_parts),
        }
        session_id = self.server.state.snapshot()["session"]["id"]
        if session_id:
            params["session_id"] = session_id

        response = self.server.rpc.dispatch("config.set", params)
        result = response.get("result", response)
        if isinstance(result, dict):
            self.server.state.set_model(provider, str(result.get("value") or model))
        else:
            self.server.state.set_model(provider, model)
        self.server.state.write()
        self._send_json(200, {"result": result, "state": self.server.state.snapshot()})

    def _handle_oneshot(self, payload: dict[str, Any]) -> None:
        text = str(payload.get("text") or "").strip()
        if not text:
            self._send_json(400, {"error": "empty_prompt"})
            return
        self.server.state.append_user_message(text)
        self.server.state.write()
        result = self.server.command_runner(
            [self.server.hermes_command, "-z", text],
            capture_output=True,
            text=True,
            timeout=600,
        )
        if result.returncode != 0:
            message = (result.stderr or result.stdout or "oneshot failed").strip()
            self.server.state._state["session"]["running"] = False
            self.server.state._state["bridge"]["error"] = message
            self.server.state.write()
            self._send_json(500, {"error": "oneshot_failed", "message": message, "state": self.server.state.snapshot()})
            return
        self.server.state.append_assistant_message((result.stdout or "").strip())
        self.server.state.write()
        self._send_json(200, {"result": {"status": "completed"}, "state": self.server.state.snapshot()})

    def _handle_gateway_start(self) -> None:
        result = self.server.command_runner(
            [self.server.hermes_command, "gateway", "start"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            msg = (result.stderr or result.stdout or "gateway start failed").strip()
            self._send_json(500, {"error": "gateway_start_failed", "message": msg})
            return
        self._send_json(200, {"result": {"status": "started"}})

    def _handle_gateway_stop(self) -> None:
        result = self.server.command_runner(
            [self.server.hermes_command, "gateway", "stop"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            msg = (result.stderr or result.stdout or "gateway stop failed").strip()
            self._send_json(500, {"error": "gateway_stop_failed", "message": msg})
            return
        self._send_json(200, {"result": {"status": "stopped"}})

    def _read_json(self) -> dict[str, Any] | None:
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length == 0:
            return {}
        if length > self.MAX_BODY_BYTES:
            self._send_json(413, {"error": "payload_too_large"})
            return None
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw.decode())
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid_json"})
            return None
        if not isinstance(data, dict):
            self._send_json(400, {"error": "invalid_payload"})
            return None
        return data

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def create_server(
    host: str,
    port: int,
    state: HermesState,
    rpc: Any,
    hermes_command: str,
) -> ThreadingHTTPServer:
    httpd = ThreadingHTTPServer((host, port), BridgeRequestHandler)
    httpd.state = state
    httpd.rpc = rpc
    httpd.hermes_command = hermes_command
    httpd.command_runner = subprocess.run
    httpd.bridge_token = ""  # set by run_server after token load
    state._state["bridge"]["status"] = "online"
    state._state["bridge"]["error"] = ""
    state._state["updated_at"] = now_ts()
    return httpd


def run_server(
    host: str,
    port: int,
    state_file: str | Path,
    hermes_home: str | Path,
    hermes_command: str,
) -> None:
    if not hermes_home or hermes_home == "~/.hermes":
        hermes_home = detect_hermes_home()
    if not hermes_command or hermes_command == "hermes":
        hermes_command = detect_hermes_command()
    state = HermesState(state_file, hermes_home)
    rpc = HermesRpcClient(state, hermes_home)
    httpd = create_server(host, port, state, rpc, hermes_command)
    token_path = state.state_file.parent / "bridge.token"
    token = load_or_create_token(token_path)
    httpd.bridge_token = token
    state.write()
    httpd.serve_forever()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Noctalia bridge for Hermes Agent")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=19777)
    parser.add_argument("--state-file", default="~/.cache/noctalia-hermes/state.json")
    parser.add_argument("--hermes-home", default="~/.hermes")
    parser.add_argument("--hermes-command", default="hermes")
    parser.add_argument("--once-health", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    argv = list(argv if argv is not None else sys.argv[1:])
    args = parse_args(argv)
    reexec_with_hermes_python(args, argv)
    if args.once_health:
        print(json.dumps(health_payload(default_state()), ensure_ascii=False))
        return 0
    run_server(args.host, args.port, args.state_file, args.hermes_home, args.hermes_command)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
