"""Exercise node backup and rollback without a Kubernetes cluster."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from test_feature_gate_config import APISERVER, KUBELET


MOCK_DOCKER = r"""#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import sys

args = sys.argv[1:]
root = Path(os.environ["MOCK_NODE"])
if args[0] == "cp":
    def path(value):
        return root / value.split(":", 1)[1].lstrip("/") if value.startswith("node-a:") else Path(value)
    shutil.copyfile(path(args[1]), path(args[2]))
elif args[:3] == ["exec", "node-a", "mktemp"]:
    (root / "tmp" / "local-feature-gates.test").mkdir(parents=True)
    print("/tmp/local-feature-gates.test")
elif args[:4] == ["exec", "--interactive", "node-a", "sh"]:
    (root / args[-1].lstrip("/")).write_bytes(sys.stdin.buffer.read())
elif args[:5] == ["exec", "node-a", "sh", "-c", args[4]]:
    command = args[4]
    temporary = root / args[-1].lstrip("/")
    if "local-apiserver-update" in command or "local-apiserver-restore" in command:
        shutil.copyfile(temporary / "apiserver.yaml", root / "etc/kubernetes/manifests/kube-apiserver.yaml")
        shutil.copyfile(temporary / "kubelet.yaml", root / "var/lib/kubelet/config.yaml")
        if "local-apiserver-update" in command and os.environ.get("MOCK_FAIL_UPDATE") == "true":
            sys.exit(1)
    else:
        for file in temporary.iterdir():
            file.unlink()
        temporary.rmdir()
else:
    raise SystemExit(f"Unexpected docker invocation: {args}")
"""

MOCK_CLUSTER = r"""
assert_docker_desktop_kind_cluster() { :; }
assert_local_gateway_stack_owner() { [ "${MOCK_OWNER}" = owned ]; }
kubectl() {
  case "$1 $2" in
    "version --output=json") printf '{"serverVersion":{"gitVersion":"v1.36.4"}}' ;;
    "get nodes") printf 'node-a\n' ;;
    "--request-timeout=5s get")
      case "$3" in
        --raw=/readyz) echo ok ;;
        --raw=/apis/certificates.k8s.io/v1beta1) echo '{"resources":[{"name":"podcertificaterequests"},{"name":"clustertrustbundles"}]}' ;;
        --raw=/api/v1/nodes/node-a/proxy/configz) echo '{"kubeletconfig":{"featureGates":{"ClusterTrustBundle":true,"ClusterTrustBundleProjection":true,"PodCertificateRequest":true}}}' ;;
        *) return 1 ;;
      esac ;;
    "wait --for=condition=Ready") return 0 ;;
    *) return 1 ;;
  esac
}
"""


class EnableFeatureGatesTests(unittest.TestCase):
    def test_backup_apply_and_rollback(self):
        source = Path(__file__).parent
        for owner, fail in (("owned", False), ("owned", True), ("unowned", False)):
            with self.subTest(owner=owner, fail=fail), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                script_dir = root / "agent-substrate"
                script_dir.mkdir()
                shared = root / "shared"
                shared.mkdir()
                (shared / "cluster.sh").write_text(MOCK_CLUSTER)
                for name in ("enable-feature-gates.sh", "feature_gate_config.py"):
                    shutil.copy(source / name, script_dir / name)
                node = root / "node"
                apiserver = node / "etc/kubernetes/manifests/kube-apiserver.yaml"
                kubelet = node / "var/lib/kubelet/config.yaml"
                apiserver.parent.mkdir(parents=True)
                kubelet.parent.mkdir(parents=True)
                apiserver.write_text(APISERVER)
                kubelet.write_text(KUBELET)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                docker = bin_dir / "docker"
                docker.write_text(MOCK_DOCKER)
                docker.chmod(0o755)
                result = subprocess.run(
                    ["bash", str(script_dir / "enable-feature-gates.sh"), "--enable"],
                    env={**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}",
                         "MOCK_NODE": str(node), "MOCK_OWNER": owner,
                         "MOCK_FAIL_UPDATE": str(fail).lower()},
                    text=True, capture_output=True, check=False,
                )
                backups = list((script_dir / ".work").glob("feature-gate-backup.*"))
                if owner != "owned":
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(backups, [])
                    self.assertEqual(apiserver.read_text(), APISERVER)
                    self.assertEqual(kubelet.read_text(), KUBELET)
                    continue
                self.assertEqual(len(backups), 1)
                self.assertEqual((backups[0] / "apiserver.yaml").read_text(), APISERVER)
                self.assertEqual((backups[0] / "kubelet.yaml").read_text(), KUBELET)
                if fail:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("original node configuration was restored", result.stderr)
                    self.assertEqual(apiserver.read_text(), APISERVER)
                    self.assertEqual(kubelet.read_text(), KUBELET)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("PodCertificateRequest=true", apiserver.read_text())
                    self.assertIn("PodCertificateRequest: true", kubelet.read_text())


if __name__ == "__main__":
    unittest.main()
