terraform {

  # State and Plan Encryption
  # https://opentofu.org/docs/language/state/encryption

  # The commented out sections below demonstrate how to configure
  # fallback encryption methods for state and plan files for bootstrapping.

  encryption {
    method "unencrypted" "migrate" {}

    key_provider "gcp_kms" "default" {
      kms_encryption_key = var.state_kms_encryption_key
      key_length         = 32
    }

    key_provider "gcp_kms" "logos" {
      encrypted_metadata_alias = "key_provider.gcp_kms.default"
      kms_encryption_key       = "projects/pt-corpus-tf16-prod/locations/us/keyRings/state-encryption/cryptoKeys/default"
      key_length               = 32
    }

    method "aes_gcm" "default" {
      keys = key_provider.gcp_kms.default
    }

    method "aes_gcm" "logos" {
      keys = key_provider.gcp_kms.logos
    }

    plan {
      method = method.aes_gcm.default
      # enforced = true

      fallback {
        method = method.unencrypted.migrate
      }
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.logos
      }
    }

    state {
      method = method.aes_gcm.default
      # enforced = true

      fallback {
        method = method.unencrypted.migrate
      }
    }
  }


  # Requiring Providers
  # https://opentofu.org/docs/language/providers/requirements#requiring-providers

  required_providers {

    # Datadog Provider
    # https://search.opentofu.org/provider/DataDog/datadog/latest/docs

    datadog = {
      source = "datadog/datadog"
    }

    # Google Cloud Platform Provider
    # https://search.opentofu.org/provider/hashicorp/google/latest/docs

    google = {
      source = "hashicorp/google"
    }

    # Random Provider
    # https://search.opentofu.org/provider/hashicorp/random/latest/docs

    random = {
      source = "hashicorp/random"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}

# Google Cloud Provider
# https://search.opentofu.org/provider/hashicorp/google/latest/docs

# provider "google" {
#   billing_project       = var.billing_project
#   user_project_override = true
# }
