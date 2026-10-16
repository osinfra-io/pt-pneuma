module "agentgateway_local" {
  source = "../../../../../../arche/pt-arche-kubernetes-agentgateway/regional/local"

  namespace = "agentgateway"
}
