#!/usr/bin/env python3
"""Send a notification to the originating terminal, including from detached hooks."""

import argparse
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid


def clean(text, limit):
    return " ".join("".join(c for c in text if c >= " " and c != "\x7f").split())[:limit]


def run(args, env=None):
    return subprocess.run(args, capture_output=True, text=True, timeout=3, check=True, env=env).stdout


def terminal_target(explicit=None, pane_id=None):
    """Return (tty, tmux passthrough). Never write escape sequences to stdin."""
    if explicit:
        return explicit, bool(os.environ.get("TMUX"))
    # Claude hooks have no controlling terminal. Resolve their inherited pane ID.
    # Do not use a local pane ID across SSH; it belongs to a different machine.
    pane_id = pane_id if pane_id is not None else os.environ.get("WEZTERM_PANE")
    if pane_id is not None and not os.environ.get("SSH_CONNECTION"):
        binary = shutil.which("wezterm")
        mac_binary = "/Applications/WezTerm.app/Contents/MacOS/wezterm"
        binary = binary or (mac_binary if Path(mac_binary).exists() else "wezterm")
        connection_env = None
        socket = os.environ.get("WEZTERM_UNIX_SOCKET")
        if socket and not Path(socket).exists():
            # A persistent multiplexer can retain a socket from an exited GUI.
            # Let the CLI discover the current local GUI, without altering the shell.
            connection_env = dict(os.environ)
            connection_env.pop("WEZTERM_UNIX_SOCKET", None)
        panes = json.loads(run([binary, "cli", "--no-auto-start", "list", "--format", "json"], env=connection_env))
        for pane in panes:
            if str(pane["pane_id"]) == str(pane_id) and pane.get("tty_name"):
                return pane["tty_name"], False
        raise OSError(f"WezTerm pane {pane_id} is no longer available")
    if os.environ.get("TERM_NOTIFY_TTY"):
        return os.environ["TERM_NOTIFY_TTY"], bool(os.environ.get("TMUX"))
    for fd in (1, 2, 0):
        if os.isatty(fd):
            return os.ttyname(fd), bool(os.environ.get("TMUX"))
    # This may work for shell jobs whose standard streams were redirected.
    return "/dev/tty", bool(os.environ.get("TMUX"))


def sequence(title, body, backend, clear=False):
    if backend == "wezterm":
        payload = {"version": 1, "id": str(uuid.uuid4()), "op": "clear" if clear else "notify",
                   "title": clean(title, 120), "body": clean(body, 1000)}
        encoded = base64.b64encode(json.dumps(payload, ensure_ascii=False).encode()).decode()
        return f"\x1b]1337;SetUserVar=term_notify={encoded}\x07".encode()
    if clear:
        return b""
    # OSC 777 has semicolon-delimited fields.
    return f"\x1b]777;notify;{clean(title, 120).replace(';', ',')};{clean(body, 1000).replace(';', ',')}\x07".encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("body", nargs="?", default="Command finished")
    parser.add_argument("--title", default="Terminal")
    parser.add_argument("--backend", choices=("auto", "wezterm", "osc777"), default="auto")
    parser.add_argument("--tty", help="Explicit terminal device (also useful for remote hooks)")
    parser.add_argument("--pane-id", type=int, help="Target a local WezTerm pane instead of WEZTERM_PANE")
    parser.add_argument("--clear", action="store_true", help="Mark this pane's notifications as read")
    parser.add_argument("--stdout", action="store_true", help="Emit the sequence for use in terminal integrations")
    args = parser.parse_args()
    backend = args.backend
    if backend == "auto":
        if args.pane_id is not None or os.environ.get("TERM_PROGRAM") == "WezTerm" or os.environ.get("WEZTERM_PANE"):
            backend = "wezterm"
        else:
            backend = "osc777"
    data = sequence(args.title, args.body, backend, args.clear)
    if args.stdout:
        sys.stdout.buffer.write(data)
        return
    if not data:
        return
    tty, tmux = terminal_target(args.tty, args.pane_id)
    if tmux:
        data = b"\x1bPtmux;" + data.replace(b"\x1b", b"\x1b\x1b") + b"\x1b\\"
    fd = os.open(tty, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        if not os.isatty(fd):
            raise OSError("notification target must be a terminal device")
        while data:
            written = os.write(fd, data)
            if not written:
                raise OSError("terminal closed while sending notification")
            data = data[written:]
    finally:
        os.close(fd)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"term-notify: {error}", file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            print(error.stderr.strip(), file=sys.stderr)
        sys.exit(1)
