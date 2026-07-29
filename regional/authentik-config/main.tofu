# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=2f13e837e5ad7b90317ad319f59e67dd8da86ba7" # create-authentik-module (branch ref pending release)

  authentik_url = local.authentik_url
  external_host = local.external_host
  namespace     = local.namespace
  redirect_uris = local.redirect_uris
}
