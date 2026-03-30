# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=1024a5446b33be60bba2d52897ba4f487cb469ed" # v0.2.3

  cost_center         = "x001"
  data_classification = "public"
  repository          = "pt-pneuma"
  team                = "pt-pneuma"
}
