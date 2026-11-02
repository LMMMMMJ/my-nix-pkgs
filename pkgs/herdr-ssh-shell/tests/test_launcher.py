"""Run the phone's real installer without touching an actual user's home."""

import json
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

SHELL, FISH, INSTALLER, BASH = sys.argv[1:]
INSTALL_COMMAND = Path(INSTALLER).read_text()
sys.argv[1:] = []


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="herdrchat tests ' ")
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.env = {
            "HOME": str(self.home),
            "USER": "alice",
            "PATH": "/usr/bin:/bin",
            "XDG_CONFIG_HOME": str(self.home / "config"),
            "XDG_DATA_HOME": str(self.home / "data"),
            "SSH_CONNECTION": "127.0.0.1 12345 127.0.0.1 22",
        }
        self.bin = self.home / ".local/bin"
        self.real = self.home / ".local/share/pnpm/codex"
        self.real.parent.mkdir(parents=True)
        self.real.write_text(
            f"#!{sys.executable}\nimport json, sys\n"
            "print(json.dumps(sys.argv[1:]))\n"
        )
        self.real.chmod(0o755)

    def run_command(self, command, *, shell=SHELL, env=None):
        return subprocess.run(
            [shell, "-c", command],
            env=env or self.env,
            text=True,
            capture_output=True,
            timeout=15,
        )

    def install(self):
        result = self.run_command(INSTALL_COMMAND)
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ("codex", "herdrchat-codex"):
            target = self.bin / name
            self.assertTrue(target.is_file())
            self.assertEqual(target.stat().st_mode & 0o777, 0o700)
            self.assertIn("# herdrchat-managed-codex-launcher-v1", target.read_text())

    def launch(self, name="codex", arguments=""):
        # The Nix build sandbox has no /usr/bin/env. The VM test separately
        # executes the shebang and command discovery through a real SSH login.
        return self.run_command(
            f'{shlex.quote(BASH)} "$HOME/.local/bin/{name}" {arguments}'
        )

    def test_reproduces_fish_failure_before_any_write(self):
        result = self.run_command(INSTALL_COMMAND, shell=FISH)
        self.assertEqual(result.returncode, 127)
        self.assertFalse(self.bin.exists())

    def test_real_installer_is_repeatable(self):
        self.install()
        original = (self.bin / "codex").read_bytes()
        self.install()
        self.assertEqual((self.bin / "codex").read_bytes(), original)
        self.assertEqual(list(self.bin.glob(".herdrchat-codex.*")), [])

    def test_keeps_an_unrelated_launcher(self):
        self.bin.mkdir(parents=True)
        target = self.bin / "codex"
        target.write_text("user-owned launcher\n")
        result = self.run_command(INSTALL_COMMAND)
        self.assertEqual(result.returncode, 47)
        self.assertEqual(target.read_text(), "user-owned launcher\n")
        self.assertFalse((self.bin / "herdrchat-codex").exists())

    def test_finds_pnpm_codex_without_fish_configuration(self):
        self.install()
        result = self.launch(arguments="--sandbox read-only -a never")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), ["--sandbox", "read-only", "-a", "never"])

    def test_pane_context_and_arguments_are_quoted(self):
        self.install()
        socket = '/tmp/"$(touch INJECTED)"/herdr.sock'
        self.env.update(
            HERDR_ENV="1", HERDR_PANE_ID="w1:p2", HERDR_SOCKET_PATH=socket
        )
        result = self.launch("herdrchat-codex", "resume 'session with spaces' -a never")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), [
            "-c", "features.hooks=true",
            "-c", 'shell_environment_policy.set.HERDR_ENV="1"',
            "-c", 'shell_environment_policy.set.HERDR_PANE_ID="w1:p2"',
            "-c", f"shell_environment_policy.set.HERDR_SOCKET_PATH={json.dumps(socket)}",
            "resume", "session with spaces", "-a", "never",
        ])

    def test_explicit_launcher_requires_a_pane(self):
        self.install()
        result = self.launch("herdrchat-codex")
        self.assertEqual(result.returncode, 1)
        self.assertIn("inside the Herdr pane", result.stderr)

    def test_command_and_exit_status_are_unchanged(self):
        result = self.run_command("value='literal $HOME'; printf '%s' \"$value\"; exit 42")
        self.assertEqual(result.stdout, "literal $HOME")
        self.assertEqual(result.returncode, 42)

    def test_custom_pnpm_home(self):
        alternate = self.home / "custom pnpm"
        alternate.mkdir()
        self.real.rename(alternate / "codex")
        self.env["PNPM_HOME"] = str(alternate)
        result = self.run_command("codex --version")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), ["--version"])

    def test_local_commands_still_use_fish(self):
        env = self.env.copy()
        env.pop("SSH_CONNECTION")
        result = self.run_command("set answer 42; printf '%s' $answer", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "42")


unittest.main(verbosity=2)
