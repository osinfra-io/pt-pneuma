module "agentgateway_manifests" {
  source = "../../../../../../arche/pt-arche-kubernetes-agentgateway/regional/manifests"

  namespace = "agentgateway"

  proxy_env = {
    ADMIN_ADDR = "0.0.0.0:15000"
  }
}
