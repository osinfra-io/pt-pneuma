# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  kubernetes_project = data.google_project.kubernetes.project_id
}
