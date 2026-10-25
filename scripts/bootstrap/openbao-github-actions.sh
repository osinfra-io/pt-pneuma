#!/usr/bin/env bash

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 sandbox | non-production | production"
  echo "Requires bao, jq, and an existing administrative OpenBao login."
  exit 0
fi

[[ $# == 1 ]] || { echo "Specify one environment: sandbox, non-production, or production." >&2; exit 1; }

case "${1:-}" in
  sandbox)
    address="https://openbao.sb.osinfra.io"
    environment="Sandbox OpenBao: us-east1-b"
    ref="refs/pull/*/merge"
    events='["pull_request"]'
    plan_subject="repo:osinfra-io/pt-pneuma:pull_request"
    ;;
  non-production | production)
    if [[ "$1" == non-production ]]; then
      address="https://openbao.nonprod.osinfra.io"
      environment="Non-Production OpenBao: us-east1-b"
    else
      address="https://openbao.osinfra.io"
      environment="Production OpenBao: us-east1-b"
    fi
    ref="refs/heads/main"
    events='["push", "workflow_dispatch"]'
    plan_subject="repo:osinfra-io/pt-pneuma:ref:refs/heads/main"
    ;;
  *)
    echo "Usage: $0 sandbox | non-production | production" >&2
    exit 1
    ;;
esac

command -v bao >/dev/null
command -v jq >/dev/null
if [[ -n "${BAO_ADDR:-}" && "$BAO_ADDR" != "$address" ]]; then
  echo "BAO_ADDR does not match the selected environment ($address)." >&2
  exit 1
fi
export BAO_ADDR="$address"
bao token lookup >/dev/null

auth_type="$(bao auth list -format=json | jq -r '."github-actions/".type // ""')"
if [[ -z "$auth_type" ]]; then
  bao auth enable -path=github-actions jwt
elif [[ "$auth_type" != jwt ]]; then
  echo "Existing github-actions/ mount is not JWT; refusing to replace it." >&2
  exit 1
fi

bao write auth/github-actions/config \
  oidc_discovery_url=https://token.actions.githubusercontent.com \
  bound_issuer=https://token.actions.githubusercontent.com

policy_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../regional/openbao-config/policies" && pwd)"
for access in plan apply; do
  bao policy write "pt-pneuma-openbao-$access" "$policy_directory/github-actions-$access.hcl"
done

for access in plan apply; do
  subject="$plan_subject"
  if [[ "$access" == apply ]]; then
    subject="repo:osinfra-io/pt-pneuma:environment:${environment//:/%3A}"
  fi
  jq -n \
    --arg subject "$subject" \
    --arg ref "$ref" \
    --argjson events "$events" \
    --arg policy "pt-pneuma-openbao-$access" \
    '{
      role_type: "jwt",
      user_claim: "sub",
      bound_audiences: ["pt-pneuma-openbao"],
      bound_subject: $subject,
      bound_claims_type: "glob",
      bound_claims: {
        repository_id: "1093115151",
        repository_owner_id: "104685378",
        ref: $ref,
        event_name: $events
      },
      token_policies: [$policy],
      token_ttl: 900,
      token_max_ttl: 900,
      token_explicit_max_ttl: 900
    }' |
    bao write "auth/github-actions/role/pt-pneuma-openbao-$access" -
done

echo "Configured GitHub Actions authentication at $BAO_ADDR for $ref."
