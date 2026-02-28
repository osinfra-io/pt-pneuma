# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-core-helpers

module "helpers" {
  source = "github.com/osinfra-io/opentofu-core-helpers//root?ref=6e95a998fa8a1d06389a501146bb6717f49dab48" # v0.2.0

  cost_center         = "x001"
  data_classification = "public"

  logos_workspaces = ["pt-logos-main-production", "pt-pneuma-main-production"]

  repository = "pt-pneuma"
  team       = "pt-pneuma"
}
