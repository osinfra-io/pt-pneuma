# Local integration tests

An opt-in developer test that runs Authentik, Istio ambient, agentgateway, and OpenBao together on a dedicated Docker Desktop Kind cluster. It is not a CI gate; the modules' mocked `tofu test` suites stay in their own repositories.

Pneuma composes these modules, so everything cross-cutting lives here: the shared ingress gateway and TLS certificate, browser-auth policies and routes (rendered by Pneuma's real `gateway-auth` module), the diagnostic workload, the ownership marker, and the holistic verifiers. Module repositories contain no local integration fixtures.

## Layout

| Path | Purpose |
| --- | --- |
| `setup.sh`, `verify.sh`, `teardown.sh` | Stack entry points: Istio → Authentik → agentgateway → OpenBao (teardown in reverse) |
| `shared/` | Preflight/ownership, cluster guards, and `hostnames.txt` |
| `istio/`, `authentik/`, `agentgateway/`, `openbao/` | Per-component fixtures with their own `setup.sh`, `verify.sh`, and `teardown.sh`; OpenBao also applies a local OIDC and team-policy configuration stage |
| `verify/` | Holistic HTTP and runtime (fail-closed, admin denial, ztunnel mTLS) verifiers |

Fixtures use the aggregated workspace layout (`arche/` and `pneuma/` under `platform-group/`) so uncommitted module changes are exercised without release pins. Generated credentials and state live in ignored `.work/` directories.

## Usage

```bash
tests/integration/setup.sh --claim   # --claim only on a fresh, dedicated cluster
tests/integration/verify.sh
tests/integration/teardown.sh        # deletes local users and database data
```

Component scripts can be rerun individually (for example `tests/integration/authentik/setup.sh`) while iterating. The OpenBao setup applies its fixture-owned OIDC and KV v2 configuration using the local Authentik outputs and credentials under `.work/`. Automated verification checks the OIDC settings, reader/writer/admin capabilities, and cross-team denial; it uses short-lived test tokens and never prints them.

Google-backed OIDC sign-in is a separate manual developer check and is not covered by the automated verifier:

1. Open `https://openbao.localhost/ui/`, choose the OIDC login method, and complete the Google sign-in through Authentik.
2. Use the CLI callback flow with a browser-enabled terminal:

   ```bash
   BAO_ADDR=https://openbao.localhost bao login -method=oidc -path=oidc role=default
   ```

3. Verify team-scoped access with an Authentik user whose local team group membership is configured. The automated policy checks do not prove that Google sign-in or group claims work end to end. Report the browser/CLI check separately and only after observing it.

The local fixture uses the same host-level authorization as the cloud: `agentgateway.localhost` requires the managed agentgateway Admins group, while `dev.localhost` uses the baseline `all` group. No post-auth authorization Lua is deployed; only identity-header stripping remains.

To verify membership changes without regenerating gateway configuration, sign in at `https://agentgateway.localhost/ui/` with a declared member, then apply only the Authentik configuration with the revocation flag:

```bash
tofu -chdir=tests/integration/authentik/config apply -auto-approve \
  -state=../../.work/config/terraform.tfstate \
  -var-file=../../../../../../logos/pt-logos/teams/pt-pneuma.tfvars \
  -var-file=../../.work/config/bootstrap.tfvars.json \
  -var=revoke_application_access=true
```

The existing session can retain its cached authorization for up to ten minutes plus one second. A fresh session should be denied immediately; diagnostic access at `dev.localhost` is unaffected. Restore the declared memberships by rerunning the same command with `-var=revoke_application_access=false`; neither apply changes gateway configuration. This expiry bound is derived from outpost session handling and still requires live browser verification.

See the `local-integration-testing` skill for cluster ownership and manual Google sign-in requirements.

## Hostnames and certificate

`shared/hostnames.txt` is the single list of local gateway hosts. The gateway certificate's subject alternative names are generated from it (plus bare `localhost` for the Google OAuth callback), and the HTTP verifier's allowlist reads it. Adding a component host means editing this list and its route, with no change in any module repository.

A wildcard `*.localhost` SAN was not used because browsers may reject wildcards directly under a single-label TLD.
