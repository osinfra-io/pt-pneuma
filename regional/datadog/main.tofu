# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=62a81283544eac8801598bdde712cabc7e9cdd53" # v0.4.3

  for_each = local.datadog_clusters

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = each.value.team_key
}

# Datadog Dashboard JSON Resource
# https://search.opentofu.org/provider/datadog/datadog/latest/docs/resources/dashboard_json

resource "datadog_dashboard_json" "gateway_auth" {
  dashboard = local.datadog_gateway_auth_dashboard_json
}

# Datadog Monitor Resource
# https://search.opentofu.org/provider/datadog/datadog/latest/docs/resources/monitor

resource "datadog_monitor" "authentik_error" {
  for_each = local.gateway_clusters

  include_tags = true
  message      = "Authentik is logging elevated errors for ${each.key}. Istio ext_authz fails closed, so sustained errors can block gateway traffic. Parent: osinfra-io/pt-pneuma#142."
  name         = "Authentik error spike - ${each.key}"
  priority     = 2
  query        = local.datadog_gateway_auth_monitor_queries[each.key].authentik_errors
  tags         = local.datadog_gateway_auth_monitor_tags[each.key]
  type         = "log alert"

  monitor_thresholds {
    critical = local.datadog_gateway_auth_monitor_thresholds.authentik_errors_critical
    warning  = local.datadog_gateway_auth_monitor_thresholds.authentik_errors_warning
  }
}

resource "datadog_monitor" "authentik_outpost_unavailable" {
  for_each = local.gateway_clusters

  include_tags      = true
  message           = "The Authentik proxy outpost has no ready replicas for ${each.key}. Istio ext_authz fails closed, so gateway traffic requiring auth will be denied until it recovers. Parent: osinfra-io/pt-pneuma#142."
  name              = "Authentik proxy outpost unavailable - ${each.key}"
  no_data_timeframe = 10
  notify_no_data    = true
  priority          = 1
  query             = local.datadog_gateway_auth_monitor_queries[each.key].authentik_outpost_unavailable
  tags              = local.datadog_gateway_auth_monitor_tags[each.key]
  type              = "metric alert"

  monitor_thresholds {
    critical = local.datadog_gateway_auth_monitor_thresholds.authentik_outpost_ready_replicas_critical
  }
}

resource "datadog_monitor" "authentik_unavailable" {
  for_each = local.gateway_clusters

  include_tags      = true
  message           = "Authentik has no ready server replicas for ${each.key}. Gateway authentication depends on Authentik for OIDC/JWKS, so user auth may fail. Parent: osinfra-io/pt-pneuma#142."
  name              = "Authentik unavailable - ${each.key}"
  no_data_timeframe = 10
  notify_no_data    = true
  priority          = 2
  query             = local.datadog_gateway_auth_monitor_queries[each.key].authentik_unavailable
  tags              = local.datadog_gateway_auth_monitor_tags[each.key]
  type              = "metric alert"

  monitor_thresholds {
    critical = local.datadog_gateway_auth_monitor_thresholds.authentik_ready_replicas_critical
  }
}

resource "datadog_monitor" "gateway_auth_jwt_rejection" {
  for_each = local.gateway_clusters

  include_tags = true
  message      = "Gateway is returning elevated JWT authentication failures (401) for ${each.key}. Check RequestAuthentication, JWKS availability, and recent client token failures. Parent: osinfra-io/pt-pneuma#142."
  name         = "Gateway auth JWT rejection spike - ${each.key}"
  priority     = 3
  query        = local.datadog_gateway_auth_monitor_queries[each.key].gateway_401
  tags         = local.datadog_gateway_auth_monitor_tags[each.key]
  type         = "log alert"

  monitor_thresholds {
    critical = local.datadog_gateway_auth_monitor_thresholds.gateway_401_critical
    warning  = local.datadog_gateway_auth_monitor_thresholds.gateway_401_warning
  }
}

resource "datadog_monitor" "gateway_auth_policy_denial" {
  for_each = local.gateway_clusters

  include_tags = true
  message      = "Gateway is returning elevated authorization denials (403) for ${each.key}. Check Istio AuthorizationPolicy, Authentik forward-auth decisions, and route auth policy changes. Parent: osinfra-io/pt-pneuma#142."
  name         = "Gateway auth policy denial spike - ${each.key}"
  priority     = 3
  query        = local.datadog_gateway_auth_monitor_queries[each.key].gateway_403
  tags         = local.datadog_gateway_auth_monitor_tags[each.key]
  type         = "log alert"

  monitor_thresholds {
    critical = local.datadog_gateway_auth_monitor_thresholds.gateway_403_critical
    warning  = local.datadog_gateway_auth_monitor_thresholds.gateway_403_warning
  }
}
