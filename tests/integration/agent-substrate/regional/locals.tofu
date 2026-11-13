# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  crds_postrender = {
    args        = [abspath("${path.module}/../../agentgateway/retain-crds.sh")]
    binary_path = "bash"
  }

  # The users and database are created by the upstream setup.sql that setup.sh applies.
  connection_string_suffix = "@postgresql.ate-system.svc.cluster.local:5432/substrate?sslmode=disable"

  owner_connection_string      = "postgresql://substrate_owner_user:local-fixture${local.connection_string_suffix}"
  read_write_connection_string = "postgresql://substrate_readwrite_user:local-fixture${local.connection_string_suffix}"
}
