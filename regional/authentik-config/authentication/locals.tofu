# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  authentication_stage_policies = {
    for key, stage in local.authentication_stages : key => stage
    if try(stage.policy_name, null) != null
  }

  authentication_stages = {
    identification = {
      name  = "default-authentication-identification"
      order = 10
    }
    login = {
      name  = "default-authentication-login"
      order = 100
    }
    mfa_validation = {
      name        = "default-authentication-mfa-validation"
      order       = 30
      policy_name = "default-authentication-flow-authenticator-validate-stage"
    }
    password = {
      name        = "default-authentication-password"
      order       = 20
      policy_name = "default-authentication-flow-password-stage"
    }
  }

  brand_attributes = jsonencode({
    settings = {
      theme = {
        base = "dark"
      }
    }
  })

  brand_custom_css = <<-EOT
    :root {
      --ak-c-login--BackgroundColorOverlay: rgba(30, 30, 30, 0.94);
      --ak-c-login__main--BackgroundColor: #232323;
      --ak-c-login__main--Color: #e0e0e0;
      --pf-global--BackgroundColor--100: #1e1e1e;
      --pf-global--BackgroundColor--200: #232323;
      --pf-global--Color--100: #e0e0e0;
      --pf-global--Color--200: #a0a0a0;
      --pf-global--primary-color--100: #ffb400;
      --pf-global--primary-color--200: #e6a200;
      --pf-c-form-control--BackgroundColor: #2b2b2b;
      --pf-c-form-control--after--BorderBottomColor: #484848;
      --pf-c-form-control--focus--after--BorderBottomColor: #606060;
      --pf-c-form-control--hover--after--BorderBottomColor: #606060;
      --pf-c-form-control--m-expanded--after--BorderBottomColor: #606060;
    }

    ::selection {
      background-color: #484848;
      color: #ffffff;
    }

    .pf-c-background-image {
      background-color: #1e1e1e !important;
      background-image: none !important;
    }

    .pf-c-login__main {
      border: 1px solid #353535;
      border-radius: 8px;
    }

    input,
    textarea,
    select {
      background-color: #2b2b2b !important;
      border-color: #484848 !important;
      color: #e0e0e0 !important;
    }

    input:focus,
    input:focus-visible,
    textarea:focus,
    textarea:focus-visible,
    select:focus,
    select:focus-visible {
      background-color: #303030 !important;
      border-color: #606060 !important;
      box-shadow: inset 0 -2px 0 #606060 !important;
      outline-color: #606060 !important;
    }

    input:autofill,
    input:-webkit-autofill,
    input:-webkit-autofill:focus,
    input:-webkit-autofill:hover {
      -webkit-text-fill-color: #e0e0e0 !important;
      box-shadow: inset 0 0 0 1000px #303030 !important;
      caret-color: #e0e0e0;
    }

    .pf-c-button.pf-m-primary {
      background-color: #ffb400;
      color: #1e1e1e;
    }

    .pf-c-button.pf-m-primary:hover {
      background-color: #e6a200;
    }

    #ak-back-home {
      background-color: #ffb400 !important;
      color: #1e1e1e !important;
    }

    #ak-back-home:active,
    #ak-back-home:focus,
    #ak-back-home:hover {
      background-color: #e6a200 !important;
      color: #1e1e1e !important;
    }

    a {
      color: #ffb400;
    }
  EOT

  # Authentik strips the final newline; normalize it to avoid perpetual in-place updates.
  brand_custom_css_api = chomp(local.brand_custom_css)

  default_authentication_stage_settings = {
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

  enabled_stage_policies = var.enabled ? local.authentication_stage_policies : {}
  enabled_stages         = var.enabled ? local.authentication_stages : {}

  # Retain the cloud instance key so whole-resource moved blocks preserve existing state.
  instances = var.enabled ? toset(["sandbox"]) : toset([])
}
