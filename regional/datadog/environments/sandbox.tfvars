# The operator normally uses 44-72m CPU and 35-40Mi memory, but reconciliation bursts reached
# 839m CPU and prior 64Mi memory limits caused repeated OOMKills. Reserve steady usage and leave
# enough limit headroom for reconciliations without letting one controller dominate the node.

kubernetes_datadog_operator_limits_cpu      = "1"
kubernetes_datadog_operator_limits_memory   = "128Mi"
kubernetes_datadog_operator_requests_cpu    = "100m"
kubernetes_datadog_operator_requests_memory = "64Mi"
