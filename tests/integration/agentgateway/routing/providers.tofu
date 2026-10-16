terraform {
  backend "local" {}
}

provider "kubernetes" {
  config_context = "docker-desktop"
  config_path    = "~/.kube/config"
}
