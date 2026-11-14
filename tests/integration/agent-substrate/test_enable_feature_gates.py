"""Exercise node feature-gate edits without a Kubernetes cluster."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import feature_gate_config
from test_feature_gate_config import APISERVER, KUBELET


MOCK_DOCKER = r"""#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import sys

args = sys.argv[1:]
root = Path(os.environ["MOCK_NODE"])
if args[0] == "exec":
    with open(os.environ["MOCK_ACTIONS"], "a") as actions:
        actions.write("exec\n")
if args[0] == "cp":
    def path(value):
        return root / value.split(":", 1)[1].lstrip("/") if value.startswith("node-a:") else Path(value)
    shutil.copyfile(path(args[1]), path(args[2]))
elif args[:3] == ["exec", "node-a", "mktemp"]:
    (root / "tmp" / "local-feature-gates.test").mkdir(parents=True)
    print("/tmp/local-feature-gates.test")
elif args[:4] == ["exec", "node-a", "sh", "-c"]:
    command = args[4]
    temporary = root / args[-1].lstrip("/")
    if "local-apiserver-update" in command:
        shutil.copyfile(temporary / "apiserver.yaml", root / "etc/kubernetes/manifests/kube-apiserver.yaml")
        shutil.copyfile(temporary / "kubelet.yaml", root / "var/lib/kubelet/config.yaml")
        if os.environ.get("MOCK_FAIL_UPDATE") == "true":
            sys.exit(1)
    else:
        shutil.rmtree(temporary)
else:
    raise SystemExit(f"Unexpected docker invocation: {args}")
"""

MOCK_CLUSTER = r"""
assert_docker_desktop_kind_cluster() { :; }
assert_local_gateway_stack_owner() { [ "${MOCK_OWNER}" = owned ]; }
sleep() { :; }
kubectl() {
  case "$1 $2" in
    "version --output=json") printf '{"serverVersion":{"gitVersion":"v1.36.4"}}' ;;
    "get nodes") printf 'node-a\n' ;;
    "--request-timeout=5s get")
      case "$3" in
        --raw=/readyz) echo ok ;;
        --raw=/apis/certificates.k8s.io/v1beta1)
          if [ "${MOCK_LIVE}" = missing_api ]; then echo '{"resources":[]}'; else echo '{"resources":[{"name":"podcertificaterequests"},{"name":"clustertrustbundles"}]}'; fi ;;
        --raw=/api/v1/nodes/node-a/proxy/configz)
          if [ "${MOCK_LIVE}" = missing_gates ]; then echo '{"kubeletconfig":{"featureGates":{}}}'; else echo '{"kubeletconfig":{"featureGates":{"ClusterTrustBundle":true,"ClusterTrustBundleProjection":true,"PodCertificateRequest":true}}}'; fi ;;
        *) return 1 ;;
      esac ;;
    "wait --for=condition=Ready") [ "${MOCK_LIVE}" != not_ready ] ;;
    *) return 1 ;;
  esac
}
"""


class EnableFeatureGatesTests(unittest.TestCase):
    def test_applies_gates_without_retaining_working_files(self):
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
                         "MOCK_ACTIONS": str(root / "actions"), "MOCK_LIVE": "ready",
                         "MOCK_FAIL_UPDATE": str(fail).lower()},
                    text=True, capture_output=True, check=False,
                )
                working_dirs = list((script_dir / ".work").glob("feature-gates.*"))
                if owner != "owned":
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(working_dirs, [])
                    self.assertEqual(apiserver.read_text(), APISERVER)
                    self.assertEqual(kubelet.read_text(), KUBELET)
                    continue
                self.assertEqual(working_dirs, [])
                if fail:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("reset Docker Desktop Kubernetes", result.stderr)
                    self.assertIn("PodCertificateRequest=true", apiserver.read_text())
                    self.assertIn("PodCertificateRequest: true", kubelet.read_text())
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("PodCertificateRequest=true", apiserver.read_text())
                    self.assertIn("PodCertificateRequest: true", kubelet.read_text())

    def test_existing_configuration_requires_live_readiness_without_mutation(self):
        source = Path(__file__).parent
        for live in ("ready", "missing_api", "missing_gates", "not_ready"):
            with self.subTest(live=live), tempfile.TemporaryDirectory() as temporary:
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
                original_api, original_kubelet = feature_gate_config.prepare(APISERVER, KUBELET)
                apiserver.write_text(original_api)
                kubelet.write_text(original_kubelet)
                bin_dir = root / "bin"
                bin_dir.mkdir()
                docker = bin_dir / "docker"
                docker.write_text(MOCK_DOCKER)
                docker.chmod(0o755)
                actions = root / "actions"
                result = subprocess.run(
                    ["bash", str(script_dir / "enable-feature-gates.sh"), "--enable"],
                    env={**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}",
                         "MOCK_NODE": str(node), "MOCK_OWNER": "owned",
                         "MOCK_ACTIONS": str(actions), "MOCK_LIVE": live},
                    text=True, capture_output=True, check=False,
                )
                if live == "ready":
                    self.assertEqual(result.returncode, 0, result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Timed out", result.stderr)
                self.assertFalse(actions.exists())
                self.assertEqual(apiserver.read_text(), original_api)
                self.assertEqual(kubelet.read_text(), original_kubelet)


if __name__ == "__main__":
    unittest.main()
