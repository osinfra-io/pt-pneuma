# Import
# https://opentofu.org/docs/language/import

import {
  for_each = var.import_built_in_brand ? toset(["built_in"]) : toset([])

  id = data.authentik_brand.built_in.id
  to = module.authentication.authentik_brand.built_in
}

import {
  id = var.embedded_outpost_id
  to = module.authentik_config.authentik_outpost.embedded
}

import {
  id = data.authentik_stage.default_authentication.id
  to = module.authentik_config.authentik_stage_identification.default_authentication
}
