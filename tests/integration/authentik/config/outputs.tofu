# Output Values
# https://opentofu.org/docs/language/values/outputs

output "authentication" {
  description = "Shared authentication configuration exercised by the local fixture"
  value       = module.authentication
}
