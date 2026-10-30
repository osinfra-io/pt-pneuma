"""Credential-free tests for Authentik bootstrap readiness."""

import unittest

import bootstrap


class BootstrapTests(unittest.TestCase):
    def test_waits_until_all_builtin_scope_mappings_exist(self):
        mappings = [
            {"managed": "goauthentik.io/providers/oauth2/scope-email"},
            {"managed": "goauthentik.io/providers/oauth2/scope-openid"},
        ]
        self.assertEqual(
            bootstrap.missing_default_scope_mappings(mappings),
            {
                "goauthentik.io/providers/oauth2/scope-entitlements",
                "goauthentik.io/providers/oauth2/scope-profile",
            },
        )

    def test_all_builtin_scope_mappings_allow_configuration(self):
        mappings = [{"managed": identifier} for identifier in bootstrap.DEFAULT_SCOPE_MAPPINGS]
        self.assertEqual(bootstrap.missing_default_scope_mappings(mappings), set())

    def test_unmanaged_and_other_mappings_do_not_satisfy_readiness(self):
        self.assertEqual(
            bootstrap.missing_default_scope_mappings([
                {"managed": None},
                {"managed": "goauthentik.io/providers/oauth2/scope-custom"},
            ]),
            bootstrap.DEFAULT_SCOPE_MAPPINGS,
        )


if __name__ == "__main__":
    unittest.main()
