module "agent_substrate" {
  source = "../../../../../../arche/pt-arche-kubernetes-agent-substrate/regional"

  depends_on = [
    kubernetes_secret_v1.postgres_owner,
    kubernetes_secret_v1.postgres_read_write,
    kubernetes_secret_v1.rustfs_credentials,
    kubernetes_stateful_set_v1.postgresql
  ]

  crds_postrender            = local.crds_postrender
  ingress_allowed_spiffe_ids = ["spiffe://cluster.local/ns/kagent/sa/kagent-controller"]
  namespace                  = kubernetes_namespace_v1.agent_substrate.metadata[0].name
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "agent_substrate" {
  metadata {
    name = "ate-system"
  }
}

# Kubernetes Secret
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

resource "kubernetes_secret_v1" "postgres_owner" {
  metadata {
    name      = "substrate-postgres-owner"
    namespace = kubernetes_namespace_v1.agent_substrate.metadata[0].name
  }

  data = {
    ownerConnectionString = local.owner_connection_string
  }
}

resource "kubernetes_secret_v1" "postgres_read_write" {
  metadata {
    name      = "substrate-postgres-readwrite"
    namespace = kubernetes_namespace_v1.agent_substrate.metadata[0].name
  }

  data = {
    readWriteConnectionString = local.read_write_connection_string
  }
}

resource "kubernetes_secret_v1" "rustfs_credentials" {
  metadata {
    name      = "rustfs-credentials"
    namespace = kubernetes_namespace_v1.agent_substrate.metadata[0].name
  }

  # The substrate chart's bundled RustFS defaults.
  data = {
    AWS_ACCESS_KEY_ID     = "rustfsadmin"
    AWS_SECRET_ACCESS_KEY = "rustfsadmin"
  }
}

# Kubernetes Service
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace_v1.agent_substrate.metadata[0].name
  }

  spec {
    port {
      port        = 5432
      target_port = "postgres"
    }
    selector = {
      app = "postgres"
    }
  }
}

# Kubernetes Stateful Set
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/stateful_set_v1

resource "kubernetes_stateful_set_v1" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace_v1.agent_substrate.metadata[0].name
  }

  spec {
    persistent_volume_claim_retention_policy {
      when_deleted = "Delete"
      when_scaled  = "Delete"
    }
    replicas     = 1
    service_name = kubernetes_service_v1.postgresql.metadata[0].name
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          image = "postgres:16-alpine"
          name  = "postgresql"
          port {
            container_port = 5432
            name           = "postgres"
          }
          env {
            name  = "POSTGRES_DB"
            value = "substrate"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "local-fixture"
          }
          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres", "-d", "substrate"]
            }
          }
          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "data"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "data"
      }

      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}
