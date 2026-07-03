# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # istio-test virtual services shared across regions, per cluster.
  common_istio_test_virtual_services = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      "istio-test" = {
        destination_host = "istio-test.istio-test.svc.cluster.local"
        host             = local.dns_zone[cluster_name]
      }
    }
  }

  # The single gateway DNS zone for each cluster's owning team (e.g. "pneuma.osinfra.io").
  # one() errors loudly if a team has >1 zone and returns null if empty; both cases
  # indicate the main workspace has not been applied for that team.
  dns_zone = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => one(keys(try(local.main.gateway_dns[cluster_config.team_key], {})))
  }

  # Failover region per cluster (the paired region for multi-region istio failover).
  failover_to_region = {
    for cluster_name in keys(local.gke_clusters) :
    cluster_name => local.regions[cluster_name] == "us-east1" ? "us-east4" : "us-east1"
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Region-specific istio-test virtual services, per cluster.
  istio_test_virtual_services = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      "istio-test-${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}" = {
        destination_host = "istio-test-${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}.istio-test.svc.cluster.local"
        host             = "${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}.${local.dns_zone[cluster_name]}"
      }
    }
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-manifests-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
