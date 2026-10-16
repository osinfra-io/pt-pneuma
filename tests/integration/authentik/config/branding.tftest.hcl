# Shared Pneuma authentication regression
# https://opentofu.org/docs/cli/commands/test/

mock_provider "authentik" {
  mock_resource "authentik_flow" {
    defaults = {
      uuid = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_resource "authentik_provider_oauth2" {
    defaults = {
      id = "1"
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = "2"
    }
  }
}

variables {
  authentik_token            = "mock-local-token"
  embedded_outpost_id        = "mock-outpost"
  google_oauth_client_id     = "mock-google-client"
  google_oauth_client_secret = "mock-google-secret"
}

run "development_branding" {
  command = apply

  plan_options {
    target = [module.authentication]
  }

  assert {
    condition     = module.authentication.brands["sandbox"].domain == "authentik.localhost" && module.authentication.brands["sandbox"].branding_title == "osinfra.io | Development"
    error_message = "The Kubernetes fixture must retain the original local domain and branded title."
  }

  assert {
    condition     = module.authentication.brands["sandbox"].branding_logo == "https://docs.osinfra.io/img/osinfra-logo-full.png" && module.authentication.brands["sandbox"].branding_favicon == "https://docs.osinfra.io/img/mirko-transparent.png"
    error_message = "The local login must retain the original osinfra logo and favicon."
  }

  assert {
    condition     = jsondecode(module.authentication.brands["sandbox"].attributes).settings.theme.base == "dark" && strcontains(module.authentication.brands["sandbox"].branding_custom_css, "--pf-c-form-control--focus--after--BorderBottomColor: #606060")
    error_message = "The local login must use Pneuma's dark theme and exact sandbox CSS."
  }

  assert {
    condition     = module.authentication.brands["sandbox"].flow_authentication == module.authentication.flows["sandbox"].uuid && module.authentication.flows["sandbox"].title == "Welcome to osinfra.io development!"
    error_message = "The local brand must select the shared custom flow, not the built-in default flow."
  }

  assert {
    condition     = length(module.authentication.stage_bindings) == 4 && length(module.authentication.policy_bindings) == 2
    error_message = "Local authentication must exercise all shared stages and conditional policies."
  }
}
