# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=b4a782e4beb4d347ebdb7dc0af4df6744f6faa84" # v0.3.6

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
