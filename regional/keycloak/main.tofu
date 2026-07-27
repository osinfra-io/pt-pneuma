# Google Cloud SQL Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-cloud-sql

module "google_cloud_sql" {
  source = "github.com/osinfra-io/pt-arche-google-cloud-sql//regional?ref=a1325d4daffb3e5b7f18c48d9780509cc33d5aec" # v0.2.8

  for_each = local.keycloak_clusters

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

# Kubernetes Keycloak Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-keycloak

module "kubernetes_keycloak" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-keycloak//regional?ref=f9c21c607203b23887910339490b6a49667e3e17" # create-keycloak-module (branch ref pending release)

  depends_on = [
    google_sql_database.keycloak,
    google_sql_user.keycloak,
    kubernetes_namespace_v1.keycloak,
    kubernetes_secret_v1.keycloak_admin,
    kubernetes_secret_v1.keycloak_database,
  ]

  for_each = local.keycloak_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  admin_existing_secret                          = kubernetes_secret_v1.keycloak_admin[each.key].metadata[0].name
  admin_password_secret_key                      = local.admin_password_secret_key
  base_url                                       = local.keycloak_base_url
  external_database_database                     = google_sql_database.keycloak[each.key].name
  external_database_existing_secret              = kubernetes_secret_v1.keycloak_database[each.key].metadata[0].name
  external_database_existing_secret_password_key = local.database_password_secret_key
  external_database_existing_secret_user_key     = local.database_user_secret_key
  external_database_host                         = module.google_cloud_sql[each.key].private_ip_address
  external_database_user                         = google_sql_user.keycloak[each.key].name
  namespace                                      = kubernetes_namespace_v1.keycloak[each.key].metadata[0].name
}

# Google SQL Database Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_database

resource "google_sql_database" "keycloak" {
  for_each = local.keycloak_clusters

  instance = module.google_cloud_sql[each.key].instance
  name     = local.cloud_sql_database_names[each.key]
  project  = each.value.project_id
}

# Google SQL User Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_user

resource "google_sql_user" "keycloak" {
  for_each = local.keycloak_clusters

  instance = module.google_cloud_sql[each.key].instance
  name     = local.cloud_sql_user_names[each.key]
  password = random_password.keycloak_database[each.key].result
  project  = each.value.project_id
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "keycloak" {
  for_each = local.keycloak_clusters
  provider = kubernetes.by_cluster[each.key]

  metadata {
    name = local.keycloak_namespace
  }
}

# Kubernetes Secret Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

resource "kubernetes_secret_v1" "keycloak_admin" {
  for_each = local.keycloak_clusters
  provider = kubernetes.by_cluster[each.key]

  data = {
    (local.admin_password_secret_key) = random_password.keycloak_admin[each.key].result
  }

  metadata {
    name      = local.admin_secret_names[each.key]
    namespace = kubernetes_namespace_v1.keycloak[each.key].metadata[0].name
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "keycloak_database" {
  for_each = local.keycloak_clusters
  provider = kubernetes.by_cluster[each.key]

  data = {
    (local.database_password_secret_key) = random_password.keycloak_database[each.key].result
    (local.database_user_secret_key)     = google_sql_user.keycloak[each.key].name
  }

  metadata {
    name      = local.database_secret_names[each.key]
    namespace = kubernetes_namespace_v1.keycloak[each.key].metadata[0].name
  }

  type = "Opaque"
}

# Random Password Resource
# https://search.opentofu.org/provider/hashicorp/random/latest/docs/resources/password

resource "random_password" "keycloak_admin" {
  for_each = local.keycloak_clusters

  length  = 32
  special = true
}

resource "random_password" "keycloak_database" {
  for_each = local.keycloak_clusters

  length  = 32
  special = true
}
