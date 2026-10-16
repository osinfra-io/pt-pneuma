# Kubernetes Authentik
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik" {
  source = "../../../../../../arche/pt-arche-kubernetes-authentik/regional"

  depends_on = [kubernetes_secret_v1.authentik, kubernetes_stateful_set_v1.postgresql]

  existing_secret        = kubernetes_secret_v1.authentik.metadata[0].name
  external_database_host = "postgresql.authentik.svc.cluster.local"
  namespace              = "authentik"
  server_replicas        = 1
}

# Kubernetes Secret
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

resource "kubernetes_secret_v1" "authentik" {
  metadata {
    name      = "authentik-local"
    namespace = "authentik"
  }

  data = var.secret_env
}

# Kubernetes Service
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = "authentik"
  }

  spec {
    port {
      port        = 5432
      target_port = 5432
    }
    selector = {
      app = "postgresql"
    }
  }
}

# Kubernetes Stateful Set
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/stateful_set_v1

resource "kubernetes_stateful_set_v1" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = "authentik"
  }

  spec {
    persistent_volume_claim_retention_policy {
      when_deleted = "Retain"
      when_scaled  = "Retain"
    }
    replicas     = 1
    service_name = kubernetes_service_v1.postgresql.metadata[0].name
    selector {
      match_labels = {
        app = "postgresql"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgresql"
        }
      }
      spec {
        container {
          image = "postgres:16-alpine"
          name  = "postgresql"
          env {
            name  = "POSTGRES_DB"
            value = "authentik"
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key  = "AUTHENTIK_POSTGRESQL__PASSWORD"
                name = kubernetes_secret_v1.authentik.metadata[0].name
              }
            }
          }
          env {
            name  = "POSTGRES_USER"
            value = "authentik"
          }
          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "authentik", "-d", "authentik"]
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
