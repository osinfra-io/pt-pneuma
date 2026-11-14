"""Verify preflight only initializes an empty cluster fixture."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
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
    required = {"--deployed", "--failed", "--pending", "--uninstalling"}
    if not required.issubset(args):
        sys.exit("Helm query omitted release statuses")
    if {"--uninstalled", "--superseded"}.intersection(args):
        sys.exit("Helm query included historical releases")
    if os.environ["HELM_RESULT"] == "error":
        sys.exit("Helm listing failed")
    if os.environ["HELM_RESULT"] in {"deployed", "failed", "pending", "uninstalling"}:
        print("existing-release")
elif tool == "kubectl":
    if args == ["config", "current-context"]:
        print("docker-desktop")
    elif "--raw=/readyz" in args:
        pass
    elif "nodes" in args:
        print("desktop-control-plane")
    elif "configmap" in args and "get" in args:
        sys.exit(1)
    elif "namespaces" in args:
        print("default kube-system kube-public kube-node-lease local-path-storage")
    elif "pods,deployments,replicasets,statefulsets,daemonsets,jobs,cronjobs" in args:
        if os.environ.get("DEFAULT_WORKLOAD"):
            print(os.environ["DEFAULT_WORKLOAD"])
    elif "crds" in args:
        pass
    elif "create" in args:
        Path(os.environ["CLAIM_MARKER"]).touch()
else:
    sys.exit("Unexpected command")
"""


class PreflightTests(unittest.TestCase):
    def test_only_empty_cluster_initializes_and_cleans_fixture_workdirs(self):
        source = Path(__file__).parent
        scenarios = ("empty", "deployed", "failed", "pending", "uninstalling", "error", "workload")
        for result in scenarios:
            with self.subTest(result=result), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                shared = root / "integration" / "shared"
                shared.mkdir(parents=True)
                shutil.copy(source / "preflight.sh", shared / "preflight.sh")
                shutil.copy(source / "owner.sh", shared / "owner.sh")
                workdirs = []
                for component in ("istio", "authentik", "agentgateway", "agent-substrate", "kagent", "openbao"):
                    workdir = root / "integration" / component / ".work"
                    workdir.mkdir(parents=True)
                    (workdir / "state").touch()
                    workdirs.append(workdir)

                mock = root / "mock"
                mock.write_text(MOCK.replace("#!/usr/bin/env python3", f"#!{sys.executable}"))
                mock.chmod(0o755)
                for tool in ("docker", "helm", "kubectl"):
                    (root / tool).symlink_to(mock)
                for tool in ("curl", "jq", "openssl", "python3", "tofu"):
                    executable = root / tool
                    executable.write_text("#!/usr/bin/env bash\nexit 0\n")
                    executable.chmod(0o755)
                marker = root / "claim"
                run = subprocess.run(
                    ["bash", str(shared / "preflight.sh")],
                    env={
                        **os.environ,
                        "PATH": f"{root}:{os.environ['PATH']}",
                        "CLAIM_MARKER": str(marker),
                        "HELM_RESULT": result,
                        "DEFAULT_WORKLOAD": (
                            "deployment.apps/manual-app" if result == "workload" else ""
                        ),
                    },
                    text=True, capture_output=True, check=False,
                )
                if result == "empty":
                    self.assertEqual(run.returncode, 0, run.stderr)
                    self.assertTrue(marker.exists())
                    self.assertTrue(all(not workdir.exists() for workdir in workdirs))
                else:
                    self.assertNotEqual(run.returncode, 0)
                    self.assertFalse(marker.exists())
                    self.assertTrue(all(workdir.joinpath("state").exists() for workdir in workdirs))
                    if result in {"deployed", "failed", "pending", "uninstalling"}:
                        self.assertIn("Existing Helm installations", run.stderr)
                    elif result == "error":
                        self.assertIn("Helm listing failed", run.stderr)
                    else:
                        self.assertIn("Existing workloads in the default namespace", run.stderr)


if __name__ == "__main__":
    unittest.main()
