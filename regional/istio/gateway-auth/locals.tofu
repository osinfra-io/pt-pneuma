# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  callback_paths = [
    "/outpost.goauthentik.io",
    "/outpost.goauthentik.io/*",
  ]

  callback_routes = {
    for host in distinct([for policy in values(var.policies) : policy.host if policy.mode == "browser"]) :
    "authentik-callback-${substr(sha1(host), 0, 8)}" => {
      backend_namespace = var.outpost_namespace
      backend_port      = var.outpost_service_port
      backend_service   = var.outpost_service_name
      host              = host
      path              = "/outpost.goauthentik.io"
    }
  }

  custom_authorization_policy_manifests = {
    for key, policy in local.resolved_policies :
    key => {
      apiVersion = "security.istio.io/v1"
      kind       = "AuthorizationPolicy"
      metadata = {
        name      = policy.custom_authorization_policy_name
        namespace = var.gateway_namespace
      }
      spec = {
        action = "CUSTOM"
        provider = {
          name = var.extension_provider_name
        }
        rules = [
          {
            to = [
              {
                operation = {
                  hosts    = [policy.host]
                  notPaths = policy.exempt_paths
                  paths    = policy.paths
                }
              }
            ]
          }
        ]
        targetRefs = [
          {
            group = "gateway.networking.k8s.io"
            kind  = "Gateway"
            name  = var.gateway_name
          }
        ]
      }
    }
    if policy.mode == "browser"
  }

  default_exempt_paths = concat(local.health_paths, local.callback_paths)

  extension_provider = {
    envoyExtAuthzHttp = {
      failOpen = false

      headersToDownstreamOnAllow = [
        "cookie",
      ]

      headersToDownstreamOnDeny = [
        "content-type",
        "set-cookie",
      ]

      headersToUpstreamOnAllow = [
        "set-cookie",
        "x-authentik-*",
      ]

      includeRequestHeadersInCheck = [
        "cookie",
      ]

      pathPrefix = var.outpost_path_prefix
      port       = var.outpost_service_port
      service    = "${var.outpost_service_name}.${var.outpost_namespace}.svc.cluster.local"
    }

    name = var.extension_provider_name
  }

  health_paths = [
    "/health",
    "/healthz",
    "/live",
    "/livez",
    "/ready",
    "/readyz",
  ]

  inbound_header_strip_filter_manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "EnvoyFilter"
    metadata = {
      annotations = {
        "galley.istio.io/analyze-suppress" = "IST0133"
      }
      name      = "gateway-authentik-inbound-header-strip"
      namespace = var.gateway_namespace
    }
    spec = {
      # Remove untrusted identity before ext_authz adds the authenticated identity.
      priority = 5

      configPatches = [
        {
          applyTo = "HTTP_FILTER"
          match = {
            context = "GATEWAY"
            listener = {
              filterChain = {
                filter = {
                  name = "envoy.filters.network.http_connection_manager"
                  subFilter = {
                    name = "envoy.filters.http.ext_authz"
                  }
                }
              }
            }
          }
          patch = {
            operation = "INSERT_BEFORE"
            value = {
              name = "envoy.filters.http.lua"
              typed_config = {
                "@type"    = "type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua"
                inlineCode = <<-EOT
                  function envoy_on_request(handle)
                    local remove = {}
                    for key, value in pairs(handle:headers()) do
                      if string.sub(string.lower(key), 1, 12) == "x-authentik-" then
                        remove[#remove + 1] = key
                      end
                    end
                    for _, key in ipairs(remove) do
                      handle:headers():remove(key)
                    end
                  end
                EOT
              }
            }
          }
        }
      ]

      workloadSelector = {
        labels = {
          "gateway.networking.k8s.io/gateway-name" = var.gateway_name
        }
      }
    }
  }

  resolved_policies = {
    for key, policy in var.policies :
    key => merge(policy, {
      custom_authorization_policy_name = "gateway-auth-${substr(sha1("${key}-custom"), 0, 8)}"
      deny_authorization_policy_name   = "gateway-auth-${substr(sha1("${key}-deny"), 0, 8)}"
      exempt_paths = distinct(concat(
        local.default_exempt_paths,
        policy.path == "/" ? [] : [
          for path in local.default_exempt_paths :
          "${trimsuffix(policy.path, "/")}${path}"
        ],
        policy.public_paths,
      ))
      paths = policy.path == "/" ? ["/*"] : [
        trimsuffix(policy.path, "/"),
        "${trimsuffix(policy.path, "/")}/*",
      ]
    })
  }
}
