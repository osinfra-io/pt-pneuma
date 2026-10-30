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
    def test_token_exchange_errors_are_redacted(self):
        self.assertEqual(diagnostics.summarize_error({
            "event": "Unable to fetch access token",
            "response": '{"error":"invalid_client","error_description":"secret"}',
        }), ["Google token exchange rejected: invalid_client"])
        self.assertEqual(diagnostics.summarize_error({
            "event": "Unable to fetch access token",
            "response": "private@example.com",
        }), ["Unable to fetch access token (non-JSON response omitted)"])

    def test_authentication_failure_reasons_are_allowlisted(self):
        self.assertEqual(diagnostics.summarize_error({
            "event": "Authentication Failure", "reason": "Could not determine id.",
        }), ["Authentication Failure: Could not determine id."])
        self.assertEqual(diagnostics.summarize_error({
            "event": "Authentication Failure", "reason": "private@example.com",
        }), ["Authentication Failure (unrecognized reason omitted)"])

    def test_auth_request_summaries_do_not_include_callback_codes(self):
        self.assertEqual(diagnostics.summarize_record({
            "path": "/source/oauth/callback/google/?code=secret",
            "status": 400,
            "user": "private@example.com",
        }), ["HTTP 400 on /source/oauth/callback/ (remaining path and query omitted)"])

    def test_nested_exception_is_redacted(self):
        self.assertEqual(diagnostics.summarize_record({
            "context": {"exception": "ValueError: private@example.com secret"},
        }), ["ValueError"])

    def test_asgi_event_path_is_redacted(self):
        self.assertEqual(diagnostics.summarize_record({
            "event": "/source/oauth/callback/google/?code=secret",
            "status": 302,
        }), ["HTTP 302 on /source/oauth/callback/ (remaining path and query omitted)"])

    def test_only_frames_and_exception_classes_are_emitted(self):
        self.assertEqual(diagnostics.summarize_error({
            "exception": 'File "/app/source.py", line 42, in mapping\nValueError: secret@example.com sensitive-token',
            "request": "/callback?code=sensitive-code",
            "user": "secret@example.com",
        }), ["/app/source.py:42 in mapping", "ValueError"])

    def test_normal_requests_are_not_emitted(self):
        self.assertEqual(diagnostics.summarize_error({"request": "/callback?code=secret"}), [])

    def test_oauth_rejections_are_reported_without_request_values(self):
        for event in (
            "Invalid grant_type for provider",
            "Missing nonce for OpenID Request",
            "The request is otherwise malformed",
        ):
            with self.subTest(event=event):
                self.assertEqual(diagnostics.summarize_error({
                    "event": event,
                    "grant_type": "secret",
                    "redirect_uri": "/callback?code=secret",
                    "request": "secret",
                }), [event])
        self.assertEqual(diagnostics.summarize_error({
            "event": "sensitive arbitrary event",
        }), [])


if __name__ == "__main__":
    unittest.main()
