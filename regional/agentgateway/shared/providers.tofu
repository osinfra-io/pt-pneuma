terraform {
  encryption {
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
      enforced = true
      method   = method.aes_gcm.default
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.logos
      }
    }

    state {
      enforced = true
      method   = method.aes_gcm.default
    }
  }

  required_providers {
    google = {
      source = "hashicorp/google"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "google" {
  add_terraform_attribution_label = false
  user_project_override           = true
}

provider "helm" {
  alias    = "by_cluster"
  for_each = var.clusters

  kubernetes = {
    cluster_ca_certificate = base64decode(data.google_container_cluster.this[each.key].master_auth[0].cluster_ca_certificate)
    host                   = "https://${data.google_container_cluster.this[each.key].endpoint}"
    token                  = data.google_client_config.this.access_token
  }
}

provider "kubernetes" {
  alias    = "by_cluster"
  for_each = var.clusters

  cluster_ca_certificate = base64decode(data.google_container_cluster.this[each.key].master_auth[0].cluster_ca_certificate)
  host                   = "https://${data.google_container_cluster.this[each.key].endpoint}"
  token                  = data.google_client_config.this.access_token
}
