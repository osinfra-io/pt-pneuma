# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  agentgateway_clusters = {
    for name, cluster in var.clusters : name => cluster
    if endswith(name, "-${local.zone}") && cluster.team_key == module.core_helpers.team && module.core_helpers.environment == "sandbox"
  }

  namespace = "${module.core_helpers.team}-agentgateway"

  regions = {
    for name in keys(var.clusters) : name => regex("(us-[a-z0-9]+)-[a-z]$", name)[0]
  }

  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
