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
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=f326d09b418821f34bc84bbf2225a7157d520e36" # v0.2.7

  depends_on = [terraform_data.browser_group_policy_validation]

  application_groups                    = module.team_access.application_groups
  authentik_url                         = local.authentik_url
  browser_group_policy_bindings         = local.browser_group_policy_bindings
  default_authentication_source_uuids   = local.default_authentication_source_uuids
  default_authentication_stage_settings = module.authentication.default_authentication_stage_settings
  external_host                         = local.external_host
  google_internal_domains               = ["osinfra.io"]
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  manage_default_authentication_stage   = local.manage_default_authentication_stage
  namespace                             = local.namespace
  openbao_hostname                      = local.main.openbao_hostname
  redirect_uris                         = local.redirect_uris
  superuser_group_keys                  = local.authentik_superuser_group_keys
}

# Team Application Access Module (osinfra.io)
# https://github.com/osinfra-io/pt-pneuma

module "team_access" {
  source = "./team-access"

  environment = module.core_helpers.environment
  teams       = module.core_helpers.teams
}

# Terraform Data Resource
# https://search.opentofu.org/provider/hashicorp/terraform/latest/docs/resources/data

resource "terraform_data" "browser_group_policy_validation" {
  lifecycle {
    precondition {
      condition     = module.core_helpers.environment != "sandbox" || contains(keys(module.team_access.application_group_members), "${module.core_helpers.team}: agentgateway Admins")
      error_message = "Deploy the Logos agentgateway application-group declaration before enabling its sandbox Authentik provider."
    }

    precondition {
      condition     = length(local.browser_group_policy_conflicting_hosts) == 0
      error_message = "Browser routes sharing an Authentik host must declare identical required_groups and required_roles. Conflicting hosts: ${join(", ", local.browser_group_policy_conflicting_hosts)}."
    }
  }
}
