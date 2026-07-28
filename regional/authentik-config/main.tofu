# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=d033f0a0fa55b5a07266968b6ef654ea0a9f3037" # create-authentik-module (branch ref pending release)

  authentik_url = local.authentik_url
  external_host = local.external_host
  namespace     = local.namespace
  redirect_uris = local.redirect_uris
}
