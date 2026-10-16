"""Ensure access diagnostics never include exception data or request fields."""

import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "diagnose_access", Path(__file__).with_name("diagnose-access.py"),
)
diagnostics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostics)


class AccessDiagnosticsTest(unittest.TestCase):
    def test_only_frames_and_exception_classes_are_emitted(self):
        self.assertEqual(diagnostics.summarize_error({
            "exception": 'File "/app/source.py", line 42, in mapping\nValueError: secret@example.com sensitive-token',
            "request": "/callback?code=sensitive-code",
            "user": "secret@example.com",
        }), ["/app/source.py:42 in mapping", "ValueError"])

    def test_normal_requests_are_not_emitted(self):
        self.assertEqual(diagnostics.summarize_error({"request": "/callback?code=secret"}), [])


if __name__ == "__main__":
    unittest.main()
