"""Inspect local enrollment configuration and events without emitting user data."""

from collections import Counter
import importlib.util
import json
from pathlib import Path
import ssl
import sys
import urllib.request


spec = importlib.util.spec_from_file_location(
    "access_diagnostics", Path(__file__).with_name("diagnose-access.py"),
)
diagnostics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostics)


def diagnose(work):
    token = json.loads((work / "config/bootstrap.tfvars.json").read_text())["authentik_token"]
    client = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=ssl._create_unverified_context()),
    )

    def api(path):
        request = urllib.request.Request(
            "https://127.0.0.1:19443/api/v3/" + path,
            headers={"Authorization": "Bearer " + token},
        )
        with client.open(request, timeout=15) as response:
            return json.load(response)

    def pages(path):
        page = 1
        while True:
            response = api(f"{path}{'&' if '?' in path else '?'}page_size=100&page={page}")
            yield from response["results"]
            if not response["pagination"]["next"]:
                break
            page += 1

    source = api("sources/oauth/google/")
    enrollment = next(
        flow for flow in pages("flows/instances/")
        if source["enrollment_flow"] in (flow["pk"], flow["slug"])
    )
    print("Google source enabled:", source["enabled"])
    print("Dedicated Google enrollment selected:", enrollment["slug"] == "google-source-enrollment")
    bindings = list(pages(f"flows/bindings/?target={source['enrollment_flow']}"))
    print("Enrollment stage orders:", sorted(binding["order"] for binding in bindings))
    for binding in bindings:
        stage = api(f"stages/all/{binding['stage']}/")
        kind = stage["component"]
        if kind == "ak-stage-user-write-form":
            write = api(f"stages/user_write/{binding['stage']}/")
            print("User-write mode:", write["user_creation_mode"])
            print("Creates inactive users:", write["create_users_as_inactive"])
    users = list(pages("core/users/"))
    print("Users with verified-Google marker:", sum(
        bool(user.get("attributes", {}).get("osinfra_google_email")) for user in users
    ))
    events = api("events/events/?ordering=-created&page_size=100")["results"]
    allowed_actions = {
        "login", "login_failed", "source_linked", "user_write", "policy_exception",
        "property_mapping_exception", "configuration_error", "flow_execution",
        "suspicious_request", "logout", "authorize_application", "source_login",
    }
    counts = Counter(event["action"] for event in events if event["action"] in allowed_actions)
    print("Recent authentication event counts:", dict(counts))
    for event in events:
        summary = diagnostics.summarize_error(event.get("context", {}))
        if summary:
            print("Redacted event diagnostic:", "; ".join(summary))


if __name__ == "__main__":
    diagnose(Path(sys.argv[1]))
