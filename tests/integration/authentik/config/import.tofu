# Import
# https://opentofu.org/docs/language/import

import {
  id = var.embedded_outpost_id
  to = module.authentik_config.authentik_outpost.embedded
}

import {
  id = data.authentik_stage.default_authentication.id
  to = module.authentik_config.authentik_stage_identification.default_authentication[0]
}
