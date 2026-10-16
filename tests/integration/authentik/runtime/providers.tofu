terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
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
