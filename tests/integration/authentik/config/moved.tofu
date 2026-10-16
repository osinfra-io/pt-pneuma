# Moved Resources
# https://opentofu.org/docs/language/modules/develop/refactoring

moved {
  from = authentik_brand.development
  to   = module.authentication.authentik_brand.sandbox["sandbox"]
}
