terraform {
  # State and Plan Encryption
  # https://opentofu.org/docs/language/state/encryption

  # The commented out sections below demonstrate how to configure
  # fallback encryption methods for state and plan files for bootstrapping.

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
      # enforced = true

      fallback {
        method = method.unencrypted.migrate
      }
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.logos
      }

      remote_state_data_source "main" {
        method = method.aes_gcm.default
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

  required_providers {

    # Google Cloud Platform Provider
    # https://search.opentofu.org/provider/hashicorp/google/latest/docs

    google = {
      source = "hashicorp/google"
    }

    # Helm Provider
    # https://search.opentofu.org/provider/hashicorp/helm/latest/docs

    helm = {
      source = "hashicorp/helm"
    }

    # Kubernetes Provider
    # https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs

    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Helm Provider
# https://search.opentofu.org/provider/hashicorp/helm/latest
# One instance per cluster in this zone; modules receive the matching instance

provider "helm" {
  alias    = "by_cluster"
  for_each = var.clusters

  kubernetes = {

    cluster_ca_certificate = base64decode(
      data.google_container_cluster.this[each.key].master_auth.0.cluster_ca_certificate
    )

    host  = data.google_container_cluster.this[each.key].endpoint
    token = data.google_client_config.this.access_token
  }
}

# Kubernetes Provider
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest
# One instance per cluster in this zone; modules receive the matching instance

provider "kubernetes" {
  alias    = "by_cluster"
  for_each = var.clusters

  cluster_ca_certificate = base64decode(
    data.google_container_cluster.this[each.key].master_auth.0.cluster_ca_certificate
  )
  host  = "https://${data.google_container_cluster.this[each.key].endpoint}"
  token = data.google_client_config.this.access_token
}

# Helm Provider (state migration bridge)
# https://search.opentofu.org/provider/hashicorp/helm/latest
# Matches old state entries recorded with the unaliased provider before the
# per-cluster for_each refactor. Remove after the first successful apply.

provider "helm" {
  kubernetes = {
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.this["pt-pneuma-${regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0]}"].master_auth.0.cluster_ca_certificate
    )

    host  = data.google_container_cluster.this["pt-pneuma-${regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0]}"].endpoint
    token = data.google_client_config.this.access_token
  }
}

# Kubernetes Provider (state migration bridge)
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest
# Matches old state entries recorded with the unaliased provider before the
# per-cluster for_each refactor. Remove after the first successful apply.

provider "kubernetes" {
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.this["pt-pneuma-${regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0]}"].master_auth.0.cluster_ca_certificate
  )

  host  = "https://${data.google_container_cluster.this["pt-pneuma-${regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0]}"].endpoint}"
  token = data.google_client_config.this.access_token
}
