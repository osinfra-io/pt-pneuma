# Moved Blocks
# https://opentofu.org/docs/language/moved

# The per-team for_each refactor re-keyed these modules from their original
# single-instance addresses to pt-pneuma-keyed addresses. These moved blocks
# map the existing state and GCP resources in-place so OpenTofu does not
# destroy and recreate them (which would 409 on resources with fixed names
# such as the istio gateway global address, security policy, and SSL policy).

moved {
  from = module.google_kubernetes_engine
  to   = module.google_kubernetes_engine["pt-pneuma"]
}

moved {
  from = module.kubernetes_cert_manager
  to   = module.kubernetes_cert_manager["pt-pneuma"]
}

moved {
  from = module.kubernetes_istio
  to   = module.kubernetes_istio["pt-pneuma"]
}
