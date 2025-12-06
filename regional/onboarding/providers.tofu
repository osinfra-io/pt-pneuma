# Required Providers
# https://opentofu.org/docs/language/providers/requirements/

terraform {
  # State and Plan Encryption
  # https://opentofu.org/docs/language/state/encryption

  encryption {
    method "unencrypted" "migrate" {}

    key_provider "gcp_kms" "default" {
      key_length         = 32
      kms_encryption_key = var.state_kms_encryption_key
    }

    method "aes_gcm" "default" {
      keys = key_provider.gcp_kms.default
    }

    plan {
      fallback {
        method = method.unencrypted.migrate
      }

      method = method.aes_gcm.default
    }

    remote_state_data_sources {
      default {
        method = method.aes_gcm.default
      }
    }

    state {
      fallback {
        method = method.unencrypted.migrate
      }

      method = method.aes_gcm.default
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

# Helm Provider
# https://search.opentofu.org/provider/hashicorp/helm/latest

provider "helm" {
  kubernetes = {
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.this.master_auth.0.cluster_ca_certificate
    )

    host  = data.google_container_cluster.this.endpoint
    token = data.google_client_config.this.access_token
  }
}

# Kubernetes Provider
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest

provider "kubernetes" {
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.this.master_auth.0.cluster_ca_certificate
  )

  host  = "https://${data.google_container_cluster.this.endpoint}"
  token = data.google_client_config.this.access_token
}
