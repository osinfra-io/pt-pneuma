# Test
# https://opentofu.org/docs/cli/commands/test

mock_provider "helm" {}
mock_provider "kubernetes" {}

run "local_postgresql_retains_data" {
  command = plan

  variables {
    secret_env = {
      AUTHENTIK_BOOTSTRAP_PASSWORD   = "mock-bootstrap-password"
      AUTHENTIK_BOOTSTRAP_TOKEN      = "mock-bootstrap-token"
      AUTHENTIK_POSTGRESQL__PASSWORD = "mock-database-password"
      AUTHENTIK_SECRET_KEY           = "mock-secret-key"
    }
  }

  assert {
    condition     = kubernetes_stateful_set_v1.postgresql.spec[0].persistent_volume_claim_retention_policy[0].when_deleted == "Retain"
    error_message = "Normal runtime teardown must retain the PostgreSQL volume."
  }

  assert {
    condition     = kubernetes_stateful_set_v1.postgresql.metadata[0].namespace == "authentik" && kubernetes_secret_v1.authentik.metadata[0].namespace == "authentik"
    error_message = "Runtime resources must stay in the separately managed persistent namespace."
  }
}
