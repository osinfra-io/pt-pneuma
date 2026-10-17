# Output Values
# https://opentofu.org/docs/language/values/outputs

output "authentik_base_url" {
  description = "Public base URL (OIDC issuer/provider host) for the single logical Authentik service"
  value       = local.authentik_base_url
}

output "authentik_cloud_sql_connection_name" {
  description = "Connection name (project:region:instance) of the platform-managed Authentik Cloud SQL instance, consumed by the regional authentik workspaces for the Cloud SQL Auth Proxy sidecar"
  value       = local.authentik_cloud_sql_connection_name
}

output "authentik_cloud_sql_service_account_email" {
  description = "Email of the Google service account the Authentik Cloud SQL Auth Proxy impersonates via Workload Identity, consumed by the regional authentik workspaces"
  value       = google_service_account.authentik_cloud_sql.email
}

output "authentik_database_host" {
  description = "Private DNS FQDN of the platform-managed (pt-corpus) Authentik Cloud SQL primary, consumed by regional authentik workspaces"
  value       = local.authentik_database_host
}

output "authentik_database_name" {
  description = "Name of the shared Authentik PostgreSQL database"
  value       = google_sql_database.authentik.name
}

output "authentik_database_user" {
  description = "User for the shared Authentik PostgreSQL database"
  value       = google_sql_user.authentik.name
}

output "authentik_kubernetes_namespace" {
  description = "Logos-managed Kubernetes namespace where Authentik is deployed"
  value       = local.authentik_kubernetes_namespace
}

output "authentik_secret_env" {
  description = "Shared Authentik environment secret values (secret key, DB and bootstrap credentials) generated once and consumed by every regional authentik workspace"
  sensitive   = true
  value       = local.authentik_secret_env
}

output "clusters" {
  description = "Slim GKE cluster map (all teams, all zones) for the deployment workflow to pass to zone workspaces as TF_VAR_clusters, keyed by cluster name"
  value       = local.clusters_slim
}

output "gateway_dns" {
  description = "Gateway DNS configuration for Istio per team, keyed by team then DNS zone name"
  value       = local.gateway_dns_by_team
}

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert" {
  description = "The self-signed certificate for the cert-manager root certificate"
  value       = tls_self_signed_cert.cert_manager_ca.cert_pem
}

output "kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key" {
  description = "The private key for the cert-manager root certificate"
  sensitive   = true
  value       = tls_private_key.cert_manager_ca.private_key_pem
}

output "kubernetes_engine_workload_identity_service_account_emails" {
  description = "The email addresses of the service accounts for the Kubernetes namespace workload identity, keyed by team then namespace"
  value       = local.kubernetes_engine_workload_identity_service_account_emails
}

output "kubernetes_istio_gateway_mci_global_address" {
  description = "The IP address for the Istio Gateway multi-cluster ingress, keyed by team"
  value       = local.kubernetes_istio_gateway_mci_global_addresses
}

output "openbao_hostname" {
  description = "Global public hostname for the OpenBao multi-cluster ingress"
  value       = local.openbao_hostname
}

output "openbao_kms_seal" {
  description = "GCP Cloud KMS settings (project, region, key ring, crypto key) for the OpenBao auto-unseal gcpckms seal, consumed by the regional openbao workspaces"
  value       = local.openbao_kms_seal
}

output "openbao_kms_service_account_email" {
  description = "Email of the Google service account the OpenBao pods impersonate via Workload Identity to use the auto-unseal KMS key, consumed by the regional openbao workspaces"
  value       = google_service_account.openbao_kms.email
}

output "openbao_mci_global_address" {
  description = "The global IP address reserved for the OpenBao multi-cluster ingress"
  value       = google_compute_global_address.openbao_mci.address
}

output "openbao_mci_ssl_certificate_name" {
  description = "The Google-managed SSL certificate name for the OpenBao multi-cluster ingress"
  value       = google_compute_managed_ssl_certificate.openbao_mci.name
}

output "openbao_public_dns_zone_name" {
  description = "The environment-level public DNS zone for OpenBao global and zonal ingress records"
  value       = local.authentik_public_dns_zone_name
}

output "project_id" {
  description = "The platform-managed project ID"
  value       = data.google_project.platform_managed.project_id
}

output "project_number" {
  description = "The platform-managed project number"
  value       = data.google_project.platform_managed.number
}

output "shared_ingress_policy_name" {
  description = "Name of the shared Cloud Armor security and SSL policies for Pneuma-managed ingress"
  value       = local.shared_ingress_policy_name
}

output "shared_vpc_host_project_id" {
  description = "The shared VPC host project ID from pt-corpus"
  value       = data.google_project.shared_vpc_host.project_id
}

output "team" {
  description = "The team data from helpers module"
  value       = module.core_helpers.teams[module.core_helpers.team]
}
