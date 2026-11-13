# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  connection_string = "postgres://postgres:local-fixture@postgresql.kagent.svc.cluster.local:5432/kagent?sslmode=disable"
}
