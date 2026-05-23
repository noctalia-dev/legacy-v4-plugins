#!/usr/bin/env python3
"""Fetch Codex and Claude Code usage for the Noctalia ModelBar plugin.

Codex usage is delegated to codex_usage.py. Claude usage mirrors CodexBar's
OAuth path: read Claude Code credentials from ~/.claude/.credentials.json and
call Anthropic's OAuth usage endpoint. Tokens are never printed.
"""

from __future__ import annotations

import argparse
import datetime as dt
import email.utils
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

sys.dont_write_bytecode = True

import codex_usage


CLAUDE_CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
CLAUDE_REFRESH_ENDPOINT = "https://platform.claude.com/v1/oauth/token"
CLAUDE_USAGE_ENDPOINT = "https://api.anthropic.com/api/oauth/usage"
CLAUDE_BETA_HEADER = "oauth-2025-04-20"
DEFAULT_CLAUDE_CACHE_TTL_SECONDS = 5 * 60
DEFAULT_CLAUDE_RATE_LIMIT_BACKOFF_SECONDS = 15 * 60
MAX_STALE_CLAUDE_CACHE_SECONDS = 24 * 60 * 60
CLAUDE_CREDITS_DISPLAY_UNIT = "major"


class FetchError(RuntimeError):
    pass


class HTTPFetchError(FetchError):
    def __init__(self, code: int, body: str, retry_after_seconds: int | None = None) -> None:
        self.code = code
        self.body = body
        self.retry_after_seconds = retry_after_seconds
        super().__init__(f"HTTP {code}: {body[:300]}")


def iso_utc(value: dt.datetime | None = None) -> str:
    return codex_usage.iso_utc(value)


def parse_iso(value: str | None) -> dt.datetime | None:
    return codex_usage.parse_iso(value)


def parse_float(value: Any, fallback: float = 0.0) -> float:
    return codex_usage.parse_float(value, fallback)


def clamp_percent(value: Any) -> float:
    return max(0.0, min(100.0, parse_float(value)))


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def parse_retry_after(value: str | None) -> int | None:
    if not value:
        return None
    raw = value.strip()
    try:
        seconds = int(float(raw))
        return max(1, seconds)
    except ValueError:
        pass
    parsed = parse_iso(raw)
    if not parsed:
        try:
            parsed = email.utils.parsedate_to_datetime(raw)
        except (TypeError, ValueError):
            parsed = None
    if not parsed:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return max(1, int((parsed - utc_now()).total_seconds()))


def expand_path(raw: str | None, default: pathlib.Path) -> pathlib.Path:
    if raw:
        return pathlib.Path(os.path.expanduser(raw)).resolve()
    return default


def claude_home(raw: str | None) -> pathlib.Path:
    env_home = os.environ.get("CLAUDE_CONFIG_DIR") or os.environ.get("CLAUDE_HOME")
    if raw:
        return expand_path(raw, pathlib.Path.home() / ".claude")
    if env_home:
        return expand_path(env_home, pathlib.Path.home() / ".claude")
    return pathlib.Path.home() / ".claude"


def read_json_file(path: pathlib.Path, app_name: str) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise FetchError(f"{path} not found. Run `{app_name}` to authenticate.") from exc
    except json.JSONDecodeError as exc:
        raise FetchError(f"{path} is not valid JSON: {exc}") from exc


def http_json(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    body: bytes | None = None,
    timeout: float = 30,
    auth_errors_as_http: bool = False,
) -> dict[str, Any]:
    request = urllib.request.Request(url, data=body, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        if exc.code in (401, 403) and not auth_errors_as_http:
            raise FetchError("unauthorized")
        retry_after = parse_retry_after(exc.headers.get("Retry-After") if exc.headers else None)
        raise HTTPFetchError(exc.code, raw, retry_after) from exc
    except urllib.error.URLError as exc:
        raise FetchError(f"network error: {exc.reason}") from exc
    except TimeoutError as exc:
        raise FetchError("network timeout") from exc
    except json.JSONDecodeError as exc:
        raise FetchError(f"invalid JSON response: {exc}") from exc


def save_claude_credentials(path: pathlib.Path, root: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=".credentials.", suffix=".json", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(root, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def load_claude_oauth(home: pathlib.Path) -> tuple[pathlib.Path, dict[str, Any], dict[str, Any]]:
    path = home / ".credentials.json"
    root = read_json_file(path, "claude")
    oauth = root.get("claudeAiOauth")
    if not isinstance(oauth, dict):
        raise FetchError(f"{path} contains no Claude OAuth credentials.")
    token = oauth.get("accessToken")
    if not isinstance(token, str) or not token:
        raise FetchError(f"{path} contains no Claude access token.")
    return path, root, oauth


def claude_credentials_expired(oauth: dict[str, Any]) -> bool:
    expires_at = parse_float(oauth.get("expiresAt"), 0)
    if expires_at <= 0:
        return True
    expires_at_seconds = expires_at / 1000.0
    return dt.datetime.now(dt.timezone.utc).timestamp() >= expires_at_seconds - 60


def refresh_claude_oauth(
    path: pathlib.Path,
    root: dict[str, Any],
    oauth: dict[str, Any],
    timeout: float,
) -> dict[str, Any]:
    refresh_token = oauth.get("refreshToken")
    if not isinstance(refresh_token, str) or not refresh_token:
        return oauth

    client_id = os.environ.get("CODEXBAR_CLAUDE_OAUTH_CLIENT_ID", CLAUDE_CLIENT_ID)
    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "refresh_token": refresh_token,
            "client_id": client_id,
        }
    ).encode("utf-8")
    response = http_json(
        CLAUDE_REFRESH_ENDPOINT,
        method="POST",
        body=body,
        timeout=timeout,
        headers={
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )

    access_token = response.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise FetchError("Claude OAuth refresh returned no access token.")

    refreshed = dict(oauth)
    refreshed["accessToken"] = access_token
    if isinstance(response.get("refresh_token"), str) and response["refresh_token"]:
        refreshed["refreshToken"] = response["refresh_token"]
    expires_in = parse_float(response.get("expires_in"), 0)
    if expires_in > 0:
        refreshed["expiresAt"] = int((dt.datetime.now(dt.timezone.utc).timestamp() + expires_in) * 1000)

    root["claudeAiOauth"] = refreshed
    save_claude_credentials(path, root)
    return refreshed


def claude_code_version(claude_bin: str, timeout: float) -> str:
    try:
        result = subprocess.run(
            [claude_bin, "--version"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=min(max(timeout, 1), 3),
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "2.1.0"
    token = (result.stdout or "").strip().split()
    return token[0] if token else "2.1.0"


def fetch_claude_usage_response(oauth: dict[str, Any], version: str, timeout: float) -> dict[str, Any]:
    return http_json(
        CLAUDE_USAGE_ENDPOINT,
        headers={
            "Authorization": f"Bearer {oauth['accessToken']}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "anthropic-beta": CLAUDE_BETA_HEADER,
            "User-Agent": f"claude-code/{version}",
        },
        timeout=timeout,
        auth_errors_as_http=True,
    )


def modelbar_cache_dir() -> pathlib.Path:
    base = pathlib.Path(os.environ.get("XDG_CACHE_HOME") or pathlib.Path.home() / ".cache")
    return base / "modelbar"


def claude_cache_key(home: pathlib.Path) -> str:
    return hashlib.sha256(str(home.resolve()).encode("utf-8")).hexdigest()[:16]


def claude_cache_path(home: pathlib.Path) -> pathlib.Path:
    return modelbar_cache_dir() / f"claude-usage-{claude_cache_key(home)}.json"


def claude_backoff_path(home: pathlib.Path) -> pathlib.Path:
    return modelbar_cache_dir() / f"claude-backoff-{claude_cache_key(home)}.json"


def read_json_cache(path: pathlib.Path) -> dict[str, Any] | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def write_json_cache(path: pathlib.Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, separators=(",", ":"))
            handle.write("\n")
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass


def cached_provider_age_seconds(cache: dict[str, Any]) -> float | None:
    fetched_at = parse_iso(cache.get("fetchedAt") if isinstance(cache.get("fetchedAt"), str) else None)
    if not fetched_at:
        return None
    return max(0.0, (utc_now() - fetched_at).total_seconds())


def cached_claude_provider(home: pathlib.Path, max_age_seconds: int) -> dict[str, Any] | None:
    if max_age_seconds <= 0:
        return None
    cache = read_json_cache(claude_cache_path(home))
    if not cache:
        return None
    age = cached_provider_age_seconds(cache)
    if age is None or age > max_age_seconds:
        return None
    provider = cache.get("provider")
    if not isinstance(provider, dict):
        return None
    provider = normalize_cached_claude_provider(dict(provider))
    provider["cache"] = {"status": "fresh", "ageSeconds": int(age)}
    return provider


def stale_claude_provider(home: pathlib.Path) -> dict[str, Any] | None:
    cache = read_json_cache(claude_cache_path(home))
    if not cache:
        return None
    age = cached_provider_age_seconds(cache)
    if age is None or age > MAX_STALE_CLAUDE_CACHE_SECONDS:
        return None
    provider = cache.get("provider")
    if not isinstance(provider, dict):
        return None
    provider = normalize_cached_claude_provider(dict(provider))
    errors = list(provider.get("errors") if isinstance(provider.get("errors"), list) else [])
    errors.append("Using cached Claude usage because live usage is temporarily unavailable.")
    provider["errors"] = errors
    provider["cache"] = {"status": "stale", "ageSeconds": int(age)}
    return provider


def write_claude_provider_cache(home: pathlib.Path, provider: dict[str, Any]) -> None:
    write_json_cache(
        claude_cache_path(home),
        {
            "fetchedAt": iso_utc(),
            "provider": provider,
        },
    )


def active_claude_backoff(home: pathlib.Path) -> dict[str, Any] | None:
    data = read_json_cache(claude_backoff_path(home))
    if not data:
        return None
    until = parse_iso(data.get("until") if isinstance(data.get("until"), str) else None)
    if not until or until <= utc_now():
        try:
            claude_backoff_path(home).unlink()
        except FileNotFoundError:
            pass
        except OSError:
            pass
        return None
    data["remainingSeconds"] = max(1, int((until - utc_now()).total_seconds()))
    return data


def write_claude_backoff(home: pathlib.Path, seconds: int, reason: str) -> None:
    seconds = max(60, min(seconds, 60 * 60))
    until = utc_now() + dt.timedelta(seconds=seconds)
    write_json_cache(
        claude_backoff_path(home),
        {
            "until": iso_utc(until),
            "reason": reason,
        },
    )


def clear_claude_backoff(home: pathlib.Path) -> None:
    try:
        claude_backoff_path(home).unlink()
    except FileNotFoundError:
        pass
    except OSError:
        pass


def make_claude_window(raw: Any, window_minutes: int, label: str) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    if raw.get("utilization") is None:
        return None
    used = clamp_percent(raw.get("utilization"))
    resets_at = None
    if isinstance(raw.get("resets_at"), str):
        parsed = parse_iso(raw.get("resets_at"))
        resets_at = iso_utc(parsed) if parsed else None
    return {
        "label": label,
        "usedPercent": used,
        "remainingPercent": max(0.0, min(100.0, 100.0 - used)),
        "windowMinutes": window_minutes,
        "resetsAt": resets_at,
    }


def claude_extra_window_label(key: str) -> str:
    name = key
    if name.startswith("seven_day_"):
        name = name[len("seven_day_") :]
    words = [part.capitalize() for part in name.split("_") if part]
    if not words:
        return key
    return " ".join(words) + " weekly"


def make_claude_extra_windows(raw: dict[str, Any]) -> list[dict[str, Any]]:
    definitions = [
        ("Sonnet weekly", ["seven_day_sonnet", "sonnet"]),
        ("Opus weekly", ["seven_day_opus", "opus"]),
        ("Haiku weekly", ["seven_day_haiku", "haiku"]),
        ("Claude Design", ["seven_day_design", "seven_day_claude_design", "claude_design", "design", "seven_day_omelette", "omelette", "omelette_promotional"]),
        ("Claude Routines", ["seven_day_routines", "seven_day_claude_routines", "claude_routines", "routines", "routine", "seven_day_cowork", "cowork"]),
    ]
    windows: list[dict[str, Any]] = []
    known_keys = {key for _, keys in definitions for key in keys}

    for label, keys in definitions:
        for key in keys:
            window = make_claude_window(raw.get(key), 7 * 24 * 60, label)
            if window:
                windows.append(window)
                break

    for key in sorted(raw.keys()):
        if key in known_keys or key in {"seven_day", "five_hour", "extra_usage"}:
            continue
        if not key.startswith("seven_day_"):
            continue
        window = make_claude_window(raw.get(key), 7 * 24 * 60, claude_extra_window_label(key))
        if window:
            windows.append(window)

    return windows


def claude_plan_label(subscription_type: Any, rate_limit_tier: Any) -> str:
    subscription = str(subscription_type or "").strip().lower()
    tier = str(rate_limit_tier or "").strip().lower()
    source = f"{subscription} {tier}"

    if "max" in source:
        if "20x" in source:
            return "Claude Max 20x"
        if "5x" in source:
            return "Claude Max 5x"
        return "Claude Max"
    if "pro" in source:
        return "Claude Pro"
    if "team" in source:
        return "Claude Team"
    if "enterprise" in source:
        return "Claude Enterprise"
    if "ultra" in source:
        return "Claude Ultra"
    return str(subscription_type or rate_limit_tier or "")


def claude_response_has_primary_usage_window(
    response: dict[str, Any],
    primary: dict[str, Any] | None,
    secondary: dict[str, Any] | None,
) -> bool:
    if primary is not None or secondary is not None:
        return True
    for key in ("seven_day_oauth_apps", "seven_day_sonnet", "seven_day_opus", "sonnet", "opus"):
        if make_claude_window(response.get(key), 7 * 24 * 60, key):
            return True
    return False


def claude_extra_usage_is_spend_limit(oauth: dict[str, Any], has_usage_window: bool, extra_enabled: bool) -> bool:
    if not extra_enabled:
        return False
    source = f"{oauth.get('subscriptionType') or ''} {oauth.get('rateLimitTier') or ''}".lower()
    return not has_usage_window or "enterprise" in source


def normalize_claude_extra_usage_amounts(used: float, limit: float, treat_as_major_units: bool) -> tuple[float, float]:
    if used < 0 or limit < 0 or treat_as_major_units:
        return used, limit
    return used / 100.0, limit / 100.0


def normalize_cached_claude_provider(provider: dict[str, Any]) -> dict[str, Any]:
    if provider.get("provider") != "claude":
        return provider

    credits = provider.get("credits")
    if not isinstance(credits, dict) or credits.get("displayUnit") == CLAUDE_CREDITS_DISPLAY_UNIT:
        return provider

    used = parse_float(credits.get("used"), -1)
    limit = parse_float(credits.get("limit"), -1)
    if used < 0 or limit < 0:
        return provider

    account = provider.get("account") if isinstance(provider.get("account"), dict) else {}
    plan = f"{account.get('plan') or ''} {account.get('planRaw') or ''}".lower()
    treat_as_major = "enterprise" in plan or str(credits.get("period") or "").lower() == "spend limit"
    normalized_used, normalized_limit = normalize_claude_extra_usage_amounts(used, limit, treat_as_major)

    normalized_credits = dict(credits)
    normalized_credits["used"] = normalized_used
    normalized_credits["limit"] = normalized_limit
    normalized_credits["remaining"] = normalized_limit - normalized_used if normalized_limit >= 0 and normalized_used >= 0 else -1
    normalized_credits["period"] = "Spend limit" if treat_as_major else "Monthly cap"
    normalized_credits["displayUnit"] = CLAUDE_CREDITS_DISPLAY_UNIT
    provider["credits"] = normalized_credits
    return provider


def format_codex_plan(raw_plan: Any) -> str:
    raw = str(raw_plan or "").strip()
    normalized = raw.lower().replace("-", "_")
    mapping = {
        "prolite": "ChatGPT Pro",
        "pro_lite": "ChatGPT Pro",
        "pro": "ChatGPT Pro",
        "plus": "ChatGPT Plus",
        "team": "ChatGPT Team",
        "enterprise": "ChatGPT Enterprise",
        "free": "Free",
        "api_key": "API key",
    }
    return mapping.get(normalized, raw)


def fetch_claude_oauth(home: pathlib.Path, claude_bin: str, timeout: float) -> dict[str, Any]:
    path, root, oauth = load_claude_oauth(home)
    if claude_credentials_expired(oauth):
        oauth = refresh_claude_oauth(path, root, oauth, timeout)

    version = claude_code_version(claude_bin, timeout)
    try:
        response = fetch_claude_usage_response(oauth, version, timeout)
    except HTTPFetchError as exc:
        if exc.code not in (401, 403):
            raise

        # Claude Code can refresh credentials after a reboot even when expiresAt
        # has not passed. Mirror that by forcing one refresh on auth rejection.
        refresh_token = oauth.get("refreshToken")
        if not isinstance(refresh_token, str) or not refresh_token:
            raise FetchError("unauthorized") from exc

        oauth = refresh_claude_oauth(path, root, oauth, timeout)
        try:
            response = fetch_claude_usage_response(oauth, version, timeout)
        except HTTPFetchError as retry_exc:
            if retry_exc.code in (401, 403):
                raise FetchError("unauthorized") from retry_exc
            raise

    primary = make_claude_window(response.get("five_hour"), 5 * 60, "Session")
    secondary = make_claude_window(response.get("seven_day"), 7 * 24 * 60, "Weekly")
    extra_usage = response.get("extra_usage") if isinstance(response.get("extra_usage"), dict) else {}
    extra_enabled = bool(extra_usage.get("is_enabled", False))
    extra_limit_raw = parse_float(extra_usage.get("monthly_limit"), -1)
    extra_used_raw = parse_float(extra_usage.get("used_credits"), -1)
    has_usage_window = claude_response_has_primary_usage_window(response, primary, secondary)
    extra_is_spend_limit = claude_extra_usage_is_spend_limit(oauth, has_usage_window, extra_enabled)
    extra_used, extra_limit = normalize_claude_extra_usage_amounts(extra_used_raw, extra_limit_raw, extra_is_spend_limit)
    extra_remaining = extra_limit - extra_used if extra_limit >= 0 and extra_used >= 0 else -1
    extra_period = "Spend limit" if extra_is_spend_limit else "Monthly cap"

    plan = claude_plan_label(oauth.get("subscriptionType"), oauth.get("rateLimitTier"))
    return {
        "ok": True,
        "provider": "claude",
        "providerLabel": "Claude Code",
        "shortLabel": "Cl",
        "source": "claude-oauth",
        "usage": {
            "primary": primary,
            "secondary": secondary,
            "tertiary": None,
            "extraRateWindows": make_claude_extra_windows(response),
        },
        "credits": {
            "remaining": max(-1.0, extra_remaining),
            "used": extra_used,
            "limit": extra_limit,
            "currency": extra_usage.get("currency") if isinstance(extra_usage.get("currency"), str) else "",
            "hasCredits": extra_enabled,
            "unlimited": False,
            "period": extra_period if extra_enabled and extra_limit >= 0 and extra_used >= 0 else "",
            "displayUnit": CLAUDE_CREDITS_DISPLAY_UNIT,
        },
        "account": {
            "email": "",
            "plan": plan,
            "planRaw": oauth.get("subscriptionType") or oauth.get("rateLimitTier") or "",
            "organization": "",
            "loginMethod": plan,
        },
        "local": claude_local_stats(home),
        "updatedAt": iso_utc(),
        "errors": [],
    }


def project_dirs_for_claude(home: pathlib.Path) -> list[pathlib.Path]:
    dirs = [home / "projects"]
    default_home = pathlib.Path.home() / ".claude"
    if home == default_home:
        dirs.append(pathlib.Path.home() / ".config" / "claude" / "projects")
    seen: set[str] = set()
    result: list[pathlib.Path] = []
    for directory in dirs:
        key = str(directory)
        if key not in seen and directory.exists():
            seen.add(key)
            result.append(directory)
    return result


def claude_local_stats(home: pathlib.Path) -> dict[str, Any]:
    today = dt.datetime.now().astimezone().date()
    prompts = 0
    seen_prompts: set[str] = set()
    sessions: set[str] = set()
    files: list[pathlib.Path] = []

    for directory in project_dirs_for_claude(home):
        files.extend(path for path in directory.glob("*/*.jsonl") if path.is_file())

    for path in files:
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        for line in lines:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            timestamp = codex_usage.parse_entry_time(entry.get("timestamp"))
            if timestamp is None or timestamp.astimezone().date() != today:
                continue
            session_id = entry.get("sessionId")
            if isinstance(session_id, str) and session_id:
                sessions.add(session_id)
            if entry.get("type") != "user":
                continue
            prompt_id = entry.get("promptId") or entry.get("uuid") or f"{path}:{line[:80]}"
            prompt_key = str(prompt_id)
            if prompt_key in seen_prompts:
                continue
            seen_prompts.add(prompt_key)
            prompts += 1

    latest_tokens, latest_model, latest_path = latest_claude_session_usage(files)
    return {
        "promptsToday": prompts,
        "sessionsToday": len(sessions),
        "latestSessionTokens": latest_tokens,
        "latestModel": latest_model,
        "latestSessionPath": latest_path,
    }


def latest_claude_session_usage(files: list[pathlib.Path]) -> tuple[int, str, str]:
    if not files:
        return 0, "", ""
    try:
        latest = max(files, key=lambda path: path.stat().st_mtime)
    except OSError:
        return 0, "", ""

    try:
        lines = latest.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return 0, "", str(latest)

    for line in reversed(lines[-2000:]):
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        message = entry.get("message") if isinstance(entry.get("message"), dict) else {}
        usage = message.get("usage") if isinstance(message.get("usage"), dict) else None
        if not usage:
            continue
        model = message.get("model") if isinstance(message.get("model"), str) else ""
        total = 0
        for key in ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"):
            total += int(parse_float(usage.get(key)))
        return total, model, str(latest)

    return 0, "", str(latest)


def fetch_claude(args: argparse.Namespace) -> dict[str, Any]:
    home = claude_home(args.claude_home)
    if args.claude_source not in ("auto", "oauth"):
        raise FetchError(f"unsupported Claude source: {args.claude_source}")

    cached = cached_claude_provider(home, int(args.claude_cache_ttl))
    if cached:
        return cached

    backoff = active_claude_backoff(home)
    if backoff:
        stale = stale_claude_provider(home)
        if stale:
            return stale
        raise FetchError(
            "Claude usage refresh is in backoff for "
            f"{backoff.get('remainingSeconds', 'unknown')}s after a rate-limit or transient error."
        )

    try:
        provider = fetch_claude_oauth(home, args.claude_bin, args.timeout)
    except HTTPFetchError as exc:
        if exc.code == 429:
            backoff_seconds = exc.retry_after_seconds or DEFAULT_CLAUDE_RATE_LIMIT_BACKOFF_SECONDS
            write_claude_backoff(home, backoff_seconds, "HTTP 429")
            stale = stale_claude_provider(home)
            if stale:
                return stale
        elif 500 <= exc.code < 600:
            write_claude_backoff(home, DEFAULT_CLAUDE_CACHE_TTL_SECONDS, f"HTTP {exc.code}")
            stale = stale_claude_provider(home)
            if stale:
                return stale
        raise

    write_claude_provider_cache(home, provider)
    clear_claude_backoff(home)
    return provider


def fetch_codex(args: argparse.Namespace) -> dict[str, Any]:
    payload = codex_usage.fetch(args)
    payload = dict(payload)
    payload["ok"] = True
    payload["provider"] = "codex"
    payload["providerLabel"] = "Codex"
    payload["shortLabel"] = "Cx"
    account = dict(payload.get("account") if isinstance(payload.get("account"), dict) else {})
    account["planRaw"] = account.get("plan", "")
    account["plan"] = format_codex_plan(account.get("plan"))
    payload["account"] = account
    payload.setdefault("updatedAt", iso_utc())
    return payload


def error_provider(provider: str, label: str, short_label: str, source: str, error: Exception, local: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "ok": False,
        "provider": provider,
        "providerLabel": label,
        "shortLabel": short_label,
        "source": source,
        "usage": {},
        "credits": {"remaining": -1, "hasCredits": False, "unlimited": False},
        "account": {"email": "", "plan": "", "planRaw": ""},
        "local": local or {},
        "updatedAt": iso_utc(),
        "error": str(error),
        "errors": [str(error)],
    }


def provider_windows(provider: dict[str, Any]) -> list[dict[str, Any]]:
    usage = provider.get("usage") if isinstance(provider.get("usage"), dict) else {}
    windows = []
    for key in ("primary", "secondary", "tertiary"):
        value = usage.get(key)
        if isinstance(value, dict):
            windows.append(value)
    extra = usage.get("extraRateWindows")
    if isinstance(extra, list):
        windows.extend(value for value in extra if isinstance(value, dict))
    return windows


def provider_score(provider: dict[str, Any]) -> float:
    if not provider.get("ok"):
        return -1.0
    windows = provider_windows(provider)
    if not windows:
        return -1.0
    return max(parse_float(window.get("usedPercent"), -1) for window in windows)


def choose_active(providers: list[dict[str, Any]], mode: str) -> dict[str, Any] | None:
    ok_providers = [provider for provider in providers if provider.get("ok")]
    if mode in ("codex", "claude"):
        for provider in ok_providers:
            if provider.get("provider") == mode:
                return provider
    if ok_providers:
        return max(ok_providers, key=provider_score)
    return providers[0] if providers else None


def aggregate_response(providers: list[dict[str, Any]], mode: str, errors: list[str]) -> dict[str, Any]:
    active = choose_active(providers, mode)
    ok = any(provider.get("ok") for provider in providers)
    payload: dict[str, Any] = {
        "ok": ok,
        "updatedAt": iso_utc(),
        "providers": providers,
        "activeProvider": active or {},
        "errors": errors,
    }
    if active:
        for key in (
            "provider",
            "providerLabel",
            "shortLabel",
            "source",
            "usage",
            "credits",
            "account",
            "local",
            "updatedAt",
            "error",
        ):
            if key in active:
                payload[key] = active[key]
    if not ok:
        payload["error"] = "; ".join(errors) if errors else "No provider usage available."
    return payload


def fetch(args: argparse.Namespace) -> dict[str, Any]:
    provider_ids = [args.provider_mode] if args.provider_mode in ("codex", "claude") else ["codex", "claude"]
    providers: list[dict[str, Any]] = []
    errors: list[str] = []

    for provider_id in provider_ids:
        if provider_id == "codex":
            try:
                providers.append(fetch_codex(args))
            except Exception as exc:
                errors.append(f"Codex: {exc}")
                providers.append(error_provider("codex", "Codex", "Cx", args.source, exc))
        elif provider_id == "claude":
            try:
                providers.append(fetch_claude(args))
            except Exception as exc:
                errors.append(f"Claude Code: {exc}")
                try:
                    local = claude_local_stats(claude_home(args.claude_home))
                except Exception:
                    local = {}
                providers.append(error_provider("claude", "Claude Code", "Cl", args.claude_source, exc, local=local))

    return aggregate_response(providers, args.provider_mode, errors)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch model usage for Noctalia ModelBar.")
    parser.add_argument("--provider-mode", choices=("auto", "codex", "claude"), default="auto")
    parser.add_argument("--source", choices=("auto", "oauth", "cli"), default="auto", help="Codex source")
    parser.add_argument("--claude-source", choices=("auto", "oauth"), default="auto")
    parser.add_argument("--codex-bin", default="codex")
    parser.add_argument("--codex-home", default="")
    parser.add_argument("--claude-bin", default="claude")
    parser.add_argument("--claude-home", default="")
    parser.add_argument("--timeout", type=float, default=8)
    parser.add_argument("--claude-cache-ttl", type=int, default=DEFAULT_CLAUDE_CACHE_TTL_SECONDS)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    payload = fetch(args)
    print(json.dumps(payload, separators=(",", ":")))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
