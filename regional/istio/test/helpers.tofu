# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=7e9435f875ac91ac8538385fe8b4554dd068673e" # v0.3.2

  cost_center         = "x001"
  data_classification = "public"
  repository          = "pt-pneuma"
  team                = "pt-pneuma"
}
