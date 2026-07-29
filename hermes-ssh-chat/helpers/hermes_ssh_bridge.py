#!/usr/bin/env python3
import json
import os
import pty
import select
import signal
import subprocess
import sys
import termios
import threading
import time
from queue import Empty, Queue


ANSI_RE_TEXT = "\x1b[@-_][0-?]*[ -/]*[@-~]|\x1b\\][^\a]*(?:\a|\x1b\\\\)"


def emit(message):
    sys.stdout.write(json.dumps(message, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def decode_output(data):
    return data.decode("utf-8", errors="replace")


def strip_ansi(text):
    import re

    return re.sub(ANSI_RE_TEXT, "", text)


def stdin_reader(queue):
    for line in sys.stdin:
        try:
            queue.put(json.loads(line))
        except json.JSONDecodeError as exc:
            emit({"type": "error", "message": f"invalid json command: {exc}"})


def set_winsize(fd, rows=32, cols=120):
    try:
        import fcntl
        import struct

        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    except Exception:
        pass


class Session:
    def __init__(self):
        self.master_fd = None
        self.proc = None
        self.password = ""
        self.password_sent = False
        self.last_password_prompt = 0.0

    def start(self, command, rows=32, cols=120):
        self.stop()
        self.master_fd, slave_fd = pty.openpty()
        set_winsize(self.master_fd, rows, cols)

        env = os.environ.copy()
        env.setdefault("TERM", "xterm-256color")
        env.setdefault("COLORTERM", "truecolor")

        self.proc = subprocess.Popen(
            command,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            close_fds=True,
            start_new_session=True,
            env=env,
        )
        os.close(slave_fd)

    def resize(self, rows=32, cols=120):
        if self.master_fd is not None:
            set_winsize(self.master_fd, rows, cols)

    def write(self, text):
        if self.master_fd is None:
            return
        os.write(self.master_fd, text.encode("utf-8", errors="replace"))

    def read_ready(self):
        if self.master_fd is None:
            return ""
        try:
            data = os.read(self.master_fd, 4096)
        except OSError:
            return ""
        return decode_output(data)

    def maybe_answer_password(self, text):
        if not self.password or self.password_sent:
            return
        lower = strip_ansi(text).lower()
        if "password:" not in lower:
            return
        now = time.monotonic()
        if now - self.last_password_prompt < 0.3:
            return
        self.last_password_prompt = now
        self.password_sent = True
        self.write(self.password + "\n")

    def stop(self):
        if self.proc and self.proc.poll() is None:
            try:
                os.killpg(self.proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(self.proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                self.proc.wait(timeout=2)

        if self.master_fd is not None:
            try:
                os.close(self.master_fd)
            except OSError:
                pass

        self.master_fd = None
        self.proc = None
        self.password = ""
        self.password_sent = False


def ssh_command(host, port, user):
    return [
        "ssh",
        "-tt",
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        "ServerAliveInterval=30",
        "-p",
        str(port),
        f"{user}@{host}",
        "TERM=xterm-256color COLORTERM=truecolor hermes",
    ]


def main():
    queue = Queue()
    threading.Thread(target=stdin_reader, args=(queue,), daemon=True).start()
    session = Session()

    emit({"type": "status", "status": "idle", "message": "Bridge ready"})

    try:
        while True:
            try:
                while True:
                    command = queue.get_nowait()
                    command_type = command.get("type")

                    if command_type == "connect":
                        host = str(command.get("host", "")).strip()
                        user = str(command.get("user", "")).strip()
                        port = int(command.get("port") or 22)
                        rows = int(command.get("rows") or 32)
                        cols = int(command.get("cols") or 120)

                        if not host or not user:
                            emit({"type": "error", "message": "host and user are required"})
                            continue

                        session.password = str(command.get("password", ""))
                        session.password_sent = False
                        emit(
                            {
                                "type": "status",
                                "status": "connecting",
                                "message": f"Connecting to {user}@{host}",
                            }
                        )
                        session.start(ssh_command(host, port, user), rows, cols)

                    elif command_type == "input":
                        session.write(str(command.get("text", "")))

                    elif command_type == "resize":
                        rows = int(command.get("rows") or 32)
                        cols = int(command.get("cols") or 120)
                        session.resize(rows, cols)

                    elif command_type == "disconnect":
                        session.stop()
                        emit({"type": "exit", "code": 0})
                        return

            except Empty:
                pass

            if session.proc is None:
                time.sleep(0.05)
                continue

            readable, _, _ = select.select([session.master_fd], [], [], 0.05)
            if readable:
                text = session.read_ready()
                if text:
                    session.maybe_answer_password(text)
                    emit({"type": "output", "text": text})
                    if session.proc and session.proc.poll() is None:
                        emit(
                            {
                                "type": "status",
                                "status": "connected",
                                "message": "Connected",
                            }
                        )

            code = session.proc.poll()
            if code is not None:
                emit({"type": "exit", "code": code})
                session.stop()
                return

    except KeyboardInterrupt:
        pass
    finally:
        session.stop()


if __name__ == "__main__":
    main()
