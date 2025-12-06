# Data Source: pt-corpus Kubernetes Project
# Reference the Kubernetes project created by pt-corpus for this team

data "terraform_remote_state" "corpus" {
  backend = "gcs"

  config = {
    bucket = "pt-corpus-state-${module.helpers.env}"
  }

  workspace = "main-${module.helpers.env == "sb" ? "sandbox" : module.helpers.env == "np" ? "non-production" : "production"}"
}
