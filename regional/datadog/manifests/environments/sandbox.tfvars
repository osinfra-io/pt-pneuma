# The cluster agent measures 192Mi against the module's 256Mi default limit, which left too little
# headroom and produced repeated OOMKills (exit 137) on both single-node sandbox clusters. Memory
# is incompressible, so the restart loop is the only possible outcome rather than degraded service.

kubernetes_datadog_operator_cluster_agent_limits_memory = "384Mi"

# The Node Agent CR's previous `containers.all` resource override was ignored because the Operator
# expects overrides keyed by actual container name. The agent used 175m CPU / 203Mi memory and
# system-probe used 171m / 565Mi; both were timing out their probes under node contention.
# Requests grant CPU shares while the limits leave headroom above observed usage.

kubernetes_datadog_operator_node_agent_container_resources = {
  agent = {
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
  }
  "system-probe" = {
    limits = {
      cpu    = "500m"
      memory = "768Mi"
    }
    requests = {
      cpu    = "100m"
      memory = "640Mi"
    }
  }
}
