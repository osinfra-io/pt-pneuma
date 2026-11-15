terraform {
  backend "local" {}

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.8.0"
    }
  }
}

provider "authentik" {
  insecure = true
  token    = var.authentik_token
  url      = var.authentik_url
}
