#!/usr/bin/env python3
"""Fetch live Codex usage for the Noctalia ModelBar plugin.

The data source mirrors CodexBar's Linux-friendly sources:
1. ChatGPT/Codex OAuth usage API from ~/.codex/auth.json.
2. Codex app-server JSON-RPC as a local fallback.

The script prints one compact JSON object and never prints tokens.
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import os
import pathlib
import re
import select
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from typing import Any


DEFAULT_USAGE_BASE = "https://chatgpt.com/backend-api/"
REFRESH_ENDPOINT = "https://auth.openai.com/oauth/token"
CODEX_CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"


class FetchError(RuntimeError):
    pass


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def iso_utc(value: dt.datetime | None = None) -> str:
    return (value or utc_now()).astimezone(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    raw = value.strip()
    if raw.endswith("Z"):
        raw = raw[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(raw)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def codex_home(raw: str | None) -> pathlib.Path:
    if raw:
        return pathlib.Path(os.path.expanduser(raw)).resolve()
    env_home = os.environ.get("CODEX_HOME")
    if env_home:
        return pathlib.Path(os.path.expanduser(env_home)).resolve()
    return pathlib.Path.home() / ".codex"


def read_json_file(path: pathlib.Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise FetchError(f"{path} not found. Run `codex` to authenticate.") from exc
    except json.JSONDecodeError as exc:
        raise FetchError(f"{path} is not valid JSON: {exc}") from exc


def parse_jwt_payload(token: str | None) -> dict[str, Any]:
    if not token or token.count(".") < 2:
        return {}
    part = token.split(".")[1]
    part += "=" * (-len(part) % 4)
    try:
        decoded = base64.urlsafe_b64decode(part.encode("ascii"))
        return json.loads(decoded.decode("utf-8"))
    except Exception:
        return {}


def normalize_base_url(value: str | None) -> str:
    base = (value or DEFAULT_USAGE_BASE).strip() or DEFAULT_USAGE_BASE
    while base.endswith("/"):
        base = base[:-1]
    if (base.startswith("https://chatgpt.com") or base.startswith("https://chat.openai.com")) and "/backend-api" not in base:
        base += "/backend-api"
    return base


def parse_chatgpt_base_url(home: pathlib.Path) -> str:
    config = home / "config.toml"
    try:
        text = config.read_text(encoding="utf-8")
    except FileNotFoundError:
        return DEFAULT_USAGE_BASE

    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key.strip() != "chatgpt_base_url":
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        return value.strip()
    return DEFAULT_USAGE_BASE


def usage_url(home: pathlib.Path) -> str:
    base = normalize_base_url(parse_chatgpt_base_url(home))
    path = "/wham/usage" if "/backend-api" in base else "/api/codex/usage"
    return base + path


def load_credentials(home: pathlib.Path) -> tuple[dict[str, Any], dict[str, Any]]:
    auth_path = home / "auth.json"
    auth = read_json_file(auth_path)

    api_key = auth.get("OPENAI_API_KEY")
    if isinstance(api_key, str) and api_key.strip():
        return auth, {
            "access_token": api_key.strip(),
            "refresh_token": "",
            "id_token": None,
            "account_id": None,
            "last_refresh": None,
        }

    tokens = auth.get("tokens")
    if not isinstance(tokens, dict):
        raise FetchError(f"{auth_path} exists but contains no OAuth tokens.")

    access_token = tokens.get("access_token") or tokens.get("accessToken")
    refresh_token = tokens.get("refresh_token") or tokens.get("refreshToken") or ""
    if not isinstance(access_token, str) or not access_token:
        raise FetchError(f"{auth_path} exists but contains no access token.")

    return auth, {
        "access_token": access_token,
        "refresh_token": refresh_token if isinstance(refresh_token, str) else "",
        "id_token": tokens.get("id_token") or tokens.get("idToken"),
        "account_id": tokens.get("account_id") or tokens.get("accountId"),
        "last_refresh": auth.get("last_refresh"),
    }


def credentials_need_refresh(credentials: dict[str, Any]) -> bool:
    last_refresh = parse_iso(credentials.get("last_refresh"))
    if last_refresh is None:
        return True
    return utc_now() - last_refresh > dt.timedelta(days=8)


def save_credentials(home: pathlib.Path, auth: dict[str, Any], credentials: dict[str, Any]) -> None:
    auth_path = home / "auth.json"
    tokens = {
        "access_token": credentials["access_token"],
        "refresh_token": credentials.get("refresh_token", ""),
    }
    if credentials.get("id_token"):
        tokens["id_token"] = credentials["id_token"]
    if credentials.get("account_id"):
        tokens["account_id"] = credentials["account_id"]

    auth["tokens"] = tokens
    auth["last_refresh"] = iso_utc()
    auth_path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix="auth.", suffix=".json", dir=str(auth_path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(auth, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, auth_path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def http_json(url: str, *, method: str = "GET", headers: dict[str, str] | None = None, body: Any = None, timeout: float = 30) -> dict[str, Any]:
    data = None
    request_headers = dict(headers or {})
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/json")
    request = urllib.request.Request(url, data=data, headers=request_headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw = response.read()
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        if exc.code in (401, 403):
            raise FetchError("unauthorized")
        raise FetchError(f"HTTP {exc.code}: {raw[:300]}") from exc
    except urllib.error.URLError as exc:
        raise FetchError(f"network error: {exc.reason}") from exc
    except TimeoutError as exc:
        raise FetchError("network timeout") from exc
    except json.JSONDecodeError as exc:
        raise FetchError(f"invalid JSON response: {exc}") from exc


def refresh_credentials(home: pathlib.Path, auth: dict[str, Any], credentials: dict[str, Any], timeout: float) -> dict[str, Any]:
    refresh_token = credentials.get("refresh_token")
    if not refresh_token:
        return credentials

    payload = {
        "client_id": CODEX_CLIENT_ID,
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
        "scope": "openid profile email",
    }
    response = http_json(REFRESH_ENDPOINT, method="POST", body=payload, timeout=timeout)
    credentials = dict(credentials)
    credentials["access_token"] = response.get("access_token") or credentials["access_token"]
    credentials["refresh_token"] = response.get("refresh_token") or credentials["refresh_token"]
    credentials["id_token"] = response.get("id_token") or credentials.get("id_token")
    credentials["last_refresh"] = iso_utc()
    save_credentials(home, auth, credentials)
    return credentials


def make_window(raw: dict[str, Any] | None) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None

    used = raw.get("used_percent", raw.get("usedPercent"))
    reset_at = raw.get("reset_at", raw.get("resetsAt"))
    window_seconds = raw.get("limit_window_seconds")
    window_minutes = raw.get("windowDurationMins", raw.get("window_minutes"))

    try:
        used_float = float(used)
    except (TypeError, ValueError):
        return None

    if window_minutes is None and window_seconds is not None:
        try:
            window_minutes = int(window_seconds) // 60
        except (TypeError, ValueError):
            window_minutes = None

    reset_iso = None
    if reset_at is not None:
        try:
            reset_iso = iso_utc(dt.datetime.fromtimestamp(float(reset_at), tz=dt.timezone.utc))
        except (TypeError, ValueError, OSError):
            if isinstance(reset_at, str):
                parsed = parse_iso(reset_at)
                reset_iso = iso_utc(parsed) if parsed else None

    label = "Session" if window_minutes == 300 else "Weekly" if window_minutes == 10080 else "Window"
    return {
        "label": label,
        "usedPercent": max(0.0, min(100.0, used_float)),
        "remainingPercent": max(0.0, min(100.0, 100.0 - used_float)),
        "windowMinutes": window_minutes,
        "resetsAt": reset_iso,
    }


def normalize_windows(primary: dict[str, Any] | None, secondary: dict[str, Any] | None) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    def role(window: dict[str, Any] | None) -> str:
        minutes = window.get("windowMinutes") if window else None
        if minutes == 300:
            return "session"
        if minutes == 10080:
            return "weekly"
        return "unknown"

    first = make_window(primary)
    second = make_window(secondary)
    first_role = role(first)
    second_role = role(second)

    if first and second and first_role == "weekly" and second_role in ("session", "unknown"):
        return second, first
    if first and not second and first_role == "weekly":
        return None, first
    if second and not first and second_role == "session":
        return second, None
    return first, second


def account_from_credentials(credentials: dict[str, Any], plan: str | None) -> dict[str, Any]:
    payload = parse_jwt_payload(credentials.get("id_token"))
    profile = payload.get("https://api.openai.com/profile") if isinstance(payload.get("https://api.openai.com/profile"), dict) else {}
    auth = payload.get("https://api.openai.com/auth") if isinstance(payload.get("https://api.openai.com/auth"), dict) else {}
    email = payload.get("email") or profile.get("email")
    resolved_plan = plan or auth.get("chatgpt_plan_type") or payload.get("chatgpt_plan_type")
    return {
        "email": email if isinstance(email, str) else "",
        "plan": resolved_plan if isinstance(resolved_plan, str) else "",
    }


def fetch_oauth(home: pathlib.Path, timeout: float) -> dict[str, Any]:
    auth, credentials = load_credentials(home)
    if credentials_need_refresh(credentials) and credentials.get("refresh_token"):
        credentials = refresh_credentials(home, auth, credentials, timeout)

    headers = {
        "Authorization": f"Bearer {credentials['access_token']}",
        "Accept": "application/json",
        "User-Agent": "ModelBar-Noctalia",
    }
    account_id = credentials.get("account_id")
    if isinstance(account_id, str) and account_id:
        headers["ChatGPT-Account-Id"] = account_id

    response = http_json(usage_url(home), headers=headers, timeout=timeout)
    rate_limit = response.get("rate_limit") if isinstance(response.get("rate_limit"), dict) else {}
    primary, secondary = normalize_windows(rate_limit.get("primary_window"), rate_limit.get("secondary_window"))

    credits_raw = response.get("credits") if isinstance(response.get("credits"), dict) else {}
    plan_type = response.get("plan_type") if isinstance(response.get("plan_type"), str) else None

    return {
        "source": "oauth",
        "usage": {
            "primary": primary,
            "secondary": secondary,
        },
        "credits": {
            "remaining": parse_float(credits_raw.get("balance"), -1),
            "hasCredits": bool(credits_raw.get("has_credits", False)),
            "unlimited": bool(credits_raw.get("unlimited", False)),
        },
        "account": account_from_credentials(credentials, plan_type),
    }


def parse_float(value: Any, fallback: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return fallback


class CodexRPC:
    def __init__(self, codex_bin: str, home: pathlib.Path, timeout: float) -> None:
        self.timeout = timeout
        env = os.environ.copy()
        env["CODEX_HOME"] = str(home)
        command = [codex_bin, "-s", "read-only", "-a", "untrusted", "app-server"]
        self.proc = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            env=env,
        )
        self.next_id = 1

    def close(self) -> None:
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.proc.kill()

    def send(self, payload: dict[str, Any]) -> None:
        if self.proc.stdin is None:
            raise FetchError("codex app-server stdin is closed")
        self.proc.stdin.write(json.dumps(payload, separators=(",", ":")) + "\n")
        self.proc.stdin.flush()

    def request(self, method: str, params: dict[str, Any] | None = None, timeout: float | None = None) -> dict[str, Any]:
        request_id = self.next_id
        self.next_id += 1
        self.send({"id": request_id, "method": method, "params": params or {}})
        deadline = time.monotonic() + (timeout or self.timeout)

        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise FetchError(f"codex app-server timed out waiting for {method}")
            if self.proc.stdout is None:
                raise FetchError("codex app-server stdout is closed")
            ready, _, _ = select.select([self.proc.stdout], [], [], remaining)
            if not ready:
                raise FetchError(f"codex app-server timed out waiting for {method}")
            line = self.proc.stdout.readline()
            if not line:
                stderr = self.proc.stderr.read() if self.proc.stderr else ""
                raise FetchError(f"codex app-server exited early. {stderr.strip()}")
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if "id" not in message:
                continue
            if message.get("id") != request_id:
                continue
            if isinstance(message.get("error"), dict):
                text = message["error"].get("message") or json.dumps(message["error"])
                raise FetchError(str(text))
            if "result" not in message:
                raise FetchError(f"codex app-server returned no result for {method}")
            return message["result"]

    def notify(self, method: str, params: dict[str, Any] | None = None) -> None:
        self.send({"method": method, "params": params or {}})


def extract_error_body(message: str) -> dict[str, Any] | None:
    marker = "body="
    start = message.find(marker)
    if start < 0:
        return None
    text = message[start + len(marker) :]
    brace = text.find("{")
    if brace < 0:
        return None
    depth = 0
    for index, char in enumerate(text[brace:], start=brace):
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[brace : index + 1])
                except json.JSONDecodeError:
                    return None
    return None


def fetch_cli(home: pathlib.Path, codex_bin: str, timeout: float) -> dict[str, Any]:
    rpc = CodexRPC(codex_bin, home, timeout)
    try:
        rpc.request(
            "initialize",
            {"clientInfo": {"name": "modelbar-noctalia", "version": "0.1.0"}},
            timeout=max(timeout, 8),
        )
        rpc.notify("initialized")
        try:
            rate_result = rpc.request("account/rateLimits/read")
        except FetchError as exc:
            body = extract_error_body(str(exc))
            if body is None:
                raise
            rate_limits = {
                "primary": (body.get("rate_limit") or {}).get("primary_window"),
                "secondary": (body.get("rate_limit") or {}).get("secondary_window"),
                "credits": body.get("credits") or {},
                "planType": body.get("plan_type"),
            }
            account = {"email": body.get("email") or "", "plan": body.get("plan_type") or ""}
        else:
            rate_limits = rate_result.get("rateLimits", {}) if isinstance(rate_result, dict) else {}
            account = read_cli_account(rpc)

        primary, secondary = normalize_windows(rate_limits.get("primary"), rate_limits.get("secondary"))
        credits_raw = rate_limits.get("credits") if isinstance(rate_limits.get("credits"), dict) else {}
        if account.get("plan", "") == "":
            plan = rate_limits.get("planType")
            if isinstance(plan, str):
                account["plan"] = plan
        return {
            "source": "codex-cli",
            "usage": {
                "primary": primary,
                "secondary": secondary,
            },
            "credits": {
                "remaining": parse_float(credits_raw.get("balance"), -1),
                "hasCredits": bool(credits_raw.get("hasCredits", False)),
                "unlimited": bool(credits_raw.get("unlimited", False)),
            },
            "account": account,
        }
    finally:
        rpc.close()


def read_cli_account(rpc: CodexRPC) -> dict[str, str]:
    try:
        result = rpc.request("account/read")
    except FetchError:
        return {"email": "", "plan": ""}
    account = result.get("account") if isinstance(result, dict) else None
    if not isinstance(account, dict):
        return {"email": "", "plan": ""}
    if str(account.get("type", "")).lower() == "chatgpt":
        return {
            "email": account.get("email") if isinstance(account.get("email"), str) else "",
            "plan": account.get("planType") if isinstance(account.get("planType"), str) else "",
        }
    if str(account.get("type", "")).lower() == "apikey":
        return {"email": "", "plan": "api-key"}
    return {"email": "", "plan": ""}


def parse_entry_time(value: Any) -> dt.datetime | None:
    if isinstance(value, (int, float)):
        seconds = float(value) / 1000 if value > 1_000_000_000_000 else float(value)
        try:
            return dt.datetime.fromtimestamp(seconds, tz=dt.timezone.utc)
        except (ValueError, OSError):
            return None
    if isinstance(value, str):
        return parse_iso(value)
    return None


def local_history_stats(home: pathlib.Path) -> dict[str, Any]:
    today = dt.datetime.now().astimezone().date()
    prompts = 0
    sessions: set[str] = set()
    history = home / "history.jsonl"

    try:
        lines = history.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        lines = []

    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        when = parse_entry_time(entry.get("ts") or entry.get("timestamp"))
        if when is None:
            continue
        local_date = when.astimezone().date()
        if local_date < today:
            break
        if local_date > today:
            continue
        prompts += 1
        session_id = entry.get("session_id") or entry.get("sessionId")
        if isinstance(session_id, str) and session_id:
            sessions.add(session_id)

    latest_tokens, latest_model, latest_path = latest_session_usage(home)
    model = latest_model or parse_config_model(home)
    return {
        "promptsToday": prompts,
        "sessionsToday": len(sessions),
        "latestSessionTokens": latest_tokens,
        "latestModel": model,
        "latestSessionPath": latest_path,
    }


def parse_config_model(home: pathlib.Path) -> str:
    try:
        text = (home / "config.toml").read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""
    match = re.search(r"^\s*model\s*=\s*['\"]([^'\"]+)['\"]", text, flags=re.MULTILINE)
    return match.group(1) if match else ""


def latest_session_usage(home: pathlib.Path) -> tuple[int, str, str]:
    sessions_dir = home / "sessions"
    if not sessions_dir.exists():
        return 0, "", ""

    files = [path for path in sessions_dir.rglob("*.jsonl") if path.is_file()]
    if not files:
        return 0, "", ""
    latest = max(files, key=lambda path: path.stat().st_mtime)

    model = ""
    token_total = 0
    try:
        lines = latest.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return 0, "", str(latest)

    for line in reversed(lines[-1000:]):
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not model:
            model = extract_model(entry)
        payload = token_payload(entry)
        if not payload:
            continue
        usage = payload.get("info", {}).get("total_token_usage")
        if not isinstance(usage, dict):
            continue
        token_total = int(parse_float(usage.get("input_tokens"))) + int(parse_float(usage.get("output_tokens")))
        token_total += int(parse_float(usage.get("cached_input_tokens"))) + int(parse_float(usage.get("reasoning_output_tokens")))
        break

    return token_total, model, str(latest)


def extract_model(entry: dict[str, Any]) -> str:
    payload = entry.get("payload") if isinstance(entry.get("payload"), dict) else {}
    context = payload.get("turn_context") if isinstance(payload.get("turn_context"), dict) else {}
    model = context.get("model") or payload.get("model") or entry.get("model")
    return model if isinstance(model, str) else ""


def token_payload(entry: dict[str, Any]) -> dict[str, Any] | None:
    payload = entry.get("payload")
    if entry.get("type") == "token_count":
        return entry
    if isinstance(payload, dict) and entry.get("type") == "event_msg" and payload.get("type") == "token_count":
        return payload
    nested = payload.get("payload") if isinstance(payload, dict) and isinstance(payload.get("payload"), dict) else None
    if nested and payload.get("type") == "event_msg" and nested.get("type") == "token_count":
        return nested
    return None


def response(ok: bool, **fields: Any) -> dict[str, Any]:
    payload = {"ok": ok, "provider": "codex", "updatedAt": iso_utc()}
    payload.update(fields)
    return payload


def fetch(args: argparse.Namespace) -> dict[str, Any]:
    home = codex_home(args.codex_home)
    errors: list[str] = []

    if args.source in ("auto", "oauth"):
        try:
            data = fetch_oauth(home, args.timeout)
            data["local"] = local_history_stats(home)
            data["errors"] = errors
            return response(True, **data)
        except Exception as exc:
            if args.source == "oauth":
                raise
            errors.append(f"oauth: {exc}")

    if args.source in ("auto", "cli"):
        try:
            data = fetch_cli(home, args.codex_bin, args.timeout)
            data["local"] = local_history_stats(home)
            data["errors"] = errors
            return response(True, **data)
        except Exception as exc:
            errors.append(f"cli: {exc}")
            raise FetchError("; ".join(errors)) from exc

    raise FetchError(f"unsupported source: {args.source}")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch Codex usage for Noctalia ModelBar.")
    parser.add_argument("--source", choices=("auto", "oauth", "cli"), default="auto")
    parser.add_argument("--codex-bin", default="codex")
    parser.add_argument("--codex-home", default="")
    parser.add_argument("--timeout", type=float, default=8)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        payload = fetch(args)
    except Exception as exc:
        payload = response(False, error=str(exc), errors=[str(exc)])
        print(json.dumps(payload, separators=(",", ":")))
        return 1

    print(json.dumps(payload, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
