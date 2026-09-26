# Seven-day sandbox observations show the server peaking around 500m CPU / 716Mi memory and the
# worker averaging 171-231m CPU / 286Mi memory, with CPU bursts near one core. The e2-standard-4
# nodes have enough scheduling capacity to reserve their steady usage while leaving CPU unlimited
# for authentication and background-task bursts.

authentik_server_replicas                  = 1
authentik_server_resources_requests_cpu    = "250m"
authentik_server_resources_requests_memory = "768Mi"
authentik_worker_replicas                  = 1
authentik_worker_resources_requests_cpu    = "250m"
authentik_worker_resources_requests_memory = "384Mi"
