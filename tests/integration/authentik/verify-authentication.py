#!/usr/bin/env python3
"""Verify applied shared authentication configuration without logging API secrets."""

import json
import http.cookiejar
import ssl
import sys
import urllib.request
from pathlib import Path


def verify_password_flow(context):
    cookies = http.cookiejar.CookieJar()
    client = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=context),
        urllib.request.HTTPCookieProcessor(cookies),
    )
    url = "https://127.0.0.1:19443/api/v3/flows/executor/sandbox-authentication-flow/"

    def execute(payload=None):
        headers = {"Host": "authentik.localhost"}
        body = None
        if payload is not None:
            body = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
            for cookie in cookies:
                if cookie.name == "authentik_csrf":
                    headers["X-CSRFToken"] = cookie.value
        request = urllib.request.Request(url, data=body, headers=headers)
        with client.open(request, timeout=15) as response:
            return json.load(response)

    challenge = execute()
    if challenge.get("component") != "ak-stage-identification":
        raise ValueError("The shared flow did not begin at identification")
    challenge = execute({"uid_field": "akadmin"})
    if challenge.get("component") != "ak-stage-password":
        raise ValueError("The shared flow did not execute its separate password stage")
    challenge = execute({"password": "akadmin"})
    if challenge.get("type") != "redirect":
        component = challenge.get("component", "")
        if component == "ak-stage-authenticator-validate":
            raise ValueError("The shared flow requires administrator MFA verification")
        if component == "ak-stage-password":
            raise ValueError("The shared flow rejected the test administrator password")
        if component != "xak-flow-redirect":
            raise ValueError("The shared flow did not complete the local administrator login")
    request = urllib.request.Request(
        "https://127.0.0.1:19443/api/v3/core/users/me/",
        headers={"Host": "authentik.localhost"},
    )
    with client.open(request, timeout=15) as response:
        if response.status != 200:
            raise ValueError("The shared flow did not establish an authenticated session")
    print("Shared custom flow executed identification, password, and login successfully (local test administrator).")


def verify(work):
    token = json.loads((work / "config/bootstrap.tfvars.json").read_text())["authentik_token"]
    state = json.loads((work / "config/terraform.tfstate").read_text())
    context = ssl._create_unverified_context()
    client = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=context),
    )
    endpoints = {
        "authentik_brand": ("core/brands", (
            "attributes", "branding_custom_css", "branding_favicon", "branding_logo",
            "branding_title", "default", "domain", "flow_authentication",
        )),
        "authentik_flow": ("flows/instances", (
            "authentication", "compatibility_mode", "denied_action", "designation",
            "layout", "name", "slug", "title",
        )),
        "authentik_flow_stage_binding": ("flows/bindings", (
            "evaluate_on_plan", "order", "re_evaluate_policies", "stage", "target",
        )),
        "authentik_policy_binding": ("policies/bindings", (
            "failure_result", "order", "policy", "target",
        )),
        "authentik_stage_identification": ("stages/identification", (
            "captcha_stage", "case_insensitive_matching", "enable_remember_me",
            "enrollment_flow", "password_stage", "passwordless_flow",
            "pretend_user_exists", "recovery_flow", "show_matched_user",
            "show_source_labels", "sources", "user_fields", "webauthn_stage",
        )),
    }
    counts = {kind: 0 for kind in endpoints}
    selected_brand = None
    selected_flow = None
    for resource in state["resources"]:
        kind = resource["type"]
        shared = resource.get("module") == "module.authentication"
        identification = (
            resource.get("module") == "module.authentik_config"
            and kind == "authentik_stage_identification"
            and resource["name"] == "default_authentication"
        )
        if not (shared or identification) or kind not in endpoints:
            continue
        endpoint, fields = endpoints[kind]
        for instance in resource["instances"]:
            expected = instance["attributes"]
            if kind == "authentik_brand":
                selected_brand = expected
            if kind == "authentik_flow":
                selected_flow = expected
            request = urllib.request.Request(
                f"https://127.0.0.1:19443/api/v3/{endpoint}/{expected['id']}/",
                headers={"Authorization": "Bearer " + token, "Host": "authentik.localhost"},
            )
            with client.open(request, timeout=15) as response:
                actual = json.load(response)
            for field in fields:
                value = expected[field]
                observed = actual.get(field)
                if field == "attributes":
                    value = json.loads(value)
                if field in ("sources", "user_fields"):
                    value = sorted(value)
                    observed = sorted(observed)
                if kind == "authentik_stage_identification" and field.endswith(("_stage", "_flow")):
                    # The provider records absent optional UUIDs as "", while the API uses null.
                    value = value or None
                    observed = observed or None
                if value != observed:
                    raise ValueError(f"{kind}.{field} differs from applied shared configuration")
            counts[kind] += 1
    if counts != {
        "authentik_brand": 1,
        "authentik_flow": 1,
        "authentik_flow_stage_binding": 4,
        "authentik_policy_binding": 2,
        "authentik_stage_identification": 1,
    }:
        raise ValueError("Shared brand, flow, stages, policies, or identification state is missing")
    request = urllib.request.Request(
        "https://127.0.0.1:19443/api/v3/core/brands/current/",
        headers={"Host": "authentik.localhost"},
    )
    with client.open(request, timeout=15) as response:
        current_brand = json.load(response)
    if (
        current_brand.get("flow_authentication") != selected_flow["slug"]
        or current_brand.get("branding_title") != selected_brand["branding_title"]
    ):
        raise ValueError("The local hostname did not select the shared brand and custom flow")
    print("Live shared brand/CSS, custom flow, four stages, two policies, and identification settings verified.")
    verify_password_flow(context)


if __name__ == "__main__":
    try:
        verify(Path(sys.argv[1]))
    except Exception as error:
        # Network errors can contain request URLs; never emit response bodies or identities.
        print(f"Shared authentication verification failed ({type(error).__name__}).", file=sys.stderr)
        if isinstance(error, ValueError):
            print(str(error), file=sys.stderr)
        sys.exit(1)
