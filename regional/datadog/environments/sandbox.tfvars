# The operator only reconciles DatadogAgent resources and measures 4m CPU / 29Mi memory. Its
# default 100m request is what exhausted the single-node sandbox clusters and left the operator
# pod Pending, which failed the Datadog apply. The limit is left at the module default.

kubernetes_datadog_operator_requests_cpu = "25m"
