#!/usr/bin/env bash

# Single source of truth for local gateway hostnames (shared/hostnames.txt).
# The bare localhost SAN exists only for the Google OAuth callback.
LOCAL_HOSTNAMES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hostnames.txt"
readonly LOCAL_HOSTNAMES_FILE

certificate_subject_alt_names() {
  local names="DNS:localhost" hostname
  while IFS= read -r hostname; do
    [ -n "${hostname}" ] && names+=",DNS:${hostname}"
  done <"${LOCAL_HOSTNAMES_FILE}"
  printf '%s\n' "${names}"
}
