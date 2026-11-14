"""Verify state ownership checks do not hide errors or lose matches to SIGPIPE."""

from pathlib import Path
import subprocess
import tempfile
import unittest


STATE_HELPER = Path(__file__).with_name("state.sh")


class StateTests(unittest.TestCase):
    def run_check(self, producer, address, state="existing", workspace="default"):
        with tempfile.TemporaryDirectory() as temporary:
            work_dir = Path(temporary)
            state_file = work_dir / "routing.tfstate"
            if state == "existing":
                state_file.touch()
            elif state == "dangling":
                state_file.symlink_to(work_dir / "missing")
            return subprocess.run(
                ["bash", "-o", "pipefail", "-c",
                 f'WORK_DIR="$3"; MOCK_WORKSPACE="$4"; tofu_stage() {{ '
                 f'if [ "$2" = workspace ]; then '
                 f'[ "$MOCK_WORKSPACE" != error ] || return 1; echo "$MOCK_WORKSPACE"; else {producer}; fi; '
                 f'}}; source "$1"; '
                 'if state_has routing "$2"; then echo found; else echo absent; fi',
                 "test", str(STATE_HELPER), address, str(work_dir), workspace],
                text=True, capture_output=True, check=False,
            )

    def test_finds_early_match_in_large_state(self):
        result = self.run_check(
            'echo module.example; for i in {1..10000}; do echo "module.other$i"; done',
            "module.example",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "found")

    def test_missing_address_is_not_a_match(self):
        result = self.run_check('echo module.other', "module.example")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "absent")

    def test_fresh_backend_is_a_non_match_without_reading_state(self):
        result = self.run_check('echo unexpected >&2; return 1', "module.example", state="absent")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "absent")
        self.assertNotIn("unexpected", result.stderr)

    def test_state_read_failure_stops_with_diagnostic(self):
        result = self.run_check('echo "state unavailable" >&2; return 1', "module.example")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("state unavailable", result.stderr)
        self.assertIn("refusing", result.stderr)

    def test_dangling_state_symlink_is_not_treated_as_fresh(self):
        result = self.run_check('echo "state unavailable" >&2; return 1', "module.example", state="dangling")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing", result.stderr)

    def test_non_default_workspace_is_rejected_even_without_default_state(self):
        for state in ("absent", "existing"):
            with self.subTest(state=state):
                result = self.run_check(
                    'echo unexpected >&2; return 1', "module.example",
                    state=state, workspace="other",
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Non-default", result.stderr)
                self.assertNotIn("unexpected", result.stderr)

    def test_workspace_read_failure_is_fatal(self):
        result = self.run_check('echo unexpected >&2', "module.example", state="absent", workspace="error")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not determine", result.stderr)
        self.assertNotIn("unexpected", result.stderr)


if __name__ == "__main__":
    unittest.main()
