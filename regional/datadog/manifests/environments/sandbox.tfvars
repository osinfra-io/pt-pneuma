# The cluster agent measures 192Mi against the module's 256Mi default limit, which left too little
# headroom and produced repeated OOMKills (exit 137) on both single-node sandbox clusters. Memory
# is incompressible, so the restart loop is the only possible outcome rather than degraded service.

kubernetes_datadog_operator_cluster_agent_limits_memory = "384Mi"
