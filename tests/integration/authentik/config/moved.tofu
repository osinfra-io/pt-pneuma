# Moved Resources
# https://opentofu.org/docs/language/modules/develop/refactoring

moved {
  from = authentik_brand.development
  to   = module.authentication.authentik_brand.sandbox["sandbox"]
}

moved {
  from = module.authentication.authentik_brand.sandbox["sandbox"]
  to   = module.authentication.authentik_brand.this
}

moved {
  from = module.authentication.authentik_flow.sandbox_authentication["sandbox"]
  to   = module.authentication.authentik_flow.authentication
}

moved {
  from = module.authentication.authentik_flow_stage_binding.sandbox_authentication_stages
  to   = module.authentication.authentik_flow_stage_binding.authentication_stages
}

moved {
  from = module.authentication.authentik_policy_binding.sandbox_authentication_stage_policies
  to   = module.authentication.authentik_policy_binding.authentication_stage_policies
}
