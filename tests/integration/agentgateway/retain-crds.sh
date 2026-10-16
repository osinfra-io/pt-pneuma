#!/usr/bin/env bash

set -euo pipefail

kubectl patch --local --filename=- --type=merge \
  --patch='{"metadata":{"annotations":{"helm.sh/resource-policy":"keep"}}}' \
  --output=json |
  jq --slurp --raw-output '
    if length == 0 then
      error("The CRD post-renderer produced no resources")
    elif any(.[]; .kind != "CustomResourceDefinition") then
      error("The CRD post-renderer received a non-CRD resource")
    else
      .[] | "---\n" + tojson
    end
  '
