terraform {
  # State and Plan Encryption
  # https://opentofu.org/docs/language/state/encryption

  encryption {
    method "unencrypted" "migrate" {}

    key_provider "gcp_kms" "default" {
      key_length         = 32
      kms_encryption_key = var.state_kms_encryption_key
    }

    key_provider "gcp_kms" "logos" {
      encrypted_metadata_alias = "key_provider.gcp_kms.default"
      key_length               = 32
      kms_encryption_key       = "projects/pt-corpus-tf16-prod/locations/us/keyRings/state-encryption/cryptoKeys/default"
    }

    method "aes_gcm" "default" {
      keys = key_provider.gcp_kms.default
    }

    method "aes_gcm" "logos" {
      keys = key_provider.gcp_kms.logos
    }

    plan {
      method = method.aes_gcm.default

      fallback {
        method = method.unencrypted.migrate
      }
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.logos
      }

      remote_state_data_source "authentik" {
        method = method.aes_gcm.default
      }
    }

    state {
      method = method.aes_gcm.default

      fallback {
        method = method.unencrypted.migrate
      }
    }
  }

  required_providers {

    # Authentik Provider
    # https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

    authentik = {
      source = "goauthentik/authentik"
    }
  }
}

# Authentik Provider
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs
# A single gateway Authentik per zonal workspace; configured from the authentik workspace outputs.

provider "authentik" {
  token = local.authentik_token
  url   = local.authentik_url
}
