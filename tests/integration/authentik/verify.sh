#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"
require_local_cluster
kubectl --context="${KUBE_CONTEXT}" rollout status statefulset/postgresql --namespace=authentik --timeout=180s
kubectl --context="${KUBE_CONTEXT}" rollout status deployment/authentik-server --namespace=authentik --timeout=180s
kubectl --context="${KUBE_CONTEXT}" rollout status deployment/authentik-worker --namespace=authentik --timeout=180s
curl --noproxy '*' --fail --insecure --silent --show-error --connect-timeout 5 --max-time 15 \
  https://authentik.localhost/-/health/live/ >/dev/null

start_admin_forward
python3 -B "${LOCAL_DIR}/verify-authentication.py" "${WORK_DIR}"
python3 -B "${LOCAL_DIR}/verify-application-access.py" "${WORK_DIR}"

google_location="$(curl --noproxy '*' --insecure --silent --show-error --connect-timeout 5 --max-time 15 \
  --output /dev/null --write-out '%{http_code} %{redirect_url}' \
  https://authentik.localhost/source/oauth/login/google/)"
if [ "${google_location%% *}" != "302" ] ||
  ! grep --quiet 'redirect_uri=https%3A%2F%2Flocalhost%2Fsource%2Foauth%2Fcallback%2Fgoogle%2F' <<<"${google_location}"; then
  echo "Google login must redirect using the registered https://localhost callback." >&2
  exit 1
fi
echo "Authentik runtime and Google redirect checks passed; real browser sign-in is still required."
