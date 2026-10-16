terraform {
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
  url      = "https://127.0.0.1:19443"
}
