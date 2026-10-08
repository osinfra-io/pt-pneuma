# Gateway Auth Rendering Module (osinfra.io)
# https://github.com/osinfra-io/pt-pneuma

module "shared" {
  source = "../../gateway-auth"

  outpost_namespace = "authentik"
  policies          = module.legacy_manifests.gateway_auth_authorization_policies
}

module "legacy_manifests" {
  source = "./legacy-manifests"
}

module "legacy_mesh" {
  source = "./legacy-mesh"
}
