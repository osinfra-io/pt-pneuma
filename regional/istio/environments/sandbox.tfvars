# Sandbox runs a single e2-standard-2 node per cluster, so the ambient data plane's default
# reservations - ztunnel 250m, istio-cni 100m and the east-west gateway 100m - consume roughly
# a quarter of the node's allocatable CPU on their own. Measured usage is 5m, 1m and 4m
# respectively. Data plane limits are left at the module defaults so every component can still
# burst; the istiod limits below are the one exception and are raised for the reason given there.

kubernetes_istio_cni_cpu_requests                  = "25m"
kubernetes_istio_cni_memory_requests               = "32Mi"
kubernetes_istio_east_west_gateway_cpu_requests    = "25m"
kubernetes_istio_east_west_gateway_memory_requests = "64Mi"

# One istiod replica. The HPA's CPU target is measured against the pilot CPU request, so a 10m
# request makes ordinary control plane activity read as several hundred percent utilization and
# pins istiod at the maximum. On a single node those extra replicas cost ~55Mi each and provide
# no availability benefit.

kubernetes_istio_pilot_autoscale_max = 1

# The module's default 25m CPU limit is below istiod's idle draw (23-29m measured with a single
# replica and only the istio-test workload). Throttling starved the readiness probe, which failed
# 7246 times over 10 hours and left istiod NotReady for 14 hours on both clusters. Because a
# NotReady istiod is dropped from its Service endpoints, ztunnel lost XDS and its DaemonSet
# rollout wedged behind maxUnavailable: 0. Requests are raised alongside the limits so the control
# plane keeps real CPU shares on a node that runs at ~100% actual CPU, and so that 78Mi of steady
# state memory is not a 64Mi limit away from an OOMKill.

kubernetes_istio_pilot_cpu_limits      = "500m"
kubernetes_istio_pilot_cpu_requests    = "50m"
kubernetes_istio_pilot_memory_limits   = "256Mi"
kubernetes_istio_pilot_memory_requests = "128Mi"

kubernetes_istio_ztunnel_cpu_requests    = "100m"
kubernetes_istio_ztunnel_memory_requests = "128Mi"
