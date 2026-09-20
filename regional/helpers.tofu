# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=acab8925a01c1e0b2c06f2c31631c3034024acd3" # v0.3.4

  cost_center         = "x001"
  data_classification = "public"
  repository          = "pt-pneuma"
  team                = "pt-pneuma"
}
