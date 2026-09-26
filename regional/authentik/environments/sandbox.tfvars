# The server's memory request was 2.4x below its actual 623Mi footprint and the worker's 2.1x
# below its 275Mi, which made both the first candidates for eviction under node memory pressure.
# Node memory requests sit at roughly half of allocatable, so raising them is cheap. CPU runs
# well under its request on the server, so that is reclaimed.

authentik_server_replicas                  = 1
authentik_server_resources_requests_cpu    = "50m"
authentik_server_resources_requests_memory = "640Mi"
authentik_worker_replicas                  = 1
authentik_worker_resources_requests_cpu    = "50m"
authentik_worker_resources_requests_memory = "288Mi"
