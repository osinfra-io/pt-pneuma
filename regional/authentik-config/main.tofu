# Pneuma Authentication
# https://github.com/osinfra-io/pt-pneuma

module "authentication" {
  source = "./authentication"

  brand_domain = local.sandbox_brand_domain
  brand_title  = local.sandbox_brand_title
  enabled      = var.sandbox_authentication_enabled
  flow_title   = local.sandbox_flow_title
  policy_ids   = local.authentication_policy_ids
  stage_ids    = local.authentication_stage_ids
}

# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=af6e9e6371f216aa61fd710e3f0af6eed5657fcd" # v0.1.8

  depends_on = [terraform_data.browser_group_policy_validation]

  authentik_url                         = local.authentik_url
  browser_group_policy_bindings         = local.browser_group_policy_bindings
  default_authentication_source_uuids   = local.default_authentication_source_uuids
  default_authentication_stage_settings = module.authentication.default_authentication_stage_settings
  external_host                         = local.external_host
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  manage_default_authentication_stage   = local.manage_default_authentication_stage
  namespace                             = local.namespace
  redirect_uris                         = local.redirect_uris
}

# Terraform Data Resource
# https://search.opentofu.org/provider/hashicorp/terraform/latest/docs/resources/data

resource "terraform_data" "browser_group_policy_validation" {
  lifecycle {
    precondition {
      condition     = length(local.browser_group_policy_conflicting_hosts) == 0
      error_message = "Browser routes sharing an Authentik host must declare identical required_groups and required_roles. Conflicting hosts: ${join(", ", local.browser_group_policy_conflicting_hosts)}."
    }
  }
}
