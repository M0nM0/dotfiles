"""Transport and agent adapter checks. No live notifications or LLM calls."""
import base64
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SENDER = ROOT / "wezterm/bin/term-notify"
loader = importlib.machinery.SourceFileLoader("term_notify", str(ROOT / "wezterm/utils/term-notify.py"))
spec = importlib.util.spec_from_loader(loader.name, loader)
sender = importlib.util.module_from_spec(spec)
loader.exec_module(sender)


def decode(data):
    prefix = b"\x1b]1337;SetUserVar=term_notify="
    assert data.startswith(prefix) and data.endswith(b"\x07"), repr(data)
    return json.loads(base64.b64decode(data[len(prefix):-1]))


class TransportTests(unittest.TestCase):
    def test_round_trip_and_control_sanitizing(self):
        message = decode(sender.sequence('日本語 "title"', "hello\x07\x1b\nworld", "wezterm"))
        self.assertEqual(message["title"], '日本語 "title"')
        self.assertNotIn("\x07", message["body"])
        self.assertNotIn("\x1b", message["body"])
        self.assertEqual(message["op"], "notify")
        self.assertNotEqual(message["id"], decode(sender.sequence("a", "b", "wezterm"))["id"])

    def test_clear_and_limits(self):
        message = decode(sender.sequence("a" * 200, "b" * 2000, "wezterm", True))
        self.assertEqual(message["op"], "clear")
        self.assertEqual(len(message["title"]), 120)
        self.assertEqual(len(message["body"]), 1000)

    def test_detached_hook_targets_outer_wezterm_even_in_tmux(self):
        with patch.dict(os.environ, {"WEZTERM_PANE": "12", "TMUX": "test", "TMUX_PANE": "%3"}, clear=True):
            with patch.object(sender, "run", return_value=json.dumps([{"pane_id": 12, "tty_name": "/dev/pts/7"}])) as run:
                self.assertEqual(sender.terminal_target(), ("/dev/pts/7", False))
                self.assertIn("--no-auto-start", run.call_args.args[0])

    def test_stale_pane_does_not_fall_back_to_wrong_tty(self):
        with patch.dict(os.environ, {"WEZTERM_PANE": "12"}, clear=True):
            with patch.object(sender, "run", return_value="[]"):
                with self.assertRaises(OSError):
                    sender.terminal_target()

    def test_dead_socket_is_removed_only_for_cli_discovery(self):
        with patch.dict(os.environ, {"WEZTERM_PANE": "12", "WEZTERM_UNIX_SOCKET": "/nonexistent/old-wezterm.sock"}, clear=True):
            with patch.object(sender, "run", return_value='[{"pane_id":12,"tty_name":"/dev/pts/7"}]') as run:
                self.assertEqual(sender.terminal_target(), ("/dev/pts/7", False))
                self.assertNotIn("WEZTERM_UNIX_SOCKET", run.call_args.kwargs["env"])
                self.assertIn("WEZTERM_UNIX_SOCKET", os.environ)

    def test_existing_socket_keeps_its_explicit_connection(self):
        with patch.dict(os.environ, {"WEZTERM_PANE": "12", "WEZTERM_UNIX_SOCKET": "/current/gui.sock"}, clear=True):
            with patch.object(sender.Path, "exists", return_value=True):
                with patch.object(sender, "run", return_value='[{"pane_id":12,"tty_name":"/dev/pts/7"}]') as run:
                    self.assertEqual(sender.terminal_target(), ("/dev/pts/7", False))
                    self.assertIsNone(run.call_args.kwargs["env"])

    def test_ssh_does_not_resolve_local_pane_ids(self):
        with patch.dict(os.environ, {"WEZTERM_PANE": "12", "SSH_CONNECTION": "remote", "TERM_NOTIFY_TTY": "/dev/pts/4"}, clear=True):
            with patch.object(sender, "run") as run:
                self.assertEqual(sender.terminal_target(), ("/dev/pts/4", False))
                run.assert_not_called()

    def test_actual_pty_write_without_controlling_terminal(self):
        master, slave = pty.openpty()
        try:
            result = subprocess.run([str(SENDER), "--backend", "wezterm", "--tty", os.ttyname(slave), "--title", "Build", "完了"],
                                    capture_output=True, env={"PATH": os.environ["PATH"]}, start_new_session=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(select.select([master], [], [], 1)[0])
            self.assertEqual(decode(os.read(master, 8192))["body"], "完了")
            self.assertEqual(result.stdout, b"")
        finally:
            os.close(master)
            os.close(slave)

    def test_refuses_regular_file_without_truncating(self):
        with tempfile.NamedTemporaryFile() as target:
            target.write(b"untouched")
            target.flush()
            result = subprocess.run([str(SENDER), "--backend", "wezterm", "--tty", target.name], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(Path(target.name).read_bytes(), b"untouched")

    def test_other_terminals_use_osc_without_launching_notification_apps(self):
        result = subprocess.run([str(SENDER), "--stdout", "--title", "Build;test", "hello;world"],
                                capture_output=True, env={"PATH": os.environ["PATH"]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b"\x1b]777;notify;Build,test;hello,world\x07")


class AgentFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.log = self.directory / "notifications"
        binary = self.directory / "wezterm/bin/term-notify"
        binary.parent.mkdir(parents=True)
        binary.write_text('#!/bin/bash\nprintf "%s\\n" "$@" >> "$NOTIFY_TEST_LOG"\n')
        binary.chmod(0o755)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.directory), NOTIFY_TEST_LOG=str(self.log),
                        WEZTERM_PANE="12", STOP_GUARD_INNER="")


class ClaudeTests(AgentFixture):
    def notify(self, payload):
        return subprocess.run([str(ROOT / "claude/hooks/notify.sh")], input=json.dumps(payload),
                              capture_output=True, text=True, env=self.env, cwd=self.directory)

    def test_main_completion_and_background_work(self):
        result = self.notify({"hook_event_name": "Stop", "background_tasks": [{"id": "running"}]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Background work still running", self.log.read_text())

    def test_completion_includes_final_response_preview(self):
        self.notify({"hook_event_name": "Stop", "last_assistant_message": '通知を修正しました。\nテスト15件を確認。 "quoted"'})
        text = self.log.read_text()
        self.assertIn('通知を修正しました。 テスト15件を確認。 "quoted"', text)
        self.assertNotIn("Response finished", text)

    def test_permission_uses_actual_notification_message(self):
        self.notify({"hook_event_name": "Notification", "notification_type": "permission_prompt",
                     "message": "Permission required to run tests"})
        self.assertIn("Permission required to run tests", self.log.read_text())

    def test_prompt_clears_without_notifying(self):
        self.notify({"hook_event_name": "UserPromptSubmit"})
        self.assertEqual(self.log.read_text(), "--clear\n")

    def test_inner_guard_and_subagent_stay_silent(self):
        self.notify({"hook_event_name": "Stop", "agent_id": "subagent"})
        self.notify({"hook_event_name": "UserPromptSubmit", "agent_id": "subagent"})
        self.env["STOP_GUARD_INNER"] = "1"
        self.notify({"hook_event_name": "Stop"})
        self.assertFalse(self.log.exists())

    def test_stop_guard_blocks_notification_and_preserves_output(self):
        wrapper = self.directory / "stop-and-notify.sh"
        wrapper.write_bytes((ROOT / "claude/hooks/stop-and-notify.sh").read_bytes())
        wrapper.chmod(0o755)
        guard = self.directory / "stop-guard.sh"
        guard.write_text('#!/bin/bash\ncat >/dev/null\nprintf \'{"decision":"block","reason":"continue"}\\n\'\n')
        guard.chmod(0o755)
        notify = self.directory / "notify.sh"
        notify.write_text('#!/bin/bash\necho notified >> "$NOTIFY_TEST_LOG"\n')
        notify.chmod(0o755)
        result = subprocess.run([str(wrapper)], input='{"hook_event_name":"Stop"}', text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["decision"], "block")
        self.assertFalse(self.log.exists())
        guard.write_text('#!/bin/bash\ncat >/dev/null\nexit 0\n')
        result = subprocess.run([str(wrapper)], input='{"hook_event_name":"Stop"}', text=True, capture_output=True, env=self.env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "notified\n")


class CodexTests(AgentFixture):
    def notify(self, payload):
        return subprocess.run(["/bin/bash", str(ROOT / "codex/notify.sh"), json.dumps(payload)],
                              capture_output=True, text=True, env=self.env, cwd=self.directory)

    def test_turn_completion_preview(self):
        result = self.notify({"type": "agent-turn-complete", "cwd": str(self.directory),
                              "last-assistant-message": "Codexの通知を追加しました。\nテスト成功。"})
        self.assertEqual(result.returncode, 0, result.stderr)
        text = self.log.read_text()
        self.assertIn("Codex", text)
        self.assertIn("Codexの通知を追加しました。 テスト成功。", text)

    def test_unknown_events_stay_silent(self):
        result = self.notify({"type": "approval-requested"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.log.exists())

    def test_config_preserves_computer_use_wrapper(self):
        line = next(line for line in (ROOT / "codex/config.toml").read_text().splitlines() if line.startswith("notify = "))
        command = json.loads(line.split("=", 1)[1])
        self.assertTrue(command[0].endswith("/SkyComputerUseClient"))
        self.assertEqual(command[1:3], ["turn-ended", "--previous-notify"])
        previous = json.loads(command[3])
        self.assertEqual(previous, ["/bin/bash", str(ROOT / "codex/notify.sh")])

    def test_codex_event_reaches_shared_transport(self):
        binary = self.directory / "wezterm/bin/term-notify"
        binary.write_bytes(SENDER.read_bytes())
        utility = self.directory / "wezterm/utils/term-notify.py"
        utility.parent.mkdir()
        utility.write_bytes((ROOT / "wezterm/utils/term-notify.py").read_bytes())
        master, slave = pty.openpty()
        try:
            self.env.pop("WEZTERM_PANE", None)
            self.env["TERM_PROGRAM"] = "WezTerm"
            self.env["TERM_NOTIFY_TTY"] = os.ttyname(slave)
            result = self.notify({"type": "agent-turn-complete", "cwd": str(self.directory),
                                  "last-assistant-message": "完了内容を表示します。"})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(select.select([master], [], [], 1)[0])
            message = decode(os.read(master, 8192))
            self.assertEqual(message["title"], "Codex")
            self.assertIn("完了内容を表示します。", message["body"])
            self.assertEqual(message["op"], "notify")
        finally:
            os.close(master)
            os.close(slave)


if __name__ == "__main__":
    unittest.main()
