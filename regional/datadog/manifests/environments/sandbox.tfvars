# The cluster agent uses 35-40m CPU / 190-194Mi memory in steady state and peaks around 221m /
# 251Mi. Requests cover normal operation; limits retain headroom for collection bursts.

kubernetes_datadog_operator_cluster_agent_limits_cpu      = "500m"
kubernetes_datadog_operator_cluster_agent_limits_memory   = "384Mi"
kubernetes_datadog_operator_cluster_agent_requests_cpu    = "100m"
kubernetes_datadog_operator_cluster_agent_requests_memory = "256Mi"

# The node agent uses 167-177m CPU / 192-194Mi memory and system-probe uses 103-131m / 514-538Mi.
# Their seven-day CPU peaks were 858m and 697m; one-core limits preserve burst capacity while
# requests reserve their steady shares.

kubernetes_datadog_operator_node_agent_container_resources = {
  agent = {
    limits = {
      cpu    = "1"
      memory = "384Mi"
    }
    requests = {
      cpu    = "250m"
      memory = "256Mi"
    }
  }
  "system-probe" = {
    limits = {
      cpu    = "1"
      memory = "768Mi"
    }
    requests = {
      cpu    = "200m"
      memory = "640Mi"
    }
  }
}
