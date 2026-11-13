"""Verify an unclaimed cluster cannot bypass Helm ownership checks."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


MOCK = r"""#!/usr/bin/env python3
import os
from pathlib import Path
import sys

tool = Path(sys.argv[0]).name
args = sys.argv[1:]
if tool == "docker":
    if args[0] == "inspect":
        print("desktop")
    elif args[0] == "exec":
        print("shared")
elif tool == "helm":
    required = {"--deployed", "--failed", "--pending", "--uninstalled", "--superseded", "--uninstalling"}
    if not required.issubset(args):
        sys.exit("Helm query omitted release statuses")
    if os.environ["HELM_RESULT"] == "error":
        sys.exit("Helm listing failed")
    if os.environ["HELM_RESULT"] == "existing":
        print("existing-release")
elif tool == "kubectl":
    if args == ["config", "current-context"]:
        print("docker-desktop")
    elif "nodes" in args:
        print("desktop-control-plane")
    elif "configmap" in args and "get" in args:
        sys.exit(1)
    elif "namespaces" in args:
        print("default kube-system kube-public kube-node-lease local-path-storage")
    elif "create" in args:
        Path(os.environ["CLAIM_MARKER"]).touch()
else:
    sys.exit("Unexpected command")
"""


class PreflightTests(unittest.TestCase):
    def test_claim_requires_successful_empty_helm_list(self):
        script = Path(__file__).with_name("preflight.sh")
        for result in ("empty", "existing", "error"):
            with self.subTest(result=result), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                mock = root / "mock"
                mock.write_text(MOCK)
                mock.chmod(0o755)
                for tool in ("docker", "helm", "kubectl"):
                    (root / tool).symlink_to(mock)
                marker = root / "claim"
                run = subprocess.run(
                    ["bash", str(script), "--claim"],
                    env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                         "CLAIM_MARKER": str(marker), "HELM_RESULT": result},
                    text=True, capture_output=True, check=False,
                )
                if result == "empty":
                    self.assertEqual(run.returncode, 0, run.stderr)
                    self.assertTrue(marker.exists())
                else:
                    self.assertNotEqual(run.returncode, 0)
                    self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
