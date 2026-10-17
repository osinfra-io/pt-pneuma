# Output Values
# https://opentofu.org/docs/language/values/outputs

output "route_manifest" {
  description = "Istio ingress route to the OpenBao Service"
  value       = kubernetes_manifest.openbao.manifest
}
