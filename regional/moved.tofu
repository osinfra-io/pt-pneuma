# Moved Blocks
# https://opentofu.org/docs/language/moved

moved {
  from = module.helpers
  to   = module.core_helpers
}

moved {
  from = module.kubernetes_engine_regional
  to   = module.google_kubernetes_engine_regional
}
