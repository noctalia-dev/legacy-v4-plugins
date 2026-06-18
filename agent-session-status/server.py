#!/usr/bin/env python3
import argparse
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse


VALID_STATUSES = {"running", "completed", "blocked"}
PROTOCOL_VERSION = "2025-06-18"
USAGE_INSTRUCTIONS = """Use this MCP server to publish your current agent session state to the Noctalia bar and panel.

Call report_session when you start work, when your state changes, and before you finish. Use the same id for the same task so later calls update the existing in-memory session instead of creating duplicates.

Use status values this way:
- running: you are actively working or waiting on a command that is part of the task.
- blocked: you need user input, approval, or an external dependency before you can continue.
- completed: the task is finished or you are no longer actively working on it.

The MCP client must send Authorization: Bearer <token> and X-Agent: <agent-name> headers. X-Agent is the display group name in the Noctalia panel, for example codex or claude."""


class ValidationError(Exception):
    pass


class SessionStore:
    def __init__(self):
        self._sessions = {}

    def upsert(self, agent, payload):
        agent = str(agent or "").strip()
        if not agent:
            raise ValidationError("X-Agent header is required")

        session_id = str(payload.get("id", "")).strip()
        if not session_id:
            raise ValidationError("session id is required")

        status = str(payload.get("status", "")).strip()
        if status not in VALID_STATUSES:
            raise ValidationError("status must be running, completed, or blocked")

        title = str(payload.get("title", "")).strip() or session_id
        now = int(time.time())
        key = (agent, session_id)
        created_at = self._sessions.get(key, {}).get("createdAt", now)
        entry = {
            "id": session_id,
            "agent": agent,
            "title": title,
            "status": status,
            "createdAt": created_at,
            "updatedAt": now,
        }
        self._sessions[key] = entry
        return dict(entry)

    def snapshot(self):
        return self.snapshot_for_agent()

    def prune_inactive(self):
        before = len(self._sessions)
        self._sessions = {
            key: entry
            for key, entry in self._sessions.items()
            if entry["status"] == "running"
        }
        return before - len(self._sessions)

    def snapshot_for_agent(self, agent=None):
        grouped = {}
        running_count = 0

        for entry in self._sessions.values():
            if agent is not None and entry["agent"] != agent:
                continue
            if entry["status"] == "running":
                running_count += 1
            grouped.setdefault(entry["agent"], []).append(dict(entry))

        agents = []
        for agent in sorted(grouped.keys(), key=lambda name: (
            not any(item["status"] == "running" for item in grouped[name]),
            -max(item["updatedAt"] for item in grouped[name]),
            name.lower(),
        )):
            sessions = sorted(
                grouped[agent],
                key=lambda item: (item["status"] != "running", -item["updatedAt"]),
            )
            agents.append({
                "agent": agent,
                "runningCount": sum(1 for item in sessions if item["status"] == "running"),
                "sessions": sessions,
            })

        return {
            "runningCount": running_count,
            "agents": agents,
            "updatedAt": int(time.time()),
        }


def _json_response(status, body):
    return status, {"Content-Type": "application/json"}, body


def _authorized(headers, token):
    if not token:
        return False
    return headers.get("Authorization", "") == "Bearer " + token


def _rpc_result(request_id, result):
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "result": result,
    }


def _rpc_error(request_id, code, message):
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {
            "code": code,
            "message": message,
        },
    }


def _text_tool_result(payload):
    return {
        "content": [
            {
                "type": "text",
                "text": json.dumps(payload, separators=(",", ":")),
            }
        ],
        "isError": False,
    }


def _session_prompts():
    return [
        {
            "name": "agent-session-reporting",
            "title": "Agent session reporting guide",
            "description": "Instructions for agents that report status to the Noctalia session panel.",
        },
    ]


def _session_tools():
    return [
        {
            "name": "report_session",
            "title": "Report agent session status",
            "description": "Create or update your visible Noctalia session. Call it at task start with running, when blocked with blocked, and at task end with completed. Reuse the same id for the same task. Requires Authorization bearer token and X-Agent headers.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "id": {
                        "type": "string",
                        "description": "Stable id for this task/session. Reuse it for updates.",
                    },
                    "title": {
                        "type": "string",
                        "description": "Short human-readable task title shown in the Noctalia panel.",
                    },
                    "status": {
                        "type": "string",
                        "enum": ["running", "completed", "blocked"],
                        "description": "running while active, blocked when waiting for user/external input, completed when finished.",
                    },
                },
                "required": ["id", "title", "status"],
                "additionalProperties": False,
            },
        },
        {
            "name": "list_sessions",
            "title": "List reported agent sessions",
            "description": "Return only the current X-Agent's in-memory session snapshot. Requires Authorization bearer token and X-Agent headers.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        },
    ]


def _handle_mcp(store, token, headers, raw_body):
    try:
        request = json.loads(raw_body.decode("utf-8") or "{}")
    except json.JSONDecodeError:
        return _rpc_error(None, -32700, "Parse error")

    if not isinstance(request, dict) or request.get("jsonrpc") != "2.0":
        return _rpc_error(request.get("id") if isinstance(request, dict) else None, -32600, "Invalid Request")

    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}

    if method == "notifications/initialized":
        return None

    if method == "initialize":
        return _rpc_result(request_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {
                "prompts": {},
                "tools": {},
            },
            "serverInfo": {
                "name": "agent-session-status",
                "version": "1.0.0",
            },
            "instructions": USAGE_INSTRUCTIONS,
        })

    if method == "prompts/list":
        return _rpc_result(request_id, {"prompts": _session_prompts()})

    if method == "prompts/get":
        name = params.get("name")
        if name != "agent-session-reporting":
            return _rpc_error(request_id, -32602, "Unknown prompt: " + str(name))

        return _rpc_result(request_id, {
            "description": "Instructions for reporting agent session status to Noctalia.",
            "messages": [
                {
                    "role": "user",
                    "content": {
                        "type": "text",
                        "text": USAGE_INSTRUCTIONS,
                    },
                },
            ],
        })

    if method == "tools/list":
        return _rpc_result(request_id, {"tools": _session_tools()})

    if method == "tools/call":
        name = params.get("name")
        arguments = params.get("arguments") or {}

        if name == "list_sessions":
            if not _authorized(headers, token):
                return _rpc_error(request_id, -32001, "Unauthorized")

            agent = headers.get("X-Agent", "").strip()
            if not agent:
                return _rpc_error(request_id, -32602, "X-Agent header is required")

            return _rpc_result(request_id, _text_tool_result(store.snapshot_for_agent(agent)))

        if name == "report_session":
            if not _authorized(headers, token):
                return _rpc_error(request_id, -32001, "Unauthorized")

            agent = headers.get("X-Agent", "").strip()
            if not agent:
                return _rpc_error(request_id, -32602, "X-Agent header is required")

            try:
                session = store.upsert(agent, arguments)
            except ValidationError as error:
                return _rpc_error(request_id, -32602, str(error))

            return _rpc_result(request_id, _text_tool_result({
                "session": session,
                "snapshot": store.snapshot_for_agent(agent),
            }))

        return _rpc_error(request_id, -32602, "Unknown tool: " + str(name))

    return _rpc_error(request_id, -32601, "Method not found")


def handle_request(store, token, method, path, headers=None, raw_body=b""):
    headers = headers or {}
    parsed_path = urlparse(path).path

    if method == "GET" and parsed_path == "/health":
        return _json_response(200, {"ok": True})

    if method == "GET" and parsed_path == "/sessions":
        return _json_response(200, store.snapshot())

    if method == "POST" and parsed_path == "/sessions/prune-inactive":
        if not _authorized(headers, token):
            return _json_response(401, {"error": "unauthorized"})

        removed = store.prune_inactive()
        return _json_response(200, {
            "removed": removed,
            "snapshot": store.snapshot(),
        })

    if method == "GET" and parsed_path == "/mcp":
        return _json_response(405, {"error": "SSE streaming is not supported"})

    if method == "POST" and parsed_path == "/mcp":
        response = _handle_mcp(store, token, headers, raw_body)
        if response is None:
            return 202, {"Content-Type": "application/json"}, {}
        return _json_response(200, response)

    return _json_response(404, {"error": "not found"})


class SessionRequestHandler(BaseHTTPRequestHandler):
    server_version = "AgentSessionStatus/1.0"

    def _dispatch(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw_body = self.rfile.read(length) if length > 0 else b""
        status, headers, body = handle_request(
            self.server.store,
            self.server.auth_token,
            self.command,
            self.path,
            self.headers,
            raw_body,
        )
        encoded = json.dumps(body, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        for name, value in headers.items():
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        self._dispatch()

    def do_POST(self):
        self._dispatch()

    def log_message(self, fmt, *args):
        sys.stderr.write("agent-session-status: " + fmt % args + "\n")


class SessionServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, server_address, handler_class, auth_token):
        super().__init__(server_address, handler_class)
        self.store = SessionStore()
        self.auth_token = auth_token


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=55854)
    parser.add_argument("--token", required=True)
    return parser.parse_args()


def main():
    args = parse_args()
    httpd = SessionServer((args.host, args.port), SessionRequestHandler, args.token)
    print("agent-session-status listening on %s:%d" % (args.host, args.port), flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
