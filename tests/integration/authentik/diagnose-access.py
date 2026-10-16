#!/usr/bin/env python3
"""Read owned server errors without emitting requests, identities, or credentials."""

import json
import re
import subprocess


def summarize_error(record):
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


def main():
    command = ["kubectl", "--context=docker-desktop"]
    owner = subprocess.check_output(
        command + ["get", "configmap", "local-gateway-stack-owner",
                   "--namespace=kube-system", "--output=jsonpath={.data.owner}"],
        text=True, timeout=15,
    )
    if owner != "osinfra-local-gateway-stack":
        raise SystemExit("Access diagnostics require the owned local fixture")
    logs = subprocess.check_output(
        command + ["logs", "deployment/authentik-server", "--namespace=authentik",
                   "--all-containers=true", "--since=15m", "--tail=500"],
        text=True, timeout=30,
    )
    summaries = []
    for line in logs.splitlines():
        if not line.startswith("{"):
            continue
        record = json.loads(line)
        summary = summarize_error(record)
        if summary and summary not in summaries:
            summaries.append(summary)
    if not summaries:
        raise SystemExit("No structured server traceback found in the bounded log window")
    for summary in summaries:
        print("Server exception frames and types:")
        print("\n".join(summary))


if __name__ == "__main__":
    main()
