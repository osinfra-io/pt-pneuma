# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=37126d7c6b48b027fc57272c7e58c49e8c3753ff" # v0.2.2

  cost_center         = "x001"
  data_classification = "public"

  logos_workspaces = ["pt-logos-main-production", "pt-pneuma-main-production"]

  repository = "pt-pneuma"
  team       = "pt-pneuma"
}
