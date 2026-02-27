# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  cluster_name = data.terraform_remote_state.regional.outputs.kubernetes_engine_cluster_name
}
