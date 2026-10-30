"""Helpers for deciding when Authentik has finished bootstrapping its defaults."""

DEFAULT_SCOPE_MAPPINGS = frozenset({
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-entitlements",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
})


def missing_default_scope_mappings(mappings):
    available = {mapping.get("managed") for mapping in mappings}
    return DEFAULT_SCOPE_MAPPINGS - available
