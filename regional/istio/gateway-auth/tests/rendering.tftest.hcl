# Test
# https://opentofu.org/docs/cli/commands/test

run "browser_and_api_intent" {
  command = plan

  variables {
    policies = {
      cluster-browser = {
        host            = "pneuma.localhost"
        path            = "/istio-test/"
        public_paths    = ["/istio-test/metadata", "/health"]
        required_groups = ["local-users"]
      }
      cluster-api = {
        audiences       = ["diagnostics"]
        host            = "api.localhost"
        mode            = "api-jwt"
        path            = "/api"
        required_groups = ["api-users"]
        required_roles  = ["reader"]
      }
      cluster-public = {
        host = "public.localhost"
        mode = "public"
        path = "/"
      }
    }
  }

  assert {
    condition     = keys(output.custom_authorization_policy_manifests) == ["cluster-browser"]
    error_message = "Only browser policies may generate CUSTOM authorization."
  }

  assert {
    condition = output.custom_authorization_policy_manifests["cluster-browser"].metadata.name == "gateway-auth-${substr(sha1("cluster-browser-custom"), 0, 8)}" && output.custom_authorization_policy_manifests["cluster-browser"].metadata.namespace == "istio-ingress" && output.custom_authorization_policy_manifests["cluster-browser"].spec.targetRefs == [{
      group = "gateway.networking.k8s.io"
      kind  = "Gateway"
      name  = "gateway"
    }]
    error_message = "The production names, namespace, and Gateway targetRefs must be preserved."
  }

  assert {
    condition     = output.custom_authorization_policy_manifests["cluster-browser"].spec.rules[0].to[0].operation.paths == tolist(["/istio-test", "/istio-test/*"])
    error_message = "Browser policy paths must trim trailing slashes and cover nested paths."
  }

  assert {
    condition = output.resolved_policies["cluster-browser"].exempt_paths == tolist([
      "/health", "/healthz", "/live", "/livez", "/ready", "/readyz",
      "/outpost.goauthentik.io", "/outpost.goauthentik.io/*",
      "/istio-test/health", "/istio-test/healthz", "/istio-test/live", "/istio-test/livez", "/istio-test/ready", "/istio-test/readyz",
      "/istio-test/outpost.goauthentik.io", "/istio-test/outpost.goauthentik.io/*",
      "/istio-test/metadata",
    ])
    error_message = "Global/nested health, callback, and explicit public exemptions must preserve ordering and deduplicate."
  }

  assert {
    condition     = output.resolved_policies["cluster-browser"].required_groups == tolist(["local-users"]) && !can(output.custom_authorization_policy_manifests["cluster-browser"].spec.rules[0].when)
    error_message = "Browser group intent is preserved for Authentik, not incorrectly enforced as JWT claims."
  }

  assert {
    condition     = output.resolved_policies["cluster-api"].audiences == tolist(["diagnostics"]) && output.resolved_policies["cluster-api"].required_groups == tolist(["api-users"]) && output.resolved_policies["cluster-api"].required_roles == tolist(["reader"]) && output.resolved_policies["cluster-api"].deny_authorization_policy_name == "gateway-auth-${substr(sha1("cluster-api-deny"), 0, 8)}"
    error_message = "API JWT claim intent and DENY policy identity must not be altered."
  }

  assert {
    condition     = length(output.callback_routes) == 1 && output.callback_routes["authentik-callback-${substr(sha1("pneuma.localhost"), 0, 8)}"].host == "pneuma.localhost"
    error_message = "Callback routes must be created for browser hosts only with existing hashed names."
  }

  assert {
    condition = output.extension_provider.name == "authentik" && output.extension_provider.envoyExtAuthzHttp == {
      failOpen                   = false
      headersToDownstreamOnAllow = ["cookie"]
      headersToDownstreamOnDeny  = ["content-type", "set-cookie"]
      headersToUpstreamOnAllow   = ["set-cookie", "x-authentik-*"]
      includeRequestHeadersInCheck = [
        "cookie",
      ]
      pathPrefix = "/outpost.goauthentik.io/auth/envoy"
      port       = 80
      service    = "authentik-server.authentik.svc.cluster.local"
    }
    error_message = "Forward-auth must fail closed and preserve cookie/trusted identity propagation."
  }

  assert {
    condition     = output.inbound_header_strip_filter_manifest.spec.priority == 5 && output.inbound_header_strip_filter_manifest.spec.configPatches[0].patch.operation == "INSERT_BEFORE" && output.inbound_header_strip_filter_manifest.spec.configPatches[0].match.listener.filterChain.filter.subFilter.name == "envoy.filters.http.ext_authz" && strcontains(output.inbound_header_strip_filter_manifest.spec.configPatches[0].patch.value.typed_config.inlineCode, "string.sub(string.lower(key), 1, 12)") && strcontains(output.inbound_header_strip_filter_manifest.spec.configPatches[0].patch.value.typed_config.inlineCode, "handle:headers():remove(key)")
    error_message = "Case-insensitive x-authentik-* stripping must execute before ext_authz."
  }
}

run "root_route_and_local_coordinates" {
  command = plan

  variables {
    extension_provider_name = "local-authentik"
    gateway_name            = "local-gateway"
    gateway_namespace       = "local-ingress"
    outpost_namespace       = "local-authentik"
    outpost_service_name    = "local-outpost"
    outpost_service_port    = 9000
    policies = {
      root = {
        host = "root.localhost"
        path = "/"
      }
      nested = {
        host = "root.localhost"
        path = "/other"
      }
    }
  }

  assert {
    condition     = output.resolved_policies["root"].paths == tolist(["/*"]) && length(output.resolved_policies["root"].exempt_paths) == 8 && length(output.callback_routes) == 1
    error_message = "Root paths must not duplicate exemptions and callback hosts must deduplicate."
  }

  assert {
    condition     = output.extension_provider.envoyExtAuthzHttp.service == "local-outpost.local-authentik.svc.cluster.local" && output.extension_provider.envoyExtAuthzHttp.port == 9000 && output.custom_authorization_policy_manifests["root"].spec.provider.name == "local-authentik" && output.inbound_header_strip_filter_manifest.metadata.namespace == "local-ingress" && output.inbound_header_strip_filter_manifest.spec.workloadSelector.labels["gateway.networking.k8s.io/gateway-name"] == "local-gateway"
    error_message = "Local coordinates must configure the same renderer without production discovery."
  }
}

run "unknown_mode_fails_closed" {
  command = plan

  variables {
    policies = {
      invalid = {
        host = "pneuma.localhost"
        mode = "browesr"
        path = "/"
      }
    }
  }

  expect_failures = [var.policies]
}

run "overbroad_public_paths_fail_closed" {
  command = plan

  variables {
    policies = {
      invalid = {
        host         = "pneuma.localhost"
        path         = "/"
        public_paths = ["/", "/*", "*", "relative"]
      }
    }
  }

  expect_failures = [var.policies]
}

run "empty_policies" {
  command = plan

  assert {
    condition     = length(output.custom_authorization_policy_manifests) == 0 && length(output.callback_routes) == 0
    error_message = "No routes should create no policies or callbacks."
  }
}
