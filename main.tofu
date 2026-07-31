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

# Google Project IAM Member Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/project_iam_member

# The Cloud SQL Auth Proxy sidecar in the Authentik pods connects as this service account via
# Workload Identity; roles/cloudsql.client lets it open the proxied connection to the instance.
resource "google_project_iam_member" "authentik_cloud_sql_client" {
  member  = "serviceAccount:${google_service_account.authentik_cloud_sql.email}"
  project = local.team_project_ids[module.core_helpers.team]
  role    = "roles/cloudsql.client"
}

# Google Service Account Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/service_account

# Identity the Cloud SQL Auth Proxy sidecar impersonates. Every regional Authentik cluster shares
# the project's Workload Identity pool, namespace and chart ServiceAccount, so one account serves them all.
resource "google_service_account" "authentik_cloud_sql" {
  account_id   = "authentik-cloud-sql"
  display_name = "Authentik Cloud SQL Auth Proxy"
  project      = local.team_project_ids[module.core_helpers.team]
}

# Google Service Account IAM Member Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/service_account_iam_member

# Bind the Authentik Kubernetes service account (authentik/authentik) to the Google service account
# so the Cloud SQL Auth Proxy sidecar authenticates through GKE Workload Identity.
resource "google_service_account_iam_member" "authentik_cloud_sql_workload_identity" {
  member             = "serviceAccount:${local.team_project_ids[module.core_helpers.team]}.svc.id.goog[${local.authentik_kubernetes_namespace}/${local.authentik_kubernetes_service_account}]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.authentik_cloud_sql.name
}

# Google SQL Database Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_database
# The instance itself is platform-managed by pt-corpus (dogfooding the platform Cloud SQL); pneuma
# owns only the authentik database and user on it, discovered in-project via a data source.

resource "google_sql_database" "authentik" {
  lifecycle {
    precondition {
      condition     = local.authentik_cloud_sql_instance_name != null
      error_message = "No Cloud SQL instance matching authentik-* was found in ${local.authentik_primary_region} for the pneuma project; ensure pt-corpus has provisioned the Authentik instance."
    }
  }

  instance = local.authentik_cloud_sql_instance_name
  name     = local.authentik_database_name
  project  = local.team_project_ids[module.core_helpers.team]
}

# Google SQL User Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/sql_user

resource "google_sql_user" "authentik" {
  instance = local.authentik_cloud_sql_instance_name
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
