# Kubernetes OAuth2 Proxy Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-oauth2-proxy

module "kubernetes_oauth2_proxy" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-oauth2-proxy//regional?ref=45731187f1f7c417720774f2da0954ee57fcd091" # create-oauth2-proxy-module (branch ref pending release)

  for_each = local.oauth2_proxy_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  client_id     = local.client_id
  client_secret = random_password.oauth2_proxy_client[each.key].result
  cookie_secret = random_bytes.oauth2_proxy_cookie[each.key].base64
  issuer_url    = local.keycloak_issuer_url
}

# Random Bytes Resource
# https://search.opentofu.org/provider/hashicorp/random/latest/docs/resources/bytes

resource "random_bytes" "oauth2_proxy_cookie" {
  for_each = local.oauth2_proxy_clusters

  length = 32
}

# Random Password Resource
# https://search.opentofu.org/provider/hashicorp/random/latest/docs/resources/password

resource "random_password" "oauth2_proxy_client" {
  for_each = local.oauth2_proxy_clusters

  length  = 32
  special = false
}
