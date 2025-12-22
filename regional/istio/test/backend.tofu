# Kubernetes Backend Configuration
# https://opentofu.org/docs/language/settings/backends/kubernetes

terraform {
  backend "gcs" {
    bucket = var.state_bucket
    prefix = var.state_prefix

    encryption_key = var.state_kms_encryption_key
  }
}
