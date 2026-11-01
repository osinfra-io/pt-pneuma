mock_provider "authentik" {
  mock_resource "authentik_flow" {
    defaults = {
      uuid = "00000000-0000-0000-0000-000000000001"
    }
  }
}

variables {
  brand_domain = "authentik.sb.osinfra.io"
  brand_title  = "osinfra.io | Sandbox"
  flow_title   = "Welcome to osinfra.io sandbox!"
  policy_ids = {
    mfa_validation = "mock-mfa-policy"
    password       = "mock-password-policy"
  }
  stage_ids = {
    identification = "mock-identification-stage"
    login          = "mock-login-stage"
    mfa_validation = "mock-mfa-stage"
    password       = "mock-password-stage"
  }
}

run "identity_and_rendering" {
  command = apply

  assert {
    condition     = authentik_brand.this.domain == "authentik.sb.osinfra.io" && authentik_brand.this.branding_title == "osinfra.io | Sandbox" && authentik_flow.authentication.title == "Welcome to osinfra.io sandbox!"
    error_message = "The brand and flow must use the caller-supplied domain and titles."
  }

  assert {
    condition     = authentik_brand.this.flow_authentication == authentik_flow.authentication.uuid && authentik_flow.authentication.slug == "osinfra-authentication-flow"
    error_message = "The brand must select the custom authentication flow."
  }

  assert {
    condition     = authentik_flow.authentication.authentication == "none" && !authentik_flow.authentication.compatibility_mode && authentik_flow.authentication.denied_action == "message_continue" && authentik_flow.authentication.designation == "authentication" && authentik_flow.authentication.layout == "stacked"
    error_message = "Custom flow behavior must remain unchanged."
  }

  assert {
    condition     = jsondecode(authentik_brand.this.attributes).settings.theme.base == "dark" && strcontains(authentik_brand.this.branding_custom_css, "--pf-c-form-control--focus--after--BorderBottomColor: #606060") && authentik_brand.this.branding_logo == "https://docs.osinfra.io/img/osinfra-logo-full.png" && authentik_brand.this.branding_favicon == "https://docs.osinfra.io/img/mirko-transparent.png" && authentik_brand.this.default
    error_message = "The dark theme, CSS, assets, and default brand must remain unchanged."
  }

  assert {
    condition     = sha256("${authentik_brand.this.branding_custom_css}\n") == "86d7ab3bd4412ddcd205868a988b9f967a990689137def86ac3b0a78b3e0059e"
    error_message = "The full original stylesheet must remain unchanged except its API-normalized terminal newline."
  }

  assert {
    condition = alltrue([
      for key, binding in authentik_flow_stage_binding.authentication_stages :
      binding.stage == var.stage_ids[key] && binding.target == authentik_flow.authentication.uuid && !binding.evaluate_on_plan && binding.re_evaluate_policies
    ]) && authentik_flow_stage_binding.authentication_stages["identification"].order == 10 && authentik_flow_stage_binding.authentication_stages["password"].order == 20 && authentik_flow_stage_binding.authentication_stages["mfa_validation"].order == 30 && authentik_flow_stage_binding.authentication_stages["login"].order == 100
    error_message = "Stage order, identities, and policy evaluation must remain unchanged."
  }

  assert {
    condition = length(authentik_policy_binding.authentication_stage_policies) == 2 && alltrue([
      for key, binding in authentik_policy_binding.authentication_stage_policies :
      binding.policy == var.policy_ids[key] && binding.target == authentik_flow_stage_binding.authentication_stages[key].id && binding.failure_result && binding.order == 10
    ])
    error_message = "Password and MFA policies must remain bound to their respective stages."
  }

  assert {
    condition     = output.authentication_stages["identification"].name == "default-authentication-identification" && output.authentication_stages["password"].name == "default-authentication-password" && output.authentication_stages["mfa_validation"].name == "default-authentication-mfa-validation" && output.authentication_stages["login"].name == "default-authentication-login" && output.authentication_stage_policies["password"].policy_name == "default-authentication-flow-password-stage" && output.authentication_stage_policies["mfa_validation"].policy_name == "default-authentication-flow-authenticator-validate-stage"
    error_message = "Discovery must retain the built-in stage and policy names."
  }

  assert {
    condition = output.default_authentication_stage_settings == {
      captcha_stage             = null
      case_insensitive_matching = true
      enable_remember_me        = false
      enrollment_flow           = null
      password_stage            = null
      passwordless_flow         = null
      pretend_user_exists       = true
      recovery_flow             = null
      show_matched_user         = true
      show_source_labels        = false
      user_fields               = ["email", "username"]
      webauthn_stage            = null
    }
    error_message = "Both callers must use the original identification settings, including separate password-stage wiring."
  }
}
