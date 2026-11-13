#!/usr/bin/env bash

state_has() {
  local stage="$1"
  local address="$2"
  local addresses

  addresses="$(tofu_stage "${stage}" state list)" || {
    echo "Could not read ${stage} state; refusing to inspect or adopt resources." >&2
    exit 1
  }
  grep --fixed-strings --line-regexp --quiet -- "${address}" <<<"${addresses}"
}
