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
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=68551c85ecbfc8f82c313cc3fc7d9335f313d12a" # v0.3.4

  for_each = local.teams_with_clusters

  ca_cert_pem = tls_self_signed_cert.cert_manager_ca.cert_pem
  ca_key_pem  = tls_private_key.cert_manager_ca.private_key_pem
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=d0b3845fb3bab524093ccab9f33f94a1b76c7789" # v0.5.3

  for_each = local.teams_with_clusters

  gateway_dns               = each.key == module.core_helpers.team ? local.gateway_dns_for_pneuma : {}
  gke_fleet_host_project_id = each.key == module.core_helpers.team ? "" : local.team_project_ids[module.core_helpers.team]
  labels                    = module.core_helpers.labels
  project                   = local.team_project_ids[each.key]
}
