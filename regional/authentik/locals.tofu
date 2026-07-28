# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  authentik_base_url = "https://${local.authentik_hostname}"

  authentik_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  authentik_hostname = "authentik.${local.dns_zone_name}"

  authentik_namespace = "authentik"

  # Keys in the Authentik environment Secret, mounted into the server and worker via the chart's
  # global.envFrom so no secrets are stored in the Helm release.
  authentik_secret_env = {
    for cluster_name in keys(local.authentik_clusters) :
    cluster_name => {
      AUTHENTIK_BOOTSTRAP_PASSWORD   = random_password.authentik_admin[cluster_name].result
      AUTHENTIK_BOOTSTRAP_TOKEN      = random_password.authentik_bootstrap_token[cluster_name].result
      AUTHENTIK_POSTGRESQL__PASSWORD = random_password.authentik_database[cluster_name].result
      AUTHENTIK_SECRET_KEY           = random_password.authentik_secret_key[cluster_name].result
    }
  }

  authentik_secret_names = {
    for cluster_name in keys(local.authentik_clusters) :
    cluster_name => "authentik"
  }

  cloud_sql_database_names = {
    for cluster_name in keys(local.authentik_clusters) :
    cluster_name => "authentik"
  }

  cloud_sql_database_version = "POSTGRES_16"

  cloud_sql_deletion_protection = module.core_helpers.env == "prod"

  cloud_sql_instance_names = {
    for cluster_name in keys(local.authentik_clusters) :
    cluster_name => "authentik-${cluster_name}"
  }

  cloud_sql_labels = {
    for cluster_name, cluster_config in local.authentik_clusters :
    cluster_name => merge(module.core_helpers.labels, { cluster = cluster_name, team = cluster_config.team_key })
  }

  cloud_sql_machine_tier = "db-f1-micro"

  cloud_sql_user_names = {
    for cluster_name in keys(local.authentik_clusters) :
    cluster_name => "authentik"
  }

  dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  dns_zone_name = module.core_helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io" : "${local.dns_subdomain}.${module.core_helpers.env}.osinfra.io"

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  shared_vpc_name = "standard-shared"

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-authentik-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
