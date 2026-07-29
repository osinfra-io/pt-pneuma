# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  datadog_auth_decision_log_queries = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => {
      gateway_401 = "service:istio-gateway env:${module.core_helpers.environment} cluster_name:${cluster_name} @http.status_code:401"
      gateway_403 = "service:istio-gateway env:${module.core_helpers.environment} cluster_name:${cluster_name} @http.status_code:403"
      authentik   = "service:authentik env:${module.core_helpers.environment} cluster_name:${cluster_name}"
    }
  }

  # Auth decision logs are collected by the DatadogAgent's containerCollectAll baseline.
  # These filters document the log streams the monitors and dashboard use for decisions.
  datadog_auth_log_sources = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => {
      gateway     = "Istio gateway Envoy access logs via service:istio-gateway"
      authentik   = "Authentik IdP and embedded-outpost auth-decision logs via service:authentik"
      query_scope = "env:${module.core_helpers.environment} cluster_name:${cluster_name}"
    }
  }

  # Clusters in this zone whose owning team has opted in to platform-managed Datadog.
  datadog_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if try(module.core_helpers.teams[cluster_config.team_key].enable_platform_managed_datadog, false)
  }

  datadog_gateway_auth_dashboard_json = jsonencode({
    layout_type = "ordered"
    title       = "Gateway auth - ${local.zone} - ${module.core_helpers.environment}"
    widgets = concat(
      [
        {
          definition = {
            content = <<-EOT
            Gateway auth visibility for ${local.zone} (${module.core_helpers.environment}).

            Auth decision logs are collected cluster-wide by the Datadog Agent and filtered by service tags:
            - service:istio-gateway for Envoy access logs, including RequestAuthentication 401s and AuthorizationPolicy/ext_authz 403s.
            - service:authentik for Authentik IdP health, OIDC/JWKS, and embedded-outpost forward-auth decisions.
            EOT
            type    = "note"
          }
        }
      ],
      flatten([
        for cluster_name in keys(local.gateway_clusters) : [
          {
            definition = {
              requests = [
                {
                  display_type = "bars"
                  log_query = {
                    compute = {
                      aggregation = "count"
                    }
                    group_by = [
                      {
                        facet = "@http.status_code"
                        limit = 5
                        sort = {
                          aggregation = "count"
                          order       = "desc"
                        }
                      }
                    ]
                    index = "*"
                    search = {
                      query = "service:istio-gateway env:${module.core_helpers.environment} cluster_name:${cluster_name} @http.status_code:(401 OR 403)"
                    }
                  }
                }
              ]
              title = "${cluster_name} gateway 401/403 auth decisions"
              type  = "timeseries"
            }
          },
          {
            definition = {
              requests = [
                {
                  display_type = "line"
                  log_query = {
                    compute = {
                      aggregation = "count"
                    }
                    index = "*"
                    search = {
                      query = "service:authentik env:${module.core_helpers.environment} cluster_name:${cluster_name} (status:error OR @http.status_code:[500 TO 599])"
                    }
                  }
                }
              ]
              title = "${cluster_name} Authentik errors"
              type  = "timeseries"
            }
          },
          {
            definition = {
              requests = [
                {
                  display_type = "line"
                  q            = "avg:envoy.cluster.upstream_rq_time{cluster_name:${cluster_name},env:${module.core_helpers.environment},service:istio-gateway,envoy_cluster_name:*authentik-server*}.rollup(avg)"
                }
              ]
              title = "${cluster_name} ext_authz upstream latency"
              type  = "timeseries"
            }
          },
          {
            definition = {
              requests = [
                {
                  display_type = "line"
                  q            = "sum:kubernetes_state.deployment.replicas_available{cluster_name:${cluster_name},kube_namespace:authentik,kube_deployment:authentik-server}"
                }
              ]
              title = "${cluster_name} Authentik server ready replicas"
              type  = "timeseries"
            }
          },
          {
            definition = {
              columns = [
                "timestamp",
                "status",
                "service",
                "message",
              ]
              indexes = ["*"]
              query   = "env:${module.core_helpers.environment} cluster_name:${cluster_name} (service:istio-gateway OR service:authentik)"
              title   = "${cluster_name} auth decision logs"
              type    = "log_stream"
            }
          },
        ]
      ])
    )
  })

  # Thresholds favor early warning without paging on isolated user mistakes:
  # sustained 401/403 bursts are suspicious, while any sustained auth dependency
  # outage pages because Istio ext_authz fails closed.
  datadog_gateway_auth_monitor_thresholds = {
    authentik_errors_critical         = 10
    authentik_errors_warning          = 5
    authentik_ready_replicas_critical = 1
    gateway_401_critical              = 50
    gateway_401_warning               = 25
    gateway_403_critical              = 25
    gateway_403_warning               = 10
  }

  datadog_gateway_auth_monitor_tags = {
    for cluster_name, cluster_config in local.gateway_clusters :
    cluster_name => [
      "cluster:${cluster_name}",
      "env:${module.core_helpers.environment}",
      "service:gateway-auth",
      "team:${cluster_config.team_key}",
      "zone:${local.zone}",
    ]
  }

  datadog_gateway_auth_monitor_queries = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => {
      authentik_errors      = "logs(\"service:authentik env:${module.core_helpers.environment} cluster_name:${cluster_name} (status:error OR @http.status_code:[500 TO 599])\").index(\"*\").rollup(\"count\").last(\"5m\") > ${local.datadog_gateway_auth_monitor_thresholds.authentik_errors_critical}"
      authentik_unavailable = "min(last_5m):sum:kubernetes_state.deployment.replicas_available{cluster_name:${cluster_name},kube_namespace:authentik,kube_deployment:authentik-server} < ${local.datadog_gateway_auth_monitor_thresholds.authentik_ready_replicas_critical}"
      gateway_401           = "logs(\"${local.datadog_auth_decision_log_queries[cluster_name].gateway_401}\").index(\"*\").rollup(\"count\").last(\"5m\") > ${local.datadog_gateway_auth_monitor_thresholds.gateway_401_critical}"
      gateway_403           = "logs(\"${local.datadog_auth_decision_log_queries[cluster_name].gateway_403}\").index(\"*\").rollup(\"count\").last(\"5m\") > ${local.datadog_gateway_auth_monitor_thresholds.gateway_403_critical}"
    }
  }

  gateway_clusters = {
    for cluster_name, cluster_config in local.datadog_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-datadog-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
