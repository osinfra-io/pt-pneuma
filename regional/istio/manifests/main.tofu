# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio//regional/manifests?ref=58e5a5e78db17bf753f5bceb0406aa1e525b8b79" # fix-dns-auto-allocate-deprecation

  common_istio_test_virtual_services = local.common_istio_test_virtual_services
  common_virtual_services            = {}
  failover_from_region               = local.failover_from_region
  failover_to_region                 = local.failover_to_region
  istio_test_virtual_services        = local.istio_test_virtual_services
  virtual_services                   = {}
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "datadog_aap_gateway_filter" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "EnvoyFilter"
    metadata = {
      name      = "datadog-aap-gateway-filter"
      namespace = "istio-ingress"
    }
    spec = {
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
                cluster_name = "pt-${module.helpers.region}-${module.helpers.zone}"
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
              name = "pt-${module.helpers.region}-${module.helpers.zone}"
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
                    cluster_name = "pt-${module.helpers.region}-${module.helpers.zone}"
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
