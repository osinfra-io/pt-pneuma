"""Helpers for deciding when Authentik has finished bootstrapping its defaults."""

DEFAULT_SCOPE_MAPPINGS = frozenset({
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-entitlements",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/proxy/scope-proxy",
})

DEFAULT_FLOWS = frozenset({
    "default-authentication-flow",
    "default-source-authentication",
})


def missing_default_scope_mappings(mappings):
    available = {mapping.get("managed") for mapping in mappings}
    return DEFAULT_SCOPE_MAPPINGS - available


def missing_default_flows(flows):
    available = {flow.get("slug") for flow in flows}
    return DEFAULT_FLOWS - available
