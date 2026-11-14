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
            APISERVER + '    - "--feature-gates=PodCertificateRequest=false"\n',
            APISERVER + "    - '--feature-gates=PodCertificateRequest=false'\n",
            APISERVER + '    - "--feature\\u002dgates=PodCertificateRequest=false"\n',
            APISERVER + '    - "--runtime-config=api/all=true"\n',
            APISERVER + "    - --runtime-config=\n",
        ):
            with self.subTest(apiserver=apiserver), self.assertRaises(ValueError):
                config.prepare(apiserver, KUBELET)

    def test_rejects_existing_kubelet_gates(self):
        for key in ("featureGates", '"featureGates"', "'featureGates'"):
            with self.subTest(key=key), self.assertRaises(ValueError):
                config.prepare(APISERVER, KUBELET + f"{key} :\n  OtherGate: true\n")

    def test_rejects_quoted_duplicates_when_already_configured(self):
        apiserver, kubelet = config.prepare(APISERVER, KUBELET)
        with self.assertRaises(ValueError):
            config.prepare(apiserver + '    - "--feature-gates=OtherGate=false"\n', kubelet)
        with self.assertRaises(ValueError):
            config.prepare(apiserver, kubelet + '"featureGates":\n  OtherGate: true\n')
        with self.assertRaises(ValueError):
            config.prepare(apiserver, kubelet.replace("kind: KubeletConfiguration", "kind: Other"))


if __name__ == "__main__":
    unittest.main()
