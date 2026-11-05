# Keep the single-node footprint small without starving the remaining replicas of burst capacity.

kubernetes_istio_gateway_autoscale_max   = 1
kubernetes_istio_gateway_cpu_limits      = "500m"
kubernetes_istio_gateway_cpu_requests    = "100m"
kubernetes_istio_gateway_memory_limits   = "128Mi"
kubernetes_istio_gateway_memory_requests = "64Mi"
kubernetes_istio_pilot_autoscale_max     = 1
kubernetes_istio_pilot_cpu_limits        = "500m"
kubernetes_istio_pilot_cpu_requests      = "100m"
kubernetes_istio_pilot_memory_limits     = "256Mi"
kubernetes_istio_pilot_memory_requests   = "128Mi"
