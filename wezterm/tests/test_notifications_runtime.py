"""Run state/navigation tests with WezTerm's real Lua and GLOBAL implementation."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WEZTERM = shutil.which("wezterm")


@unittest.skipUnless(WEZTERM, "WezTerm is not installed")
class WezTermRuntimeTests(unittest.TestCase):
    def test_notification_lifecycle_in_native_runtime(self):
        with tempfile.TemporaryDirectory(prefix="wezterm-notification-test-") as folder:
            report = Path(folder) / "result.json"
            config = Path(folder) / "verify.lua"
            config.write_text(
                'local w = require("wezterm")\n'
                'local ok, result = pcall(dofile, "wezterm/tests/notifications.lua")\n'
                f'local f = assert(io.open({json.dumps(str(report))}, "w"))\n'
                'f:write(w.json_encode({passed=ok, error=ok and "" or tostring(result)}))\n'
                'f:close()\n'
                'return {}\n'
            )
            result = subprocess.run(
                [WEZTERM, "--config-file", str(config), "show-keys", "--lua"],
                cwd=ROOT, capture_output=True, text=True, timeout=15,
            )
            self.assertTrue(report.exists(), result.stderr)
            data = json.loads(report.read_text())
            self.assertTrue(data["passed"], data["error"])
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
