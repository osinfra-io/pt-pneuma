# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=89df0c51d977937743a2075605acdca2f69b90d2" # v0.6.0

  for_each = local.teams_with_clusters

  gke_fleet_host_project_id = local.gke_fleet_host_project_id_by_team[each.key]
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
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=5a6ea395abc2d4d6e8096e94a3723cffbf4b06cd" # v0.4.4

  for_each = local.teams_with_clusters

  ca_cert_pem = tls_self_signed_cert.cert_manager_ca.cert_pem
  ca_key_pem  = tls_private_key.cert_manager_ca.private_key_pem
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=ffae90ec7bb81fffbde170a991802ca7398676f2" # v0.9.7

  for_each = local.teams_with_clusters

  gateway_dns               = local.istio_gateway_dns_by_team[each.key]
  gke_fleet_host_project_id = local.gke_fleet_host_project_id_by_team[each.key]
  labels                    = module.core_helpers.labels
  project                   = local.team_project_ids[each.key]
}

# Google Compute Global Address Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/compute_global_address

resource "google_compute_global_address" "openbao_mci" {
  labels  = module.core_helpers.labels
  name    = "openbao-mci"
  project = local.team_project_ids[module.core_helpers.team]
}

# Google Compute Managed SSL Certificate Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate

resource "google_compute_managed_ssl_certificate" "openbao_mci" {
  managed {
    domains = [local.openbao_hostname]
  }

  name    = "openbao-mci"
  project = local.team_project_ids[module.core_helpers.team]
}

# Google Compute Security Policy Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/compute_security_policy

resource "google_compute_security_policy" "shared_ingress" {
  provider = google-beta

  advanced_options_config {
    log_level = "VERBOSE"
  }

  adaptive_protection_config {
    auto_deploy_config {
      confidence_threshold        = 0.5
      expiration_sec              = 7200
      impacted_baseline_threshold = 0.01
      load_threshold              = 0.8
    }

    layer_7_ddos_defense_config {
      enable = true
    }
  }

  name    = local.shared_ingress_policy_name
  project = local.team_project_ids[module.core_helpers.team]

  dynamic "rule" {
    for_each = local.authentik_cloud_armor_allow_rules

    content {
      action      = "allow"
      description = rule.value.description

      match {
        expr {
          expression = rule.value.expression
        }
      }

      preview  = false
      priority = rule.value.priority
    }
  }

  dynamic "rule" {
    for_each = local.cloud_armor_preconfigured_waf_rules

    content {
      action      = rule.value.action
      description = rule.value.description

      match {
        expr {
          expression = local.cloud_armor_waf_rule_expressions[rule.value.name]
        }
      }

      dynamic "preconfigured_waf_config" {
        for_each = length(local.cloud_armor_waf_exclusions_by_rule_set[rule.value.name]) > 0 ? [1] : []

        content {
          dynamic "exclusion" {
            for_each = local.cloud_armor_waf_exclusions_by_rule_set[rule.value.name]

            content {
              target_rule_ids = exclusion.value.target_rule_ids
              target_rule_set = exclusion.value.target_rule_set

              dynamic "request_query_param" {
                for_each = exclusion.value.request_query_param_names

                content {
                  operator = "EQUALS"
                  value    = request_query_param.value
                }
              }
            }
          }
        }
      }

      preview  = rule.value.preview
      priority = rule.value.priority
    }
  }

  rule {
    action      = "throttle"
    description = "Rate limit all user IPs"

    match {
      config {
        src_ip_ranges = ["*"]
      }

      versioned_expr = "SRC_IPS_V1"
    }

    preview  = false
    priority = 30000

    rate_limit_options {
      conform_action = "allow"
      enforce_on_key = "ALL"
      exceed_action  = "deny(429)"

      rate_limit_threshold {
        count        = 500
        interval_sec = 60
      }
    }
  }

  rule {
    action      = "allow"
    description = "Default allow rule"

    match {
      config {
        src_ip_ranges = ["*"]
      }

      versioned_expr = "SRC_IPS_V1"
    }

    priority = 2147483647
  }
}

# Google Compute SSL Policy Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/compute_ssl_policy

resource "google_compute_ssl_policy" "shared_ingress" {
  min_tls_version = "TLS_1_2"
  name            = local.shared_ingress_policy_name
  profile         = "MODERN"
  project         = local.team_project_ids[module.core_helpers.team]
}

# Google DNS Record Set Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/dns_record_set

resource "google_dns_record_set" "openbao_mci" {
  for_each = local.openbao_global_dns

  managed_zone = each.value.managed_zone
  name         = each.value.dns_name
  project      = each.value.project
  rrdatas      = [google_compute_global_address.openbao_mci.address]
  ttl          = 300
  type         = "A"
}

# Google KMS Crypto Key Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/kms_crypto_key

resource "google_kms_crypto_key" "openbao_unseal" {
  # CryptoKeys cannot be deleted from Google Cloud Platform. Losing this key means losing access to every secret
  # stored in OpenBao, so destruction is blocked.

  lifecycle {
    prevent_destroy = true
  }

  key_ring        = google_kms_key_ring.openbao_unseal.id
  labels          = module.core_helpers.labels
  name            = "unseal"
  rotation_period = "7776000s"
}

# Google KMS Crypto Key IAM Member Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member

resource "google_kms_crypto_key_iam_member" "openbao_unseal" {
  crypto_key_id = google_kms_crypto_key.openbao_unseal.id
  member        = local.openbao_kms_member
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
}

resource "google_kms_crypto_key_iam_member" "openbao_unseal_viewer" {
  crypto_key_id = google_kms_crypto_key.openbao_unseal.id
  member        = local.openbao_kms_member
  role          = "roles/cloudkms.viewer"
}

# Google KMS Key Ring Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/kms_key_ring

resource "google_kms_key_ring" "openbao_unseal" {
  # KeyRings cannot be deleted from Google Cloud Platform. Destroying a OpenTofu-managed KeyRing will remove it from
  # state but will not delete the resource from the project.

  lifecycle {
    prevent_destroy = true
  }

  # The multi-region location lets OpenBao clusters in every region use the same key.
  location = "us"
  name     = "openbao-unseal"
  project  = local.team_project_ids[module.core_helpers.team]
}

# Google Project IAM Member Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/project_iam_member

# The Cloud SQL Auth Proxy sidecar in the Authentik pods connects as this service account via
# Workload Identity; roles/cloudsql.client lets it open the proxied connection to the instance.
resource "google_project_iam_member" "authentik_cloud_sql_client" {
  member  = local.authentik_cloud_sql_member
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

# Identity the OpenBao pods impersonate to auto-unseal with Cloud KMS. Every regional OpenBao cluster
# shares the project's Workload Identity pool, namespace and chart ServiceAccount.
resource "google_service_account" "openbao_kms" {
  account_id   = "openbao-kms"
  display_name = "OpenBao KMS Auto-Unseal"
  project      = local.team_project_ids[module.core_helpers.team]
}

# Google Service Account IAM Member Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/service_account_iam_member

# Bind the Authentik Kubernetes service account (authentik/authentik) to the Google service account
# so the Cloud SQL Auth Proxy sidecar authenticates through GKE Workload Identity.
resource "google_service_account_iam_member" "authentik_cloud_sql_workload_identity" {
  member             = local.authentik_workload_identity_member
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.authentik_cloud_sql.name
}

# Bind the OpenBao Kubernetes service account to the Google service account so the pods
# authenticate to Cloud KMS through GKE Workload Identity.
resource "google_service_account_iam_member" "openbao_kms_workload_identity" {
  member             = local.openbao_workload_identity_member
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.openbao_kms.name
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
