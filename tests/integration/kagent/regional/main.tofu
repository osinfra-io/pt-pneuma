module "kagent" {
  source = "../../../../../../arche/pt-arche-kubernetes-kagent/regional"

  depends_on = [
    kubernetes_secret_v1.openai,
    kubernetes_secret_v1.postgres_owner,
    kubernetes_secret_v1.postgres_read_write,
    kubernetes_stateful_set_v1.postgresql
  ]

  namespace           = kubernetes_namespace_v1.kagent.metadata[0].name
  substrate_namespace = "ate-system"
}

# Kubernetes Config Map
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/config_map_v1

resource "kubernetes_config_map_v1" "postgresql_init" {
  metadata {
    name      = "postgresql-init"
    namespace = kubernetes_namespace_v1.kagent.metadata[0].name
  }

  data = {
    "roles.sql" = <<-SQL
      CREATE ROLE kagent_owner;
      CREATE ROLE kagent_readwrite;
      GRANT ALL ON DATABASE kagent TO kagent_owner;
      GRANT CONNECT ON DATABASE kagent TO kagent_readwrite;
      CREATE SCHEMA kagent AUTHORIZATION kagent_owner;
      GRANT USAGE ON SCHEMA kagent TO kagent_readwrite;
      ALTER DEFAULT PRIVILEGES FOR ROLE kagent_owner IN SCHEMA kagent GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO kagent_readwrite;
      ALTER DEFAULT PRIVILEGES FOR ROLE kagent_owner IN SCHEMA kagent GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO kagent_readwrite;
    SQL
  }
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "authentik_outpost" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "authentik-outpost-kagent"
      namespace = "authentik"
    }
    spec = {
      hostnames = ["kagent.localhost"]
      parentRefs = [
        {
          name      = "gateway"
          namespace = "istio-ingress"
        }
      ]
      rules = [
        {
          backendRefs = [
            {
              name = "authentik-server"
              port = 80
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/outpost.goauthentik.io"
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "kagent_ui" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "kagent-ui"
      namespace = kubernetes_namespace_v1.kagent.metadata[0].name
    }
    spec = {
      hostnames = ["kagent.localhost"]
      parentRefs = [
        {
          name      = "gateway"
          namespace = "istio-ingress"
        }
      ]
      rules = [
        {
          backendRefs = [
            {
              name = module.kagent.ui_service_name
              port = module.kagent.ui_service_port
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
        }
      ]
    }
  }
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "kagent" {
  metadata {
    name = "kagent"

    # Substrate's NetworkPolicy admits only namespaces carrying this label to its API.
    labels = {
      "ate.dev/api-access" = "true"
    }
  }
}

# Kubernetes Secret
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

# The fixture sends no LLM traffic; the controller only needs the key Secret to exist.
resource "kubernetes_secret_v1" "openai" {
  metadata {
    name      = "kagent-openai"
    namespace = kubernetes_namespace_v1.kagent.metadata[0].name
  }

  data = {
    OPENAI_API_KEY = "local-fixture-unused"
  }
}

resource "kubernetes_secret_v1" "postgres_owner" {
  metadata {
    name      = "kagent-postgres-owner"
    namespace = kubernetes_namespace_v1.kagent.metadata[0].name
  }

  data = {
    ownerConnectionString = local.connection_string
  }
}

resource "kubernetes_secret_v1" "postgres_read_write" {
  metadata {
    name      = "kagent-postgres-readwrite"
    namespace = kubernetes_namespace_v1.kagent.metadata[0].name
  }

  data = {
    readWriteConnectionString = local.connection_string
  }
}

# Kubernetes Service
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "postgresql" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace_v1.kagent.metadata[0].name
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
    namespace = kubernetes_namespace_v1.kagent.metadata[0].name
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
            value = "kagent"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "local-fixture"
          }
          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres", "-d", "kagent"]
            }
          }
          volume_mount {
            mount_path = "/docker-entrypoint-initdb.d"
            name       = "init"
          }
          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "data"
          }
        }
        volume {
          name = "init"
          config_map {
            name = kubernetes_config_map_v1.postgresql_init.metadata[0].name
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
