"""Verify state ownership checks do not hide errors or lose matches to SIGPIPE."""

from pathlib import Path
import subprocess
import unittest


STATE_HELPER = Path(__file__).with_name("state.sh")


class StateTests(unittest.TestCase):
    def run_check(self, producer, address):
        return subprocess.run(
            ["bash", "-o", "pipefail", "-c",
             f'tofu_stage() {{ {producer}; }}; source "$1"; state_has routing "$2"',
             "test", str(STATE_HELPER), address],
            text=True, capture_output=True, check=False,
        )

    def test_finds_early_match_in_large_state(self):
        result = self.run_check(
            'echo module.example; for i in {1..10000}; do echo "module.other$i"; done',
            "module.example",
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_address_is_not_a_match(self):
        self.assertEqual(self.run_check('echo module.other', "module.example").returncode, 1)

    def test_state_read_failure_stops_with_diagnostic(self):
        result = self.run_check('echo "state unavailable" >&2; return 1', "module.example")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("state unavailable", result.stderr)
        self.assertIn("refusing", result.stderr)


if __name__ == "__main__":
    unittest.main()
