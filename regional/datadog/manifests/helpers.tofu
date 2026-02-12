# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-core-helpers

module "helpers" {
  source = "github.com/osinfra-io/opentofu-core-helpers//root?ref=9dd94ed371bda83e5ad74abd6b5ba08d2e1c36d3" # v0.4.1

  cost_center         = "x001"
  data_classification = "public"
  logos_workspaces    = ["pt-corpus-main-production", "pt-logos-main-production", "pt-pneuma-main-production", "st-ethos-main-production"]
  repository          = "pt-pneuma"
  team                = "pt-pneuma"
}
