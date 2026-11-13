"""Tests for guarded feature-gate diagnostics."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class InspectFeatureGatesTests(unittest.TestCase):
    def test_inspects_each_node_only_after_ownership_check(self):
        source = Path(__file__).with_name("inspect-feature-gates.sh")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            script_dir = root / "agent-substrate"
            script_dir.mkdir()
            shared = root / "shared"
            shared.mkdir()
            shutil.copy(source, script_dir)
            (shared / "cluster.sh").write_text(
                'assert_docker_desktop_kind_cluster() { :; }\n'
                'assert_local_gateway_stack_owner() { [ "${TEST_OWNER}" = owned ]; }\n'
                'kubectl() { if [ "$1" = version ]; then printf "{\\"serverVersion\\":{\\"gitVersion\\":\\"test\\"}}"; else printf "node-a\\nnode-b\\n"; fi; }\n'
                'docker() { printf "inspected %s\\n" "$2"; }\n'
            )
            script = script_dir / source.name
            for owner in ("unowned", "owned"):
                result = subprocess.run(
                    ["bash", str(script)],
                    env={**os.environ, "TEST_OWNER": owner},
                    text=True, capture_output=True, check=False,
                )
                if owner == "unowned":
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn("inspected", result.stdout)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("inspected node-a", result.stdout)
                    self.assertIn("inspected node-b", result.stdout)


if __name__ == "__main__":
    unittest.main()
