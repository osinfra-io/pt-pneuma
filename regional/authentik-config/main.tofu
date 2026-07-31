# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=88b4ba2fea6dc0623e984b8729857470f2bf8134" # v0.1.0

  authentik_url = local.authentik_url
  external_host = local.external_host
  namespace     = local.namespace
  redirect_uris = local.redirect_uris
}
