# Moved Resources
# https://opentofu.org/docs/language/modules/develop/refactoring

moved {
  from = authentik_brand.sandbox
  to   = module.authentication.authentik_brand.sandbox
}

moved {
  from = authentik_flow.sandbox_authentication
  to   = module.authentication.authentik_flow.sandbox_authentication
}

moved {
  from = authentik_flow_stage_binding.sandbox_authentication_stages
  to   = module.authentication.authentik_flow_stage_binding.sandbox_authentication_stages
}

moved {
  from = authentik_policy_binding.sandbox_authentication_stage_policies
  to   = module.authentication.authentik_policy_binding.sandbox_authentication_stage_policies
}
