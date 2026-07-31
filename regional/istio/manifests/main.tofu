# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio//regional/manifests?ref=a1521a2eca85085be58664633502dd6a4c4434a0" # v0.5.5

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  failover_from_region = local.regions[each.key]
  failover_to_region   = local.failover_to_region[each.key]
  routes               = local.routes[each.key]
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "datadog_aap_gateway_filter" {
  for_each = local.gateway_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "EnvoyFilter"
    metadata = {
      annotations = {
        # IST0133: EnvoyFilters are inherently low-level; this warning is expected.
        "galley.istio.io/analyze-suppress" = "IST0133"
      }
      name      = "datadog-aap-gateway-filter"
      namespace = "istio-ingress"
    }
    spec = {
      # Priority ensures consistent ordering when using relative patch operations.
      # Lower numbers are applied first; 10 is early enough to run before other filters.
      priority = 10

      configPatches = [
        {
          applyTo = "CLUSTER"
          match = {
            cluster = {
              service = "*"
            }
            context = "GATEWAY"
          }
          patch = {
            operation = "ADD"
            value = {
              connect_timeout        = "0.2s"
              http2_protocol_options = {}
              lb_policy              = "ROUND_ROBIN"
              load_assignment = {
                cluster_name = "pt-${regex("(us-[a-z0-9]+-[a-z])$", each.key)[0]}"
                endpoints = [
                  {
                    lb_endpoints = [
                      {
                        endpoint = {
                          address = {
                            socket_address = {
                              address    = "datadog-aap-extproc-service.istio-ingress.svc.cluster.local"
                              port_value = 443
                            }
                          }
                        }
                      }
                    ]
                  }
                ]
              }
              name = "pt-${regex("(us-[a-z0-9]+-[a-z])$", each.key)[0]}"
              transport_socket = {
                name = "envoy.transport_sockets.tls"
                typed_config = {
                  "@type" = "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext"
                  sni     = "localhost"
                }
              }

              type = "STRICT_DNS"
            }
          }
        },
        {
          applyTo = "HTTP_FILTER"
          match = {
            context = "GATEWAY"
            listener = {
              filterChain = {
                filter = {
                  name = "envoy.filters.network.http_connection_manager"
                  subFilter = {
                    name = "envoy.filters.http.router"
                  }
                }
              }
            }
          }
          patch = {
            operation = "INSERT_BEFORE"
            value = {
              name = "envoy.filters.http.ext_proc"
              typed_config = {
                "@type"            = "type.googleapis.com/envoy.extensions.filters.http.ext_proc.v3.ExternalProcessor"
                failure_mode_allow = true
                grpc_service = {
                  envoy_grpc = {
                    cluster_name = "pt-${regex("(us-[a-z0-9]+-[a-z])$", each.key)[0]}"
                  }
                  timeout = "0.5s"
                }
              }
            }
          }
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "gateway_auth_custom_authorization_policy" {
  for_each = local.gateway_auth_custom_authorization_policy_manifests

  provider = kubernetes.by_cluster[local.gateway_auth_authorization_policies[each.key].cluster_name]

  manifest = each.value
}

resource "kubernetes_manifest" "gateway_auth_required_claim_authorization_policy" {
  for_each = local.gateway_auth_required_claim_authorization_policy_manifests

  provider = kubernetes.by_cluster[local.gateway_auth_authorization_policies[each.key].cluster_name]

  manifest = each.value
}

resource "kubernetes_manifest" "gateway_auth_request_authentication" {
  for_each = local.gateway_auth_request_authentication_manifests

  provider = kubernetes.by_cluster[each.key]

  manifest = each.value
}

resource "kubernetes_manifest" "gateway_authentik_inbound_header_strip_filter" {
  for_each = local.gateway_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "EnvoyFilter"
    metadata = {
      annotations = {
        # IST0133: EnvoyFilters are inherently low-level; this warning is expected.
        "galley.istio.io/analyze-suppress" = "IST0133"
      }
      name      = "gateway-authentik-inbound-header-strip"
      namespace = "istio-ingress"
    }
    spec = {
      # Run before ext_authz so client-supplied x-authentik-* headers are removed prior to the
      # forward-auth decision. The embedded outpost re-adds trusted x-authentik-* headers on
      # allow, which are forwarded upstream via headersToUpstreamOnAllow. This prevents a client
      # from spoofing identity headers to a backend that trusts the gateway.
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
        labels = local.gateway_auth_gateway_selector
      }
    }
  }
}

resource "kubernetes_manifest" "gateway_authentik_jwt_bypass_filter" {
  for_each = local.gateway_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "EnvoyFilter"
    metadata = {
      annotations = {
        # IST0133: EnvoyFilters are inherently low-level; this warning is expected.
        "galley.istio.io/analyze-suppress" = "IST0133"
      }
      name      = "gateway-authentik-jwt-bypass"
      namespace = "istio-ingress"
    }
    spec = {
      # The gateway-wide RequestAuthentication (gateway-authentik-jwt) is workload-scoped and
      # rejects any request carrying an Authorization: Bearer token that is not a valid JWT for
      # the configured issuer. Authentik is the IdP: it authenticates its own API and OIDC token
      # clients (including the authentik-config OpenTofu provider) with opaque Bearer tokens that
      # are not JWTs. This disables the jwt_authn filter for the Authentik virtual host only, so
      # those opaque tokens pass through to Authentik while every other host still enforces JWT.
      configPatches = [
        {
          applyTo = "VIRTUAL_HOST"
          match = {
            context = "GATEWAY"
            routeConfiguration = {
              vhost = {
                name = "${local.authentik_hostname}:443"
              }
            }
          }
          patch = {
            operation = "MERGE"
            value = {
              typed_per_filter_config = {
                "envoy.filters.http.jwt_authn" = {
                  "@type"  = "type.googleapis.com/envoy.extensions.filters.http.jwt_authn.v3.PerRouteConfig"
                  disabled = true
                }
              }
            }
          }
        }
      ]

      workloadSelector = {
        labels = local.gateway_auth_gateway_selector
      }
    }
  }
}
