# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  admin_password_secret_key = "admin-password"

  admin_secret_names = {
    for cluster_name in keys(local.keycloak_clusters) :
    cluster_name => "keycloak-admin"
  }

  cloud_sql_database_names = {
    for cluster_name in keys(local.keycloak_clusters) :
    cluster_name => "keycloak"
  }

  cloud_sql_database_version = "POSTGRES_16"

  cloud_sql_deletion_protection = module.core_helpers.env == "prod"

  cloud_sql_instance_names = {
    for cluster_name in keys(local.keycloak_clusters) :
    cluster_name => "keycloak-${cluster_name}"
  }

  cloud_sql_labels = {
    for cluster_name, cluster_config in local.keycloak_clusters :
    cluster_name => merge(module.core_helpers.labels, { cluster = cluster_name, team = cluster_config.team_key })
  }

  cloud_sql_machine_tier = "db-f1-micro"

  cloud_sql_user_names = {
    for cluster_name in keys(local.keycloak_clusters) :
    cluster_name => "keycloak"
  }

  database_password_secret_key = "password"

  database_secret_names = {
    for cluster_name in keys(local.keycloak_clusters) :
    cluster_name => "keycloak-database"
  }

  database_user_secret_key = "username"

  dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  dns_zone_name = module.core_helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io" : "${local.dns_subdomain}.${module.core_helpers.env}.osinfra.io"

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  keycloak_base_url = "https://${local.keycloak_hostname}"

  keycloak_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  keycloak_hostname = "keycloak.${local.dns_zone_name}"

  keycloak_namespace = "keycloak"

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  shared_vpc_name = "standard-shared"

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-keycloak-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
