# The operator only reconciles DatadogAgent resources and measures 4m CPU / 29Mi memory. Its
# default 100m request is what exhausted the single-node sandbox clusters and left the operator
# pod Pending, which failed the Datadog apply.

kubernetes_datadog_operator_requests_cpu = "25m"

# Steady state memory has since grown to 59Mi, which the module's 64Mi default limit cut into
# directly: the operator was OOMKilled 124 times on us-east1-b and 132 times on us-east4-a. The
# restart loop also burned ~59m of CPU on a node already at ~100% actual CPU, so raising this
# limit gives capacity back rather than consuming it.

kubernetes_datadog_operator_limits_memory = "128Mi"
