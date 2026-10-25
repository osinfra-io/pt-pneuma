#!/usr/bin/env python3
"""Verify local OpenBao OIDC setup and team policy capabilities without logging tokens."""

import http.client
import json
import socket
import ssl
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


SCRIPT_DIR = Path(__file__).resolve().parent
WORK_DIR = SCRIPT_DIR / ".work"
HOSTNAME = "openbao.localhost"
AUTHENTIK_ISSUER = "https://authentik.localhost/application/o/openbao/"
CALLBACKS = {
    "https://openbao.localhost/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
}
POLICIES = {
    "reader": "pt-pneuma-openbao-secret-readers",
    "writer": "pt-pneuma-openbao-secret-writers",
    "admin": "pt-pneuma-openbao-secret-admins",
}
TEAM_PATH = "pt-pneuma/integration-verification"
OTHER_TEAM_PATH = "pt-example/integration-verification"

TLS_CONTEXT = ssl._create_unverified_context()


class LoopbackHTTPSConnection(http.client.HTTPSConnection):
    def connect(self):
        raw_socket = socket.create_connection(("127.0.0.1", self.port), self.timeout)
        self.sock = TLS_CONTEXT.wrap_socket(raw_socket, server_hostname=self.host)


def fail(message):
    raise ValueError(message)


def api(token, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"X-Vault-Token": token}
    if body is not None:
        headers["Content-Type"] = "application/json"
    connection = LoopbackHTTPSConnection(HOSTNAME, timeout=15)
    try:
        connection.request(method, f"/v1/{path}", body=data, headers=headers)
        response = connection.getresponse()
        status = response.status
        content = response.read()
    except (http.client.HTTPException, OSError) as error:
        fail(f"{method} {path} failed ({type(error).__name__}: {error})")
    finally:
        connection.close()

    if not content:
        return status, {}
    try:
        return status, json.loads(content)
    except json.JSONDecodeError:
        fail(f"{method} {path} returned invalid JSON")


def expect(token, method, path, expected, body=None):
    status, payload = api(token, method, path, body)
    if status not in expected:
        fail(f"{method} {path} returned HTTP {status}; expected {expected}")
    return payload


def verify_oidc(root_token):
    config = expect(root_token, "GET", "auth/oidc/config", {200}).get("data", {})
    if (
        config.get("oidc_discovery_url") != AUTHENTIK_ISSUER
        or config.get("oidc_client_id") != "openbao"
        or not config.get("oidc_discovery_ca_pem")
    ):
        fail("OpenBao OIDC issuer, client ID, or discovery CA does not match the local Authentik provider")

    role = expect(root_token, "GET", "auth/oidc/role/default", {200}).get("data", {})
    if (
        role.get("role_type") != "oidc"
        or role.get("groups_claim") != "groups"
        or set(role.get("allowed_redirect_uris", [])) != CALLBACKS
        or str(role.get("token_max_ttl")) != "3600"
    ):
        fail("OpenBao OIDC role is missing the expected claims, callbacks, or one-hour TTL")

    for callback in sorted(CALLBACKS):
        result = expect(
            "", "POST", "auth/oidc/oidc/auth_url", {200},
            {"role": "default", "redirect_uri": callback},
        )
        authorization_url = urlsplit(result.get("data", {}).get("auth_url", ""))
        if (
            authorization_url.scheme != "https"
            or authorization_url.netloc != "authentik.localhost"
            or authorization_url.path != "/application/o/authorize/"
        ):
            fail("OpenBao did not generate the expected Authentik authorization endpoint")
        connection = LoopbackHTTPSConnection("authentik.localhost", timeout=15)
        try:
            connection.request("GET", f"{authorization_url.path}?{authorization_url.query}")
            response = connection.getresponse()
            location = urlsplit(response.getheader("Location", ""))
            response.read()
            if (
                response.status != 302
                or "error" in parse_qs(location.query)
                or location.netloc not in ("", "authentik.localhost")
                or not location.path.startswith("/if/flow/")
            ):
                fail("Authentik rejected the OpenBao authorization request before browser sign-in")
        finally:
            connection.close()


def create_token(root_token, policy):
    result = expect(
        root_token,
        "POST",
        "auth/token/create",
        {200},
        {"policies": [policy], "no_parent": True, "ttl": "5m", "renewable": False},
    )
    token = result.get("auth", {}).get("client_token")
    if not token:
        fail(f"OpenBao did not issue a temporary token for policy {policy}")
    return token


def verify(root_token):
    verify_oidc(root_token)

    mounts = expect(root_token, "GET", "sys/mounts", {200}).get("data", {})
    team_mount = mounts.get("team-kv2/", {})
    if team_mount.get("type") != "kv" or team_mount.get("options", {}).get("version") != "2":
        fail("The team-kv2 KV v2 mount is not configured")

    for policy in POLICIES.values():
        expect(root_token, "GET", f"sys/policies/acl/{policy}", {200})

    expect(root_token, "POST", f"team-kv2/data/{TEAM_PATH}", {200}, {"data": {"value": "fixture"}})
    expect(root_token, "POST", f"team-kv2/data/{OTHER_TEAM_PATH}", {200}, {"data": {"value": "fixture"}})

    tokens = {}
    try:
        tokens = {access: create_token(root_token, policy) for access, policy in POLICIES.items()}

        expect(tokens["reader"], "GET", f"team-kv2/data/{TEAM_PATH}", {200})
        expect(tokens["reader"], "GET", "team-kv2/metadata/pt-pneuma?list=true", {200})
        expect(tokens["reader"], "POST", f"team-kv2/data/{TEAM_PATH}", {403}, {"data": {"value": "denied"}})
        expect(tokens["reader"], "GET", f"team-kv2/data/{OTHER_TEAM_PATH}", {403})

        writer_path = f"team-kv2/data/{TEAM_PATH}-writer"
        expect(tokens["writer"], "POST", writer_path, {200}, {"data": {"value": "created"}})
        expect(tokens["writer"], "POST", writer_path, {200}, {"data": {"value": "updated"}})
        expect(tokens["writer"], "POST", f"team-kv2/data/{OTHER_TEAM_PATH}", {403}, {"data": {"value": "denied"}})
        for method, suffix, body in (
            ("DELETE", f"team-kv2/data/{TEAM_PATH}-writer", None),
            ("DELETE", f"team-kv2/metadata/{TEAM_PATH}-writer", None),
            ("POST", f"team-kv2/delete/{TEAM_PATH}-writer", {"versions": [1]}),
            ("POST", f"team-kv2/undelete/{TEAM_PATH}-writer", {"versions": [1]}),
            ("POST", f"team-kv2/destroy/{TEAM_PATH}-writer", {"versions": [1]}),
        ):
            expect(tokens["writer"], method, suffix, {403}, body)

        admin_path = f"team-kv2/data/{TEAM_PATH}-admin"
        expect(root_token, "POST", admin_path, {200}, {"data": {"value": "admin"}})
        expect(tokens["admin"], "POST", f"team-kv2/delete/{TEAM_PATH}-admin", {200, 204}, {"versions": [1]})
        expect(tokens["admin"], "POST", f"team-kv2/undelete/{TEAM_PATH}-admin", {200, 204}, {"versions": [1]})
        expect(tokens["admin"], "POST", f"team-kv2/destroy/{TEAM_PATH}-admin", {200, 204}, {"versions": [1]})
        expect(tokens["admin"], "POST", f"team-kv2/data/{OTHER_TEAM_PATH}", {403}, {"data": {"value": "denied"}})
        expect(tokens["admin"], "POST", f"team-kv2/destroy/{OTHER_TEAM_PATH}", {403}, {"versions": [1]})
    finally:
        for token in tokens.values():
            api(token, "POST", "auth/token/revoke-self")
        for path in (
            TEAM_PATH,
            f"{TEAM_PATH}-writer",
            f"{TEAM_PATH}-admin",
            OTHER_TEAM_PATH,
        ):
            api(root_token, "DELETE", f"team-kv2/metadata/{path}")


if __name__ == "__main__":
    try:
        init_file = WORK_DIR / "openbao-init.json"
        if not init_file.is_file():
            fail("OpenBao local initialization file is missing; run tests/integration/openbao/setup.sh first")
        root_token = json.loads(init_file.read_text()).get("root_token")
        if not root_token:
            fail("OpenBao local initialization file is incomplete")
        verify(root_token)
        print("OpenBao OIDC configuration and team policy capabilities verified.")
    except Exception as error:
        print(f"OpenBao access verification failed ({type(error).__name__}).", file=sys.stderr)
        if isinstance(error, ValueError):
            print(str(error), file=sys.stderr)
        sys.exit(1)
