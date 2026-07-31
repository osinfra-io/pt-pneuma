# Import
# https://opentofu.org/docs/language/import

# The embedded outpost ships with Authentik, so we import it (rather than create it) to assign
# the gateway proxy provider. This makes each regional authentik-server serve forward-auth
# locally for Istio ext_authz without a managed outpost deployment.
import {
  id = data.authentik_outpost.embedded.id
  to = module.authentik_config.authentik_outpost.embedded
}
