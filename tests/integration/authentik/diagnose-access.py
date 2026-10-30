#!/usr/bin/env python3
"""Read owned server errors without emitting requests, identities, or credentials."""

import argparse
import json
import re
import subprocess
from urllib.parse import urlsplit


def summarize_error(record):
    event = record.get("event")
    if event == "Unable to fetch access token":
        try:
            response = json.loads(record.get("response", ""))
        except (ValueError, TypeError):
            return ["Unable to fetch access token (non-JSON response omitted)"]
        error = response.get("error")
        if error in (
            "invalid_grant", "invalid_client", "redirect_uri_mismatch",
            "unauthorized_client", "invalid_request", "access_denied",
        ):
            return [f"Google token exchange rejected: {error}"]
        return ["Unable to fetch access token (unrecognized response omitted)"]
    if event == "Authentication Failure":
        reason = record.get("reason")
        if reason in (
            "Could not retrieve token.", "Could not retrieve profile.",
            "Could not determine id.",
        ):
            return [f"Authentication Failure: {reason}"]
        return ["Authentication Failure (unrecognized reason omitted)"]
    if event in (
        "Invalid grant_type for provider",
        "Missing nonce for OpenID Request",
        "The request is otherwise malformed",
    ):
        return [event]
    exception = record.get("exception")
    if not exception:
        return []
    text = exception if isinstance(exception, str) else json.dumps(exception)
    result = []
    for filename, line, function in re.findall(
        r'File "([^"]+)", line (\d+), in ([A-Za-z0-9_<>]+)', text,
    ):
        result.append(f"{filename}:{line} in {function}")
    for name in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*(?:Error|Exception))\b", text):
        result.append(name)
    if "Application access requires a verified Google email" in text:
        result.append("Google profile did not satisfy the explicit email-verification check")
    return list(dict.fromkeys(result))


def summarize_record(record):
    result = summarize_error(record)
    context = record.get("context")
    if isinstance(context, dict):
        result.extend(summarize_error(context))
    status = record.get("status")
    path = urlsplit(str(record.get("path", record.get("event", "")))).path
    for prefix in (
        "/source/oauth/callback/", "/source/oauth/login/", "/application/o/authorize/",
        "/api/v3/flows/executor/", "/outpost.goauthentik.io/",
    ):
        if path.startswith(prefix) and isinstance(status, int):
            result.append(f"HTTP {status} on {prefix} (remaining path and query omitted)")
            break
    return list(dict.fromkeys(result))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--since", default="30m", help="Bounded kubectl log window (for example 3m)")
    args = parser.parse_args()
    command = ["kubectl", "--context=docker-desktop"]
    owner = subprocess.check_output(
        command + ["get", "configmap", "local-gateway-stack-owner",
                   "--namespace=kube-system", "--output=jsonpath={.data.owner}"],
        text=True, timeout=15,
    )
    if owner != "osinfra-local-gateway-stack":
        raise SystemExit("Access diagnostics require the owned local fixture")
    summaries = []
    for deployment in ("authentik-server", "authentik-worker"):
        logs = subprocess.check_output(
            command + ["logs", f"deployment/{deployment}", "--namespace=authentik",
                       "--all-containers=true", f"--since={args.since}", "--tail=2000"],
            text=True, timeout=30,
        )
        for line in logs.splitlines():
            if not line.startswith("{"):
                continue
            record = json.loads(line)
            summary = summarize_record(record)
            if summary:
                entry = [deployment, *summary]
                if entry not in summaries:
                    summaries.append(entry)
    if not summaries:
        raise SystemExit("No structured server traceback or known OAuth rejection found in the bounded log window")
    for summary in summaries:
        print("Redacted authentication diagnostic:")
        print("\n".join(summary))


if __name__ == "__main__":
    main()
