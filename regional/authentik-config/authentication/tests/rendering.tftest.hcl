mock_provider "authentik" {
  mock_resource "authentik_flow" {
    defaults = {
      uuid = "00000000-0000-0000-0000-000000000001"
    }
  }
}

variables {
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

run "sandbox_identity_and_rendering" {
  command = apply

  assert {
    condition     = authentik_brand.sandbox["sandbox"].domain == "authentik.sb.osinfra.io" && authentik_brand.sandbox["sandbox"].branding_title == "osinfra.io | Sandbox" && authentik_flow.sandbox_authentication["sandbox"].title == "Welcome to osinfra.io sandbox!"
    error_message = "Sandbox domain, titles, and existing instance identity must remain unchanged."
  }

  assert {
    condition     = authentik_brand.sandbox["sandbox"].flow_authentication == authentik_flow.sandbox_authentication["sandbox"].uuid && authentik_flow.sandbox_authentication["sandbox"].slug == "sandbox-authentication-flow"
    error_message = "The brand must select the unchanged custom sandbox flow."
  }

  assert {
    condition     = authentik_flow.sandbox_authentication["sandbox"].authentication == "none" && !authentik_flow.sandbox_authentication["sandbox"].compatibility_mode && authentik_flow.sandbox_authentication["sandbox"].denied_action == "message_continue" && authentik_flow.sandbox_authentication["sandbox"].designation == "authentication" && authentik_flow.sandbox_authentication["sandbox"].layout == "stacked"
    error_message = "Custom flow behavior must remain unchanged."
  }

  assert {
    condition     = jsondecode(authentik_brand.sandbox["sandbox"].attributes).settings.theme.base == "dark" && strcontains(authentik_brand.sandbox["sandbox"].branding_custom_css, "--pf-c-form-control--focus--after--BorderBottomColor: #606060") && authentik_brand.sandbox["sandbox"].branding_logo == "https://docs.osinfra.io/img/osinfra-logo-full.png" && authentik_brand.sandbox["sandbox"].branding_favicon == "https://docs.osinfra.io/img/mirko-transparent.png" && !authentik_brand.sandbox["sandbox"].default
    error_message = "The existing sandbox dark theme, CSS, assets, and domain-only brand must remain unchanged."
  }

  assert {
    condition     = sha256("${authentik_brand.sandbox["sandbox"].branding_custom_css}\n") == "86d7ab3bd4412ddcd205868a988b9f967a990689137def86ac3b0a78b3e0059e"
    error_message = "The full original sandbox stylesheet must remain unchanged except its API-normalized terminal newline."
  }

  assert {
    condition = alltrue([
      for key, binding in authentik_flow_stage_binding.sandbox_authentication_stages :
      binding.stage == var.stage_ids[key] && binding.target == authentik_flow.sandbox_authentication["sandbox"].uuid && !binding.evaluate_on_plan && binding.re_evaluate_policies
    ]) && authentik_flow_stage_binding.sandbox_authentication_stages["identification"].order == 10 && authentik_flow_stage_binding.sandbox_authentication_stages["password"].order == 20 && authentik_flow_stage_binding.sandbox_authentication_stages["mfa_validation"].order == 30 && authentik_flow_stage_binding.sandbox_authentication_stages["login"].order == 100
    error_message = "Stage order, identities, and policy evaluation must remain unchanged."
  }

  assert {
    condition = length(authentik_policy_binding.sandbox_authentication_stage_policies) == 2 && alltrue([
      for key, binding in authentik_policy_binding.sandbox_authentication_stage_policies :
      binding.policy == var.policy_ids[key] && binding.target == authentik_flow_stage_binding.sandbox_authentication_stages[key].id && binding.failure_result && binding.order == 10
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

run "production_and_nonproduction_disabled" {
  command = plan

  variables {
    enabled    = false
    policy_ids = {}
    stage_ids  = {}
  }

  assert {
    condition     = length(authentik_brand.sandbox) == 0 && length(authentik_flow.sandbox_authentication) == 0 && length(authentik_flow_stage_binding.sandbox_authentication_stages) == 0 && length(authentik_policy_binding.sandbox_authentication_stage_policies) == 0
    error_message = "Disabled environments must not create a custom flow, brand, or bindings."
  }

  assert {
    condition     = output.default_authentication_stage_settings.password_stage == null && output.default_authentication_stage_settings.case_insensitive_matching && length(output.authentication_stages) == 4
    error_message = "Default identification settings must remain available when the custom flow is disabled."
  }
}
