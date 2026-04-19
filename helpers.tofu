# OpenTofu Core Helpers Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-core-helpers

module "core_helpers" {
  source = "github.com/osinfra-io/pt-arche-core-helpers//root?ref=70c1e4f4a11acdcfc36055bdd3aa16579d4203a1" # v0.3.1

  cost_center         = "x001"
  data_classification = "public"

  logos_workspaces = [
    "pt-corpus-main-production",
    "pt-kryptos-main-production",
    "pt-logos-main-production",
    "pt-pneuma-main-production",
  ]

  repository = "pt-pneuma"
  team       = "pt-pneuma"
}
