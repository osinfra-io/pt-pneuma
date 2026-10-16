# Moved Resources
# https://opentofu.org/docs/language/modules/develop/refactoring/

moved {
  from = module.agentgateway.kubernetes_namespace_v1.agentgateway
  to   = kubernetes_namespace_v1.agentgateway
}
