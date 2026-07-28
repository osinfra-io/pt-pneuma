# Google Cloud SQL Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-cloud-sql

module "google_cloud_sql" {
  source = "github.com/osinfra-io/pt-arche-google-cloud-sql//regional?ref=a1325d4daffb3e5b7f18c48d9780509cc33d5aec" # v0.2.8

  for_each = local.authentik_clusters

  database_version    = local.cloud_sql_database_version
  deletion_protection = local.cloud_sql_deletion_protection
  host_project_id     = local.main.shared_vpc_host_project_id
  instance_name       = local.cloud_sql_instance_names[each.key]
  labels              = local.cloud_sql_labels[each.key]
  machine_tier        = local.cloud_sql_machine_tier
  network             = local.shared_vpc_name
  project             = each.value.project_id
  region              = local.regions[each.key]
}

# Kubernetes Authentik Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "kubernetes_authentik" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional?ref=d033f0a0fa55b5a07266968b6ef654ea0a9f3037" # create-authentik-module (branch ref pending release)

  depends_on = [
    google_sql_database.authentik,
    google_sql_user.authentik,
    kubernetes_namespace_v1.authentik,
    kubernetes_secret_v1.authentik,
  ]

  for_each = local.authentik_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  existing_secret        = kubernetes_secret_v1.authentik[each.key].metadata[0].name
  external_database_host = module.google_cloud_sql[each.key].private_ip_address
  external_database_name = google_sql_database.authentik[each.key].name
  external_database_user = google_sql_user.authentik[each.key].name
  namespace              = kubernetes_namespace_v1.authentik[each.key].metadata[0].name
}

# Google SQL Database Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_database

resource "google_sql_database" "authentik" {
  for_each = local.authentik_clusters

  instance = module.google_cloud_sql[each.key].instance
  name     = local.cloud_sql_database_names[each.key]
  project  = each.value.project_id
}

# Google SQL User Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_user

resource "google_sql_user" "authentik" {
  for_each = local.authentik_clusters

  instance = module.google_cloud_sql[each.key].instance
  name     = local.cloud_sql_user_names[each.key]
  password = random_password.authentik_database[each.key].result
  project  = each.value.project_id
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "authentik" {
  for_each = local.authentik_clusters
  provider = kubernetes.by_cluster[each.key]

  metadata {
    name = local.authentik_namespace
  }
}

# Kubernetes Secret Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

resource "kubernetes_secret_v1" "authentik" {
  for_each = local.authentik_clusters
  provider = kubernetes.by_cluster[each.key]

  data = local.authentik_secret_env[each.key]

  metadata {
    name      = local.authentik_secret_names[each.key]
    namespace = kubernetes_namespace_v1.authentik[each.key].metadata[0].name
  }

  type = "Opaque"
}

# Random Password Resource
# https://search.opentofu.org/provider/hashicorp/random/latest/docs/resources/password

resource "random_password" "authentik_admin" {
  for_each = local.authentik_clusters

  length  = 32
  special = true
}

resource "random_password" "authentik_bootstrap_token" {
  for_each = local.authentik_clusters

  length  = 60
  special = false
}

resource "random_password" "authentik_database" {
  for_each = local.authentik_clusters

  length  = 32
  special = false
}

resource "random_password" "authentik_secret_key" {
  for_each = local.authentik_clusters

  length  = 50
  special = false
}
