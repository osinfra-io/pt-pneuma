#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"
require_local_cluster

if [ -z "${TF_VAR_google_oauth_client_id:-}" ] || [ -z "${TF_VAR_google_oauth_client_secret:-}" ]; then
  echo "Set TF_VAR_google_oauth_client_id and TF_VAR_google_oauth_client_secret; full integration requires real Google sign-in." >&2
  exit 1
fi

umask 077
mkdir -p "${WORK_DIR}/runtime" "${WORK_DIR}/config"
chmod 700 "${WORK_DIR}"
if kubectl --context="${KUBE_CONTEXT}" get namespace authentik >/dev/null 2>&1; then
  if [ "$(kubectl --context="${KUBE_CONTEXT}" get namespace authentik --output=jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}')" != "osinfra-local-gateway-stack" ]; then
    echo "The existing authentik namespace is unowned; preserve it and migrate explicitly." >&2
    exit 1
  fi
  if [ ! -f "${WORK_DIR}/runtime/terraform.tfstate" ] &&
    [ -n "$(kubectl --context="${KUBE_CONTEXT}" get deployment,statefulset,secret --namespace=authentik --output=name)" ]; then
    echo "Existing Authentik resources have no local fixture state; refusing to adopt them." >&2
    exit 1
  fi
fi

if [ ! -f "${WORK_DIR}/runtime/credentials.tfvars.json" ]; then
  python3 - "${WORK_DIR}/runtime/credentials.tfvars.json" <<'PY'
import json
import secrets
import sys

keys = [
    "AUTHENTIK_BOOTSTRAP_TOKEN",
    "AUTHENTIK_POSTGRESQL__PASSWORD",
    "AUTHENTIK_SECRET_KEY",
]
with open(sys.argv[1], "x") as stream:
    env = {key: secrets.token_urlsafe(48) for key in keys}
    env["AUTHENTIK_BOOTSTRAP_PASSWORD"] = "akadmin"
    json.dump({"secret_env": env}, stream)
PY
fi

if ! kubectl --context="${KUBE_CONTEXT}" get namespace authentik >/dev/null 2>&1; then
  kubectl --context="${KUBE_CONTEXT}" create --filename=- <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  labels:
    app.kubernetes.io/managed-by: osinfra-local-gateway-stack
  name: authentik
YAML
fi

local_tofu runtime init -input=false
local_tofu runtime apply -input=false -auto-approve \
  -state="${WORK_DIR}/runtime/terraform.tfstate" \
  -var-file="${WORK_DIR}/runtime/credentials.tfvars.json"
kubectl --context="${KUBE_CONTEXT}" rollout status statefulset/postgresql --namespace=authentik --timeout=180s
kubectl --context="${KUBE_CONTEXT}" rollout status deployment/authentik-server --namespace=authentik --timeout=300s
kubectl --context="${KUBE_CONTEXT}" rollout status deployment/authentik-worker --namespace=authentik --timeout=300s
start_admin_forward

python3 - "${WORK_DIR}" <<'PY'
import json
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

work = Path(sys.argv[1])
token = json.loads((work / "runtime/credentials.tfvars.json").read_text())["secret_env"]["AUTHENTIK_BOOTSTRAP_TOKEN"]
base = "https://127.0.0.1:19443"
context = ssl._create_unverified_context()

def get(path):
    request = urllib.request.Request(base + path, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(request, context=context, timeout=10) as response:
        return json.load(response)

deadline = time.monotonic() + 300
while True:
    try:
        outposts = get("/api/v3/outposts/instances/?managed=goauthentik.io%2Foutposts%2Fembedded")["results"]
        flows = get("/api/v3/flows/instances/?slug=default-authentication-flow")["results"]
        stages = get("/api/v3/stages/identification/?name=default-authentication-identification")["results"]
        if len(outposts) == 1 and len(flows) == 1 and len(stages) == 1:
            break
    except (urllib.error.URLError, TimeoutError) as error:
        print(f"Waiting for Authentik bootstrap ({type(error).__name__}).", file=sys.stderr)
    if time.monotonic() >= deadline:
        raise SystemExit("Timed out waiting for built-in Authentik objects; inspect server/worker logs.")
    time.sleep(5)

with (work / "config/bootstrap.tfvars.json").open("w") as stream:
    json.dump({"authentik_token": token, "embedded_outpost_id": outposts[0]["pk"]}, stream)
PY

local_tofu config init -input=false
local_tofu config apply -input=false -auto-approve \
  -state="${WORK_DIR}/config/terraform.tfstate" \
  -var-file="${LOCAL_DIR}/../../../../../logos/pt-logos/teams/pt-pneuma.tfvars" \
  -var-file="${WORK_DIR}/config/bootstrap.tfvars.json"
echo "Authentik configured in Kubernetes. Browser verification remains pending."
