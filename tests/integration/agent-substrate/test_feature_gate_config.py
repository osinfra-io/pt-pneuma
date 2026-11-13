"""Test conservative edits to local Kubernetes configuration."""

import unittest

import feature_gate_config as config


APISERVER = "kind: Pod\nspec:\n  containers:\n  - command:\n    - kube-apiserver\n    - --runtime-config=\n"
KUBELET = "apiVersion: kubelet.config.k8s.io/v1beta1\nkind: KubeletConfiguration\n"


class FeatureGateConfigTests(unittest.TestCase):
    def test_enables_required_gates_without_changing_other_configuration(self):
        apiserver, kubelet = config.prepare(APISERVER, KUBELET)
        self.assertIn(config.RUNTIME_FLAG, apiserver)
        self.assertIn(config.API_FLAG, apiserver)
        self.assertEqual(kubelet, KUBELET + config.KUBELET_GATES)
        self.assertEqual(config.prepare(apiserver, kubelet), (apiserver, kubelet))

    def test_rejects_existing_apiserver_settings(self):
        for apiserver in (
            APISERVER.replace("--runtime-config=", "--runtime-config=api/all=true"),
            APISERVER + "    - --feature-gates=SomeOtherGate=true\n",
            APISERVER + "    - --runtime-config=\n",
        ):
            with self.subTest(apiserver=apiserver), self.assertRaises(ValueError):
                config.prepare(apiserver, KUBELET)

    def test_rejects_existing_kubelet_gates(self):
        with self.assertRaises(ValueError):
            config.prepare(APISERVER, KUBELET + "featureGates:\n  OtherGate: true\n")


if __name__ == "__main__":
    unittest.main()
