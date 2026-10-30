"""Verify revocation commands use the guarded configuration apply."""

from pathlib import Path
import subprocess
import tempfile
import unittest


class ApplicationAccessCommandTests(unittest.TestCase):
    def run_command(self, *args):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = Path(__file__).with_name("set-application-access.sh")
            (root / script.name).write_text(script.read_text())
            (root / "shared.sh").write_text(
                'require_local_cluster() { echo ownership; }\n'
                'start_admin_forward() { echo forward; }\n'
                'apply_local_config() { printf "apply %s\\n" "$@"; }\n'
            )
            return subprocess.run(
                ["bash", str(root / script.name), *args],
                capture_output=True, text=True,
            )

    def test_revoke_and_restore_use_guarded_apply(self):
        for action, expected in (("revoke", "true"), ("restore", "false")):
            with self.subTest(action=action):
                result = self.run_command(action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), [
                    "ownership", "forward",
                    f"apply -var=revoke_application_access={expected}",
                ])

    def test_invalid_arguments_never_touch_the_cluster(self):
        for args in ((), ("invalid",), ("revoke", "extra")):
            with self.subTest(args=args):
                result = self.run_command(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertIn("Usage:", result.stderr)
