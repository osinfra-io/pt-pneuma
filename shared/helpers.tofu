# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=7712df4d2b0a6333ff74ae7b626c593033019082" # v0.3.3

  cost_center         = "x001"
  data_classification = "public"

  logos_workspaces = [
    "pt-corpus-main-production",
    "pt-kryptos-main-production",
    "pt-logos-main-production",
    "pt-pneuma-main-production",
    "pt-techne-main-production",
    "st-ethos-main-production",
  ]

  repository = "pt-pneuma"
  team       = "pt-pneuma"
}
