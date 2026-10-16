"""Credential-free regressions for the live custom-flow verifier."""

import importlib.util
import io
import json
import ssl
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "verify_authentication", Path(__file__).with_name("verify-authentication.py")
)
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class Response(io.BytesIO):
    status = 200

    def __init__(self, value):
        super().__init__(json.dumps(value).encode())


class Client:
    def __init__(self, password_result):
        self.results = iter([
            {"component": "ak-stage-identification"},
            {"component": "ak-stage-password"},
            password_result,
            {},
        ])
        self.requests = []

    def open(self, request, timeout):
        self.requests.append(request)
        return Response(next(self.results))


class PasswordFlowTests(unittest.TestCase):
    def execute(self, result):
        client = Client(result)
        with patch.object(verifier.urllib.request, "build_opener", return_value=client):
            with redirect_stdout(io.StringIO()):
                verifier.verify_password_flow(ssl.create_default_context())
        return client

    def test_redirect_component_checks_authenticated_session(self):
        client = self.execute({"component": "xak-flow-redirect", "type": "native"})
        self.assertTrue(client.requests[-1].full_url.endswith("/core/users/me/"))
        self.assertFalse(client.requests[-1].has_header("Authorization"))

    def test_redirect_type_checks_authenticated_session(self):
        client = self.execute({"type": "redirect"})
        self.assertTrue(client.requests[-1].full_url.endswith("/core/users/me/"))

    def test_password_rejection_is_not_success(self):
        with self.assertRaisesRegex(ValueError, "rejected"):
            self.execute({"component": "ak-stage-password"})

    def test_mfa_requirement_is_not_success(self):
        with self.assertRaisesRegex(ValueError, "MFA"):
            self.execute({"component": "ak-stage-authenticator-validate"})


if __name__ == "__main__":
    unittest.main()
