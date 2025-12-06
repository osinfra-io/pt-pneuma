terraform {
  # State and Plan Encryption
  # https://opentofu.org/docs/language/state/encryption

  encryption {
    key_provider "gcp_kms" "default" {
      kms_encryption_key = var.state_kms_encryption_key
      key_length         = 32
    }

    method "aes_gcm" "default" {
      keys = key_provider.gcp_kms.default
    }

    plan {
      enforced = true
      method   = method.aes_gcm.default
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.default
      }
    }

    state {
      enforced = true
      method   = method.aes_gcm.default
    }
  }

  # Requiring Providers
  # https://opentofu.org/docs/language/providers/requirements#requiring-providers

  required_providers {

    # Google Cloud Platform Provider
    # https://registry.terraform.io/providers/hashicorp/google/latest/docs

    google = {
      source = "hashicorp/google"
    }
  }
}

# Google Cloud Platform Provider
# https://registry.terraform.io/providers/hashicorp/google/latest/docs

provider "google" {
  region = module.helpers.region
}
