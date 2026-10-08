#!/usr/bin/env python3
"""Check that the production header resource retains ownership of shared rendering."""

from pathlib import Path


fixture = Path(__file__).resolve().parent
production = (fixture / "../../manifests/main.tofu").resolve().read_text()
resource = production.split(
    'resource "kubernetes_manifest" "gateway_authentik_inbound_header_strip_filter" {',
    1,
)[1].split('\nresource "', 1)[0]

assert "manifest = module.gateway_auth[each.key].inbound_header_strip_filter_manifest" in resource
assert "for_each = local.gateway_clusters" in resource
assert "provider = kubernetes.by_cluster[each.key]" in resource

print("Header stripping uses shared rendering with unchanged resource ownership.")
