#!/usr/bin/env bash

# Ownership marker for the dedicated local gateway-stack cluster. Changing these
# values requires a teardown and fresh setup of every component.

readonly OWNER_CONFIGMAP="local-gateway-stack-owner"
readonly OWNER_NAMESPACE="kube-system"
readonly OWNER_VALUE="osinfra-local-gateway-stack"
