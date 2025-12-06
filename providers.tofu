# Terraform Configuration and Backend
# https://opentofu.org/docs/language/settings

terraform {
  encryption {
    key_provider "gcp_kms" "key" {
      kms_encryption_key = "projects/pt-corpus-tf16-prod/locations/us/keyRings/state-encryption/cryptoKeys/default"
    }

    method "aes_gcm" "method" {
      keys = key_provider.gcp_kms.key
    }

    state {
      method = method.aes_gcm.method
    }
  }

  required_providers {
    datadog = {
      source = "datadog/datadog"
    }

    google = {
      source = "hashicorp/google"
    }
  }

  required_version = ">= 1.10, < 2.0.0"
}

# Datadog Provider
# https://registry.terraform.io/providers/DataDog/datadog/latest/docs

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}

# Google Cloud Platform Provider
# https://registry.terraform.io/providers/hashicorp/google/latest/docs

provider "google" {}
