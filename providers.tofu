terraform {

  # State and Plan Encryption
  # https://opentofu.org/docs/language/state/encryption

  # The default key provider, method, and enforced plan/state encryption are supplied by the called workflow
  # through TF_ENCRYPTION and merged with this configuration.

  encryption {
    key_provider "gcp_kms" "logos" {
      encrypted_metadata_alias = "key_provider.gcp_kms.default"
      key_length               = 32
      kms_encryption_key       = "projects/pt-corpus-tf16-prod/locations/us/keyRings/state-encryption/cryptoKeys/default"
    }

    method "aes_gcm" "logos" {
      keys = key_provider.gcp_kms.logos
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.logos
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

    # Google Cloud Platform Beta Provider
    # https://search.opentofu.org/provider/hashicorp/google-beta/latest/docs

    google-beta = {
      source = "hashicorp/google-beta"
    }

    # Random Provider
    # https://search.opentofu.org/provider/hashicorp/random/latest/docs

    random = {
      source = "hashicorp/random"
    }

    # TLS Provider
    # https://search.opentofu.org/provider/hashicorp/tls/latest/docs

    tls = {
      source = "hashicorp/tls"
    }
  }
}

# Google Cloud Platform Beta Provider
# https://search.opentofu.org/provider/hashicorp/google-beta/latest/docs

provider "google-beta" {}

# Google Cloud Provider
# https://search.opentofu.org/provider/hashicorp/google/latest/docs

# provider "google" {
#   billing_project       = var.billing_project
#   user_project_override = true
# }
