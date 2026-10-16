# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  crds_postrender = {
    args        = [abspath("${path.module}/../retain-crds.sh")]
    binary_path = "bash"
  }
}
