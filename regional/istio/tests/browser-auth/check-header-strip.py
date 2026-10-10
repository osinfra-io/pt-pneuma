#!/usr/bin/env python3
"""Check that the production header resource retains ownership of shared rendering."""

from pathlib import Path
import subprocess
import textwrap


fixture = Path(__file__).resolve().parent
production = (fixture / "../../manifests/main.tofu").resolve().read_text()
resource = production.split(
    'resource "kubernetes_manifest" "gateway_authentik_inbound_header_strip_filter" {',
    1,
)[1].split('\nresource "', 1)[0]

assert "manifest = module.gateway_auth[each.key].inbound_header_strip_filter_manifest" in resource
assert "for_each = local.gateway_clusters" in resource
assert "provider = kubernetes.by_cluster[each.key]" in resource

renderer = (fixture / "../../gateway-auth/locals.tofu").resolve().read_text()
strip_filter = renderer.split("inbound_header_strip_filter_manifest = {", 1)[1]
lua = textwrap.dedent(strip_filter.split("inlineCode = <<-EOT\n", 1)[1].split("EOT", 1)[0])
test = """
local headers = {
  ["X-authentik-CSRF"] = "csrf-token",
  ["x-authentik-csrf"] = "second-csrf-token",
  ["X-AUTHENTIK-USERNAME"] = "forged",
  ["x-authentik-groups"] = "forged",
  ["x-authentik-osinfra-google-email"] = "forged",
  ["x-authentik-csrf-extra"] = "forged",
  ["cookie"] = "session-cookie",
  ["authorization"] = "unchanged",
}
local removed = {}
local handle = {}
function handle:headers()
  return setmetatable({}, {
    __pairs = function() return next, headers, nil end,
    __index = {
      remove = function(_, key) removed[key] = true end,
    },
  })
end
envoy_on_request(handle)
assert(not removed["X-authentik-CSRF"])
assert(not removed["x-authentik-csrf"])
assert(not removed["cookie"])
assert(not removed["authorization"])
assert(removed["X-AUTHENTIK-USERNAME"])
assert(removed["x-authentik-groups"])
assert(removed["x-authentik-osinfra-google-email"])
assert(removed["x-authentik-csrf-extra"])
"""
subprocess.run(["lua", "-"], input=lua + test, text=True, check=True)

print("Shared header stripping preserves CSRF and removes forged identity headers.")
