# Google Cloud SQL Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-cloud-sql

module "google_cloud_sql" {
  source = "github.com/osinfra-io/pt-arche-google-cloud-sql//regional?ref=a1325d4daffb3e5b7f18c48d9780509cc33d5aec" # v0.2.8

  availability_type   = "REGIONAL"
  database_version    = local.authentik_cloud_sql_database_version
  deletion_protection = local.authentik_cloud_sql_deletion_protection
  host_project_id     = data.google_project.shared_vpc_host.project_id
  instance_name       = local.authentik_cloud_sql_instance_name
  labels              = module.core_helpers.labels
  machine_tier        = local.authentik_cloud_sql_machine_tier
  network             = local.shared_vpc_name
  project             = local.team_project_ids[module.core_helpers.team]
  region              = local.authentik_primary_region
}

# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=17ec48e935e9be141990413419e61161527ac60c" # v0.4.5

  for_each = local.teams_with_clusters

  gke_fleet_host_project_id = each.key == "pt-pneuma" ? "" : local.team_project_ids["pt-pneuma"]
  labels                    = module.core_helpers.labels
  namespaces                = local.gke_namespaces_by_team[each.key]
  project                   = local.team_project_ids[each.key]
}

# TLS Private Key Resource
# https://search.opentofu.org/provider/hashicorp/tls/latest/docs/resources/private_key

resource "tls_private_key" "cert_manager_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# TLS Self-Signed Certificate Resource
# https://search.opentofu.org/provider/hashicorp/tls/latest/docs/resources/self_signed_cert

resource "tls_self_signed_cert" "cert_manager_ca" {
  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
  ]

  is_ca_certificate = true
  private_key_pem   = tls_private_key.cert_manager_ca.private_key_pem

  subject {
    common_name  = "opentofu-self-signed-ca.osinfra.io"
    organization = "Open Source Infrastructure (as Code) OpenTofu Self-Signed CA"
  }

  validity_period_hours = 262980 # 30 years
}

# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=3028d24c2bff8e9cfd6e0237c45e99337a0cfc98" # v0.3.5

  for_each = local.teams_with_clusters

  ca_cert_pem = tls_self_signed_cert.cert_manager_ca.cert_pem
  ca_key_pem  = tls_private_key.cert_manager_ca.private_key_pem
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=3317d38d97fd1cb3298d5933bdbb265e45280eb0" # v0.5.4

  for_each = local.teams_with_clusters

  gateway_dns               = each.key == module.core_helpers.team ? local.gateway_dns_for_pneuma : {}
  gke_fleet_host_project_id = each.key == module.core_helpers.team ? "" : local.team_project_ids[module.core_helpers.team]
  labels                    = module.core_helpers.labels
  project                   = local.team_project_ids[each.key]
}

# Google SQL Database Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_database

resource "google_sql_database" "authentik" {
  instance = module.google_cloud_sql.instance
  name     = local.authentik_database_name
  project  = local.team_project_ids[module.core_helpers.team]
}

# Google SQL User Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_user

resource "google_sql_user" "authentik" {
  instance = module.google_cloud_sql.instance
  name     = local.authentik_database_user
  password = random_password.authentik_database.result
  project  = local.team_project_ids[module.core_helpers.team]
}

# Random Password Resource
# https://search.opentofu.org/provider/hashicorp/random/latest/docs/resources/password
# Single logical Authentik service: these secrets are generated once and shared by every
# regional server/worker so all instances form one identity provider (same signing/session state).

resource "random_password" "authentik_admin" {
  length  = 32
  special = true
}

resource "random_password" "authentik_bootstrap_token" {
  length  = 60
  special = false
}

resource "random_password" "authentik_database" {
  length  = 32
  special = false
}

resource "random_password" "authentik_secret_key" {
  length  = 50
  special = false
}
