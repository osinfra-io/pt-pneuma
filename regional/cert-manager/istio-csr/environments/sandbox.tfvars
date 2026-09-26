# istio-csr signs workload certificates on demand and measures 2m CPU / 33Mi memory in sandbox.
# The limit is left at the module default so signing bursts are still absorbed.

kubernetes_cert_manager_istio_csr_resources_requests_cpu = "10m"
