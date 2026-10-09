"""Execute the actual rendered Envoy Lua guard with a minimal HeaderMap harness."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]
ADMIN = "pt-pneuma: agentgateway Admins"
READER = "st-example: Reports Readers"


class BrowserAuthorizationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.directory.cleanup)
        cls.root = Path(cls.directory.name)
        for source in list(MODULE.glob("*.tofu")) + list(MODULE.glob("*.tftpl")):
            shutil.copyfile(source, cls.root / source.name)
        subprocess.run(
            ["tofu", "init", "-backend=false", "-input=false", "-no-color"],
            cwd=cls.root, check=True, capture_output=True, text=True,
        )
        cls.harness = cls.root / "harness.lua"
        cls.harness.write_text("""
dofile(arg[1])
local headers = {}
for line in io.lines(arg[2]) do
  local key, value = string.match(line, "^([^=]+)=(.*)$")
  headers[key] = value
end
local handle = {status = 200}
function handle:headers()
  return {get = function(_, key) return headers[key] end}
end
function handle:logWarn(message) assert(message == "Declared application access denied") end
function handle:respond(response, body)
  self.status = tonumber(response[":status"])
  assert(body == "Forbidden\\n")
end
envoy_on_request(handle)
print(handle.status)
""")
        cls.render({ADMIN: ["member@example.com"], READER: ["reader@example.com"]})

    @classmethod
    def render(cls, members):
        variables = {
            "application_group_members": members,
            "policies": {
                "ui": {
                    "host": "agentgateway.localhost",
                    "path": "/ui",
                    "required_groups": [ADMIN],
                },
                "reports": {
                    "host": "agentgateway.localhost",
                    "path": "/reports",
                    "required_groups": [READER],
                    "public_paths": ["/reports/public/*"],
                },
                "and": {
                    "host": "agentgateway.localhost",
                    "path": "/both",
                    "required_groups": [ADMIN, READER],
                    "required_roles": ["reviewer"],
                },
                "api": {
                    "host": "agentgateway.localhost",
                    "path": "/api",
                    "mode": "api-jwt",
                },
            },
        }
        (cls.root / "inputs.tfvars.json").write_text(json.dumps(variables))
        result = subprocess.run(
            ["tofu", "apply", "-auto-approve", "-input=false", "-no-color",
             "-var-file=inputs.tfvars.json"],
            cwd=cls.root, capture_output=True, text=True,
        )
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        outputs = json.loads(subprocess.check_output(
            ["tofu", "output", "-json"], cwd=cls.root, text=True,
        ))
        manifest = outputs["browser_authorization_filter_manifests"]["value"]["application_access"]
        patch = manifest["spec"]["configPatches"][0]
        if patch["patch"]["operation"] != "INSERT_AFTER":
            raise AssertionError("Guard must run after forward-auth")
        if patch["match"]["listener"]["filterChain"]["filter"]["subFilter"]["name"] != "envoy.filters.http.ext_authz":
            raise AssertionError("Guard must follow ext_authz, not JWT authorization")
        cls.guard = cls.root / "guard.lua"
        cls.guard.write_text(patch["patch"]["value"]["typed_config"]["inlineCode"])

    def status(self, path, email="member@example.com", groups=ADMIN, host="agentgateway.localhost"):
        headers = self.root / "headers"
        headers.write_text(
            f":authority={host}\n:path={path}\n"
            f"x-authentik-osinfra-google-email={email}\nx-authentik-groups={groups}\n"
        )
        result = subprocess.run(
            ["lua", str(self.harness), str(self.guard), str(headers)],
            check=True, capture_output=True, text=True,
        )
        return int(result.stdout.strip())

    def test_member_and_branding(self):
        self.assertEqual(self.status("/ui/"), 200)
        self.assertEqual(self.status("/ui/health"), 200)
        self.assertEqual(self.status("/ui/config?view=all", host="AGENTGATEWAY.localhost:443"), 200)

    def test_managed_members_do_not_depend_on_stale_groups(self):
        self.assertEqual(self.status("/ui", groups=""), 200)
        self.assertEqual(self.status("/ui", email="other@example.com", groups=ADMIN), 403)

    def test_independent_paths_on_same_host(self):
        self.assertEqual(self.status("/reports"), 403)
        self.assertEqual(self.status("/reports", email="reader@example.com"), 200)
        self.assertEqual(self.status("/ui", email="reader@example.com"), 403)

    def test_and_and_exact_or_semantics(self):
        self.assertEqual(self.status("/both", groups="reviewer"), 200)
        self.assertEqual(self.status("/both", email="reader@example.com", groups="reviewer"), 200)
        self.assertEqual(self.status("/both", groups="reviewers"), 403)
        self.assertEqual(self.status("/both", groups="operator|reviewer"), 200)
        self.assertEqual(self.status("/both", groups=""), 403)

    def test_missing_wrong_or_duplicate_identity(self):
        for email in ["", "MEMBER@example.com", "member@example.com,other@example.com", "member@example.com "]:
            with self.subTest(email=email):
                self.assertEqual(self.status("/ui", email=email), 403)

    def test_public_callbacks_api_and_prefix_boundaries(self):
        for path in ["/reports/public/metadata", "/outpost.goauthentik.io/callback",
                     "/api", "/ui-other"]:
            with self.subTest(path=path):
                self.assertEqual(self.status(path, email=""), 200)
        self.assertEqual(self.status("/reports/public", email=""), 403)
        self.assertEqual(self.status("/ui/health", email=""), 403)
        self.assertEqual(self.status("/ui", email="", host="other.localhost"), 200)

    def test_ambiguous_paths_fail_closed(self):
        for path in ["/%75i", "/ui%2fconfig", "/ui//config", "/ui/../reports", "/ui/./config", "/ui\\config"]:
            with self.subTest(path=path):
                self.assertEqual(self.status(path), 403)

    def test_removal_denies_existing_session(self):
        try:
            self.render({ADMIN: [], READER: ["reader@example.com"]})
            self.assertEqual(self.status("/ui", groups=ADMIN), 403)
            self.assertEqual(self.status("/reports", email="reader@example.com"), 200)
        finally:
            self.render({ADMIN: ["member@example.com"], READER: ["reader@example.com"]})

    def test_valid_email_with_html_escaped_character(self):
        try:
            self.render({ADMIN: ["a&b@example.com"], READER: []})
            self.assertEqual(self.status("/ui", email="a&b@example.com"), 200)
        finally:
            self.render({ADMIN: ["member@example.com"], READER: ["reader@example.com"]})


if __name__ == "__main__":
    unittest.main()
