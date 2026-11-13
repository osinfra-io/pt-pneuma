"""Prepare feature-gate edits for the supported Docker Desktop Kind node."""

import argparse
from pathlib import Path


GATES = ("ClusterTrustBundle", "ClusterTrustBundleProjection", "PodCertificateRequest")
API_FLAG = "    - --feature-gates=" + ",".join(f"{gate}=true" for gate in GATES)
RUNTIME_FLAG = "    - --runtime-config=certificates.k8s.io/v1beta1=true"
KUBELET_GATES = "featureGates:\n" + "".join(f"  {gate}: true\n" for gate in GATES)


def prepare(apiserver, kubelet):
    api_lines = apiserver.splitlines()
    runtime = [line for line in api_lines if line.strip().startswith("- --runtime-config=")]
    flags = [line for line in api_lines if line.strip().startswith("- --feature-gates=")]
    if "kind: Pod" not in api_lines or len(runtime) != 1:
        raise ValueError("Unsupported API server manifest")
    if runtime == [RUNTIME_FLAG] and flags == [API_FLAG] and KUBELET_GATES in kubelet:
        return apiserver, kubelet
    if runtime != ["    - --runtime-config="] or flags:
        raise ValueError("Existing API server runtime or feature-gate configuration needs manual review")
    if "kind: KubeletConfiguration" not in kubelet.splitlines() or any(
        line.startswith("featureGates:") for line in kubelet.splitlines()
    ):
        raise ValueError("Existing kubelet feature-gate configuration needs manual review")
    updated_api = apiserver.replace(runtime[0], f"{RUNTIME_FLAG}\n{API_FLAG}", 1)
    updated_kubelet = kubelet.rstrip("\n") + "\n" + KUBELET_GATES
    return updated_api, updated_kubelet


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("apiserver", type=Path)
    parser.add_argument("kubelet", type=Path)
    parser.add_argument("output_apiserver", type=Path)
    parser.add_argument("output_kubelet", type=Path)
    args = parser.parse_args()
    try:
        apiserver, kubelet = prepare(args.apiserver.read_text(), args.kubelet.read_text())
    except ValueError as error:
        parser.exit(1, f"{error}\n")
    args.output_apiserver.write_text(apiserver)
    args.output_kubelet.write_text(kubelet)


if __name__ == "__main__":
    main()
