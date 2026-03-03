# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gateway_dns" {
  description = "Gateway DNS configuration for Istio, keyed by DNS zone name"
  value       = local.gateway_dns
}

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert" {
  description = "The self-signed certificate for the cert-manager root certificate"
  value       = module.kubernetes_cert_manager.tls_self_signed_cert_cert_manager_root_cert
}

output "kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key" {
  description = "The private key for the cert-manager root certificate"
  sensitive   = true
  value       = module.kubernetes_cert_manager.tls_self_signed_cert_cert_manager_root_key
}

output "kubernetes_engine_workload_identity_service_account_emails" {
  description = "The email addresses of the service accounts for the Kubernetes namespace workload identity"
  value       = module.kubernetes_engine.workload_identity_service_account_emails
}

output "kubernetes_istio_gateway_mci_global_address" {
  description = "The IP address for the Istio Gateway multi-cluster ingress"
  value       = module.kubernetes_istio.gateway_mci_global_address
}

output "project_id" {
  description = "The Kubernetes project ID"
  value       = data.google_project.kubernetes.project_id
}

output "project_number" {
  description = "The Kubernetes project number"
  value       = data.google_project.kubernetes.number
}

output "shared_vpc_host_project_id" {
  description = "The shared VPC host project ID from pt-corpus"
  value       = data.google_project.shared_vpc_host.project_id
}

output "team" {
  description = "The team data from helpers module"
  value       = module.helpers.teams[module.helpers.team]
}
