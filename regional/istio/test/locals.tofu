# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  datadog_mci_synthetic_url          = module.core_helpers.environment == "production" ? "https://gcp.osinfra.io/${local.datadog_synthetic_service}/metadata/cluster-name" : "https://${module.core_helpers.env}.gcp.osinfra.io/${local.datadog_synthetic_service}/metadata/cluster-name"
  datadog_synthetic_message_critical = module.core_helpers.environment == "production" ? "@hangouts-Platform-CriticalHighPriority" : ""
  datadog_synthetic_message_medium   = module.core_helpers.environment == "production" ? "@hangouts-Platform-MediumLowInfoPriority" : ""
  datadog_synthetic_name             = "Istio Test"
  datadog_synthetic_service          = "istio-test"

  datadog_synthetic_tests = module.core_helpers.region == "us-east1" || module.core_helpers.zone == "b" ? {
    "mci" = {
      locations = [
        "aws:ca-central-1",
        "aws:us-west-1",
        "aws:us-east-1",
        "aws:eu-central-1",
        "aws:eu-south-1",
        "aws:eu-north-1",
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_critical
      message_priority = "1"
      name             = "MCI ${local.datadog_synthetic_name}"
      region           = "global"

      request_headers = {}

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = local.datadog_mci_synthetic_url
    }

    "mci-us-east1" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "MCI ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = local.datadog_mci_synthetic_url
    }

    "mci-us-east4" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "MCI ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = local.datadog_mci_synthetic_url
    }

    "us-east1" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "Ingress ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = module.core_helpers.environment == "production" ? "https://us-east1.gcp.osinfra.io/${local.datadog_synthetic_service}" : "https://us-east1.${module.core_helpers.env}.gcp.osinfra.io/${local.datadog_synthetic_service}"
    }

    "us-east4" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "Ingress ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = module.core_helpers.environment == "production" ? "https://us-east4.gcp.osinfra.io/${local.datadog_synthetic_service}" : "https://us-east4.${module.core_helpers.env}.gcp.osinfra.io/${local.datadog_synthetic_service}"
    }
  } : {}

  kubernetes_project = data.terraform_remote_state.main.outputs.project_id
  registry           = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"
}
