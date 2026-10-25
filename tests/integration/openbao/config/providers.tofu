terraform {
  backend "local" {}

  required_providers {

    # OpenBao / Vault Provider
    # https://search.opentofu.org/provider/hashicorp/vault/latest

    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.13.0"
    }
  }
}

# OpenBao / Vault Provider
# https://search.opentofu.org/provider/hashicorp/vault/latest

provider "vault" {
  address = var.openbao_address
  token   = var.openbao_root_token
}
