# Sandbox runs a single e2-standard-2 node per cluster, so the ambient data plane's default
# reservations - ztunnel 250m, istio-cni 100m and the east-west gateway 100m - consume roughly
# a quarter of the node's allocatable CPU on their own. Measured usage is 5m, 1m and 4m
# respectively. Limits are left at the module defaults so every component can still burst.

kubernetes_istio_cni_cpu_requests                  = "25m"
kubernetes_istio_cni_memory_requests               = "32Mi"
kubernetes_istio_east_west_gateway_cpu_requests    = "25m"
kubernetes_istio_east_west_gateway_memory_requests = "64Mi"

# One istiod replica. The HPA's CPU target is measured against the pilot CPU request, so a 10m
# request makes ordinary control plane activity read as several hundred percent utilization and
# pins istiod at the maximum. On a single node those extra replicas cost ~55Mi each and provide
# no availability benefit.

kubernetes_istio_pilot_autoscale_max = 1

kubernetes_istio_ztunnel_cpu_requests    = "100m"
kubernetes_istio_ztunnel_memory_requests = "128Mi"
