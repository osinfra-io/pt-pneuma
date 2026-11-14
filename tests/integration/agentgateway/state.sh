#!/usr/bin/env bash

assert_default_workspace() {
  local stage="$1"
  local workspace

  workspace="$(tofu_stage "${stage}" workspace show)" || {
    echo "Could not determine ${stage} workspace; refusing to inspect or adopt resources." >&2
    exit 1
  }
  if [ "${workspace}" != default ]; then
    echo "Non-default ${stage} workspace '${workspace}' is unsupported; refusing to inspect or adopt resources." >&2
    exit 1
  fi
}

state_has() {
  local stage="$1"
  local address="$2"
  local addresses
  local state_file="${WORK_DIR}/${stage}.tfstate"

  assert_default_workspace "${stage}"

  if [ ! -e "${state_file}" ] && [ ! -L "${state_file}" ]; then
    if [ -d "${WORK_DIR}" ] && [ -r "${WORK_DIR}" ] && [ -x "${WORK_DIR}" ]; then
      return 1
    fi
    echo "Could not inspect ${stage} state directory; refusing to inspect or adopt resources." >&2
    exit 1
  fi

  addresses="$(tofu_stage "${stage}" state list)" || {
    echo "Could not read ${stage} state; refusing to inspect or adopt resources." >&2
    exit 1
  }
  grep --fixed-strings --line-regexp --quiet -- "${address}" <<<"${addresses}"
}
