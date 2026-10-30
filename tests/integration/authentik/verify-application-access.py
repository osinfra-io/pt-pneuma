#!/usr/bin/env python3
"""Exercise deployed application mappings inside Authentik without a browser identity."""

import json
from pathlib import Path
import ssl
import sys
import urllib.request


def verify(work):
    token = json.loads((work / "config/bootstrap.tfvars.json").read_text())["authentik_token"]
    state = json.loads((work / "config/terraform.tfstate").read_text())
    client = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=ssl._create_unverified_context()),
    )

    def api(path, payload=None):
        headers = {"Authorization": "Bearer " + token}
        data = None
        if payload is not None:
            data = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(
            "https://127.0.0.1:19443/api/v3/" + path, data=data, headers=headers,
        )
        with client.open(request, timeout=15) as response:
            return json.load(response)

    def objects(kind, name):
        return [
            instance["attributes"]
            for resource in state["resources"]
            if resource.get("module") == "module.authentik_config"
            and resource["type"] == kind and resource["name"] == name
            for instance in resource["instances"]
        ]

    if api("core/applications/?slug=development-oidc")["results"]:
        raise ValueError("The unused Development OIDC application must not exist in the local fixture")

    applications = objects("authentik_application", "browser")
    expected_launches = {
        "agentgateway": "https://agentgateway.localhost/ui/",
        "Istio": "https://dev.localhost/istio-test/auth",
    }
    expected_icons = {
        "agentgateway": "https://docs.osinfra.io/img/applications/agentgateway.svg",
        "Istio": "https://docs.osinfra.io/img/applications/istio.svg",
        "OpenBao": "https://docs.osinfra.io/img/applications/openbao.svg",
    }
    if {application["name"] for application in applications} != set(expected_launches):
        raise ValueError("Browser applications do not have the expected descriptive names")
    for application in applications:
        actual = api(f"core/applications/{application['slug']}/")
        if (
            actual["name"] != application["name"]
            or actual["meta_launch_url"] != expected_launches[application["name"]]
            or actual["meta_icon"] != expected_icons[application["name"]]
        ):
            raise ValueError("Browser application name, icon, or launch URL differs from the intended configuration")

    if api("core/applications/openbao/")["meta_icon"] != expected_icons["OpenBao"]:
        raise ValueError("The OpenBao application must use the docs-hosted icon")

    openbao_providers = objects("authentik_provider_oauth2", "openbao")
    if len(openbao_providers) != 1:
        raise ValueError("The local fixture requires its dedicated OpenBao OAuth provider")
    openbao_provider = api(f"providers/oauth2/{openbao_providers[0]['id']}/")
    if "authorization_code" not in openbao_provider.get("grant_types", []):
        raise ValueError("The live OpenBao OAuth provider rejects authorization-code login")

    identities = objects("authentik_property_mapping_source_oauth", "google_username")
    if len(identities) != 1:
        raise ValueError("The Google identity mapping must be present in applied configuration")
    for info, expected_type in [
        ({"email": "member@osinfra.io", "hd": "osinfra.io", "verified_email": True}, "internal"),
        ({"email": "member@osinfra.io", "hd": "osinfra.io", "email_verified": True}, "internal"),
        ({"email": "member@osinfra.io", "verified_email": True}, "external"),
        ({"email": "member@example.com", "hd": "example.com", "verified_email": True}, "external"),
        ({"email": "member@example.com", "hd": "osinfra.io", "verified_email": True}, "external"),
        ({"email": "member@osinfra.io", "hd": "osinfra.io"}, "external"),
        ({"email": "member@osinfra.io", "hd": "osinfra.io", "verified_email": "true"}, "external"),
        ({"email": "member@osinfra.io", "hd": "osinfra.io", "email_verified": True, "verified_email": False}, "external"),
    ]:
        result = api(
            f"propertymappings/all/{identities[0]['id']}/test/", {"context": {"info": info}},
        )
        if not result["successful"] or json.loads(result["result"]) != {
            "username": info["email"], "type": expected_type,
        }:
            raise ValueError("Google user classification must require a verified matching Workspace domain")

    mappings = objects("authentik_property_mapping_source_oauth", "google_application_groups")
    proxies = objects("authentik_property_mapping_provider_scope", "google_proxy")
    if len(mappings) != 1 or len(proxies) != 1:
        raise ValueError("Local application mappings must be present in the applied configuration")
    browser_providers = objects("authentik_provider_proxy", "browser")
    if not browser_providers or any(
        provider.get("access_token_validity") != "minutes=10" for provider in browser_providers
    ):
        raise ValueError("Applied browser proxy provider state must bound cached claims to ten minutes")
    for info in [
        {"email": "test@example.com", "verified_email": True},
        {"email": "test@example.com", "email_verified": True},
    ]:
        result = api(
            f"propertymappings/all/{mappings[0]['id']}/test/", {"context": {"info": info}},
        )
        if not result["successful"]:
            raise ValueError("Deployed Google mapping rejected a verified synthetic profile")
        mapped = json.loads(result["result"])
        if mapped.get("groups") != [] or mapped.get("attributes", {}).get("osinfra_google_email") != info["email"]:
            raise ValueError("Google mapping did not preserve verified identity and deny an undeclared member")
    for verification in [
        {},
        {"verified_email": False},
        {"verified_email": "true"},
        {"email_verified": True, "verified_email": False},
        {"email_verified": False, "verified_email": True},
    ]:
        result = api(
            f"propertymappings/all/{mappings[0]['id']}/test/",
            {"context": {"info": {"email": "test@example.com", **verification}}},
        )
        if result["successful"]:
            raise ValueError("Deployed Google mapping accepted an unverified or conflicting profile")

    administrators = api("core/users/?username=akadmin")["results"]
    if len(administrators) != 1:
        raise ValueError("The owned fixture requires its unique source-independent test administrator")
    result = api(
        f"propertymappings/all/{proxies[0]['id']}/test/",
        {"user": administrators[0]["pk"], "context": {}},
    )
    if not result["successful"]:
        raise ValueError("Deployed verified identity scope failed inside Authentik")
    headers = json.loads(result["result"])["ak_proxy"]["user_attributes"]["additionalHeaders"]
    if headers.get("X-authentik-osinfra-google-email") != "":
        raise ValueError("A source-independent test identity received a verified Google header")

    for expected in objects("authentik_group", "application"):
        actual = api(f"core/groups/{expected['id']}/")
        if actual["is_superuser"] != expected["is_superuser"] or actual["name"] != expected["name"]:
            raise ValueError("Application group name or administrative status differs from applied configuration")
        if sorted(map(str, actual["users"])) != sorted(map(str, expected["users"])):
            raise ValueError("Application memberships differ from applied configuration")
    print("Live Authentik evaluator verified native/OIDC email fields, unverified denial, source-independent header denial, and application groups.")
    print("Applied state confirms browser proxy providers use ten-minute claim validity.")
    print("These dry-run checks do not establish real Google browser sign-in or session revocation.")


if __name__ == "__main__":
    try:
        verify(Path(sys.argv[1]))
    except (ValueError, KeyError) as error:
        print(f"Application mapping verification failed: {error}", file=sys.stderr)
        sys.exit(1)
