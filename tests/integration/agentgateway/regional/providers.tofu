terraform {
  backend "local" {}
}

provider "helm" {
  kubernetes = {
    config_context = "docker-desktop"
    config_path    = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_context = "docker-desktop"
  config_path    = "~/.kube/config"
}
