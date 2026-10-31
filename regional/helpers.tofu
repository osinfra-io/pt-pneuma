# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=7957efd127c1d2cf987104c7fb8e77b2f0a6eef1" # v0.3.7

  cost_center         = "x001"
  data_classification = "public"
  repository          = "pt-pneuma"
  team                = "pt-pneuma"
}
