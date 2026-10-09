# Gateway Auth Rendering Module (osinfra.io)
# https://github.com/osinfra-io/pt-pneuma

module "gateway_auth" {
  source = "../gateway-auth"

  for_each = local.gateway_clusters

  application_group_members = module.team_access.application_group_members
  extension_provider_name   = local.authentik_extension_provider_name
  outpost_namespace         = local.authentik_namespace
  policies                  = local.gateway_auth_browser_policy_inputs[each.key]
}

module "team_access" {
  source = "../gateway-auth/team-access"

  environment = module.core_helpers.environment
  teams       = module.core_helpers.teams
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio//regional/manifests?ref=127a5f69eed936a06e9faaa826834c5ff0daff9c" # unreleased authentik-application-access test pin

  depends_on = [
    kubernetes_namespace_v1.istio_test_gateway_stub,
    kubernetes_service_v1.istio_test_gateway_stub,
  ]

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

resource "kubernetes_manifest" "gateway_authentik_application_access_filter" {
  for_each = local.gateway_auth_application_access_filter_manifests

  provider = kubernetes.by_cluster[each.value.cluster_name]

  manifest = each.value.manifest
}

resource "kubernetes_manifest" "gateway_authentik_inbound_header_strip_filter" {
  for_each = local.gateway_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = module.gateway_auth[each.key].inbound_header_strip_filter_manifest
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

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "istio_test_gateway_stub" {
  for_each = local.gateway_stub_namespaces

  provider = kubernetes.by_cluster[local.gateway_cluster]

  metadata {
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }

    name = each.key
  }
}

# Kubernetes Service Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "istio_test_gateway_stub" {
  for_each = local.gateway_stub_services

  depends_on = [kubernetes_namespace_v1.istio_test_gateway_stub]
  provider   = kubernetes.by_cluster[local.gateway_cluster]

  metadata {
    # Istio uses the local cluster's service scope, so the stub must be global too or remote
    # endpoints are never merged.
    labels = {
      "istio.io/global" = "true"
    }

    name      = each.value.service
    namespace = each.value.namespace
  }

  spec {
    # Selectorless: endpoints are populated by Istio multicluster discovery from the remote team
    # cluster, so no pod selector is set here.

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# Terraform Data Resource
# https://search.opentofu.org/provider/hashicorp/terraform/latest/docs/resources/data
# Fail closed if a route auth policy declares an unknown mode or an over-broad public_paths entry;
# either would silently leave a route unauthenticated.

resource "terraform_data" "gateway_auth_policy_validation" {
  lifecycle {
    precondition {
      condition     = length(local.gateway_auth_invalid_mode_route_keys) == 0
      error_message = "Route auth policies with an unknown mode (must be one of ${join(", ", local.gateway_auth_enforced_modes)}, or \"public\"): ${join(", ", local.gateway_auth_invalid_mode_route_keys)}."
    }

    precondition {
      condition     = length(local.gateway_auth_invalid_public_path_route_keys) == 0
      error_message = "Route auth policies with an invalid public_paths entry (each must be a concrete prefix starting with \"/\" and may not be \"/\", \"/*\" or \"*\"): ${join(", ", local.gateway_auth_invalid_public_path_route_keys)}."
    }
  }
}
