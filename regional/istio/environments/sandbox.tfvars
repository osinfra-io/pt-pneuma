# Sandbox runs a single e2-standard-4 node per cluster. Requests cover observed steady usage while
# limits preserve burst capacity: the CNI peaks around 13m CPU / 59Mi memory, gateway proxies around
# 85-120m / 56Mi, and istiod around 218m / 116Mi.

kubernetes_datadog_aap_extproc_resources_limits_cpu      = "500m"
kubernetes_datadog_aap_extproc_resources_limits_memory   = "64Mi"
kubernetes_datadog_aap_extproc_resources_requests_cpu    = "250m"
kubernetes_datadog_aap_extproc_resources_requests_memory = "32Mi"
kubernetes_istio_cni_cpu_requests                        = "25m"
kubernetes_istio_cni_memory_requests                     = "64Mi"
kubernetes_istio_east_west_gateway_cpu_limits            = "500m"
kubernetes_istio_east_west_gateway_cpu_requests          = "50m"
kubernetes_istio_east_west_gateway_memory_limits         = "256Mi"
kubernetes_istio_east_west_gateway_memory_requests       = "64Mi"
kubernetes_istio_gateway_cpu_limits                      = "500m"
kubernetes_istio_gateway_cpu_requests                    = "100m"
kubernetes_istio_gateway_memory_limits                   = "128Mi"
kubernetes_istio_gateway_memory_requests                 = "64Mi"

# One istiod replica. The HPA's CPU target is measured against the pilot CPU request, so a 10m
# request makes ordinary control plane activity read as several hundred percent utilization and
# pins istiod at the maximum. On a single node those extra replicas cost ~55Mi each and provide
# no availability benefit.

kubernetes_istio_pilot_autoscale_max = 1

kubernetes_istio_pilot_cpu_limits      = "500m"
kubernetes_istio_pilot_cpu_requests    = "100m"
kubernetes_istio_pilot_memory_limits   = "256Mi"
kubernetes_istio_pilot_memory_requests = "128Mi"

kubernetes_istio_ztunnel_cpu_requests    = "50m"
kubernetes_istio_ztunnel_memory_requests = "128Mi"
