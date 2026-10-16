# Local integration tests

An opt-in developer test that runs Authentik, Istio ambient, agentgateway, and OpenBao together on a dedicated Docker Desktop Kind cluster. It is not a CI gate; the modules' mocked `tofu test` suites stay in their own repositories.

Pneuma composes these modules, so everything cross-cutting lives here: the shared ingress gateway and TLS certificate, browser-auth policies and routes (rendered by Pneuma's real `gateway-auth` module), the diagnostic workload, the ownership marker, and the holistic verifiers. Module repositories contain no local integration fixtures.

## Layout

| Path | Purpose |
| --- | --- |
| `setup.sh`, `verify.sh`, `teardown.sh` | Stack entry points: Istio → Authentik → agentgateway → OpenBao (teardown in reverse) |
| `shared/` | Preflight/ownership, cluster guards, and `hostnames.txt` |
| `istio/`, `authentik/`, `agentgateway/`, `openbao/` | Per-component fixtures with their own `setup.sh`, `verify.sh`, and `teardown.sh` |
| `verify/` | Holistic HTTP and runtime (fail-closed, admin denial, ztunnel mTLS) verifiers |

Fixtures use the aggregated workspace layout (`arche/` and `pneuma/` under `platform-group/`) so uncommitted module changes are exercised without release pins. Generated credentials and state live in ignored `.work/` directories.

## Usage

```bash
tests/integration/setup.sh --claim   # --claim only on a fresh, dedicated cluster
tests/integration/verify.sh
tests/integration/teardown.sh        # deletes local users and database data
```

Component scripts can be rerun individually (for example `tests/integration/authentik/setup.sh`) while iterating. `tests/integration/openbao/show-credentials.sh` prints the OpenBao URL and its throwaway local root token. Google browser sign-in is a manual developer step; see the `local-integration-testing` skill.

## Hostnames and certificate

`shared/hostnames.txt` is the single list of local gateway hosts. The gateway certificate's subject alternative names are generated from it (plus bare `localhost` for the Google OAuth callback), and the HTTP verifier's allowlist reads it. Adding a component host means editing this list and its route, with no change in any module repository.

A wildcard `*.localhost` SAN was not used because browsers may reject wildcards directly under a single-label TLD.
