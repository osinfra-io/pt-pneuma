# Datadog Logs Pipelines Data Source
# https://search.opentofu.org/provider/datadog/datadog/latest/docs/datasources/logs_pipelines

data "datadog_logs_pipelines" "this" {}

# Terraform Remote State Data Source - Main
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket
    prefix = module.core_helpers.repository
  }

  workspace = "main-${module.core_helpers.environment}"
}
