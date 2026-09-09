# Import
# https://opentofu.org/docs/language/import

# The embedded outpost ships with Authentik, so we import it (rather than create it) to assign
# the gateway proxy provider. This makes each regional authentik-server serve forward-auth
# locally for Istio ext_authz without a managed outpost deployment.
import {
  id = data.authentik_outpost.embedded.id
  to = module.authentik_config.authentik_outpost.embedded
}

# The default authentication flow's identification stage is a pre-existing, shared object built
# into every Authentik instance, so we import it (rather than create it) to add the Google source
# to its "sources" list without touching any of its other live settings.
import {
  id = data.authentik_stage.default_authentication_identification.id
  to = module.authentik_config.authentik_stage_identification.default_authentication
}
