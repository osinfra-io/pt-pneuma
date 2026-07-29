# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # DNS subdomain per cluster, extracted from the gateway DNS zone name
  # (e.g. "pneuma.sb.osinfra.io" → "pneuma", "kryptos.sb.osinfra.io" → "kryptos").
  dns_subdomain = {
    for cluster_name in keys(local.gke_clusters) :
    cluster_name => try(split(".", local.dns_zone[cluster_name])[0], "")
  }

  # The single gateway DNS zone for each cluster's owning team (e.g. "pneuma.osinfra.io").
  # one() errors loudly if a team has >1 zone and returns null if empty; both cases
  # indicate the main workspace has not been applied for that team.
  dns_zone = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => one(keys(try(local.main.gateway_dns[cluster_config.team_key], {})))
  }

  # Failover region per cluster (the paired region for multi-region istio failover).
  failover_to_region = {
    for cluster_name in keys(local.gke_clusters) :
    cluster_name => local.regions[cluster_name] == "us-east1" ? "us-east4" : "us-east1"
  }

  # GKE clusters in this zone that have the Istio gateway enabled (platform team only).
  # Used for resources that are gateway-specific (e.g. Datadog AAP EnvoyFilter).
  gateway_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  # Auth policies generated from the Logos route_auth_policies contract. The gateway
  # cluster enforces every team's external route because all ingress enters through
  # the platform gateway data plane.
  gateway_auth_authorization_policies = merge(concat(
    [{}],
    [
      for cluster_name, policies in local.gateway_auth_policies : {
        for key, policy in policies :
        key => policy
      }
    ]
  )...)

  gateway_auth_callback_paths = [
    "/outpost.goauthentik.io",
    "/outpost.goauthentik.io/*",
  ]

  gateway_auth_default_exempt_paths = concat(
    local.gateway_auth_health_paths,
    local.gateway_auth_callback_paths,
  )

  gateway_auth_gateway_selector = {
    "gateway.networking.k8s.io/gateway-name" = "gateway"
  }

  gateway_auth_health_paths = [
    "/health",
    "/healthz",
    "/live",
    "/livez",
    "/ready",
    "/readyz",
  ]

  gateway_auth_authentik_jwks_uris = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => try(
      data.terraform_remote_state.authentik_config.outputs.jwks_uri,
      local.authentik_jwks_uri,
    )
  }

  gateway_auth_authentik_issuer_urls = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => try(
      data.terraform_remote_state.authentik_config.outputs.issuer_url,
      local.authentik_issuer_url,
    )
  }

  gateway_auth_policies = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => {
      for item in local.gateway_auth_route_policy_items :
      "${cluster_name}-${item.key}" => merge(item, {
        cluster_name                     = cluster_name
        custom_authorization_policy_name = "gateway-auth-${substr(sha1("${cluster_name}-${item.key}-custom"), 0, 8)}"
        deny_authorization_policy_name   = "gateway-auth-${substr(sha1("${cluster_name}-${item.key}-deny"), 0, 8)}"
        exempt_paths = distinct(concat(
          local.gateway_auth_default_exempt_paths,
          item.path == "/" ? [] : [
            for path in local.gateway_auth_default_exempt_paths :
            "${trimsuffix(item.path, "/")}${path}"
          ],
          item.public_paths,
        ))
        paths = item.path == "/" ? ["/*"] : [
          item.path,
          "${trimsuffix(item.path, "/")}/*",
        ]
      })
    }
  }

  gateway_auth_request_authentication_manifests = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => {
      apiVersion = "security.istio.io/v1"
      kind       = "RequestAuthentication"
      metadata = {
        name      = "gateway-authentik-jwt"
        namespace = "istio-ingress"
      }
      spec = {
        jwtRules = [
          {
            issuer  = local.gateway_auth_authentik_issuer_urls[cluster_name]
            jwksUri = local.gateway_auth_authentik_jwks_uris[cluster_name]
          }
        ]
        selector = {
          matchLabels = local.gateway_auth_gateway_selector
        }
      }
    }
  }

  gateway_auth_required_claim_authorization_policy_manifests = {
    for key, policy in local.gateway_auth_authorization_policies :
    key => {
      apiVersion = "security.istio.io/v1"
      kind       = "AuthorizationPolicy"
      metadata = {
        name      = policy.deny_authorization_policy_name
        namespace = "istio-ingress"
      }
      spec = {
        action = "DENY"
        rules = concat(
          policy.mode != "api-jwt" ? [] : [
            {
              from = [
                {
                  source = {
                    notRequestPrincipals = ["*"]
                  }
                }
              ]
              to = [
                {
                  operation = {
                    hosts    = [policy.host]
                    notPaths = policy.exempt_paths
                    paths    = policy.paths
                  }
                }
              ]
            }
          ],
          policy.mode != "api-jwt" || length(policy.audiences) == 0 ? [] : [
            {
              to = [
                {
                  operation = {
                    hosts    = [policy.host]
                    notPaths = policy.exempt_paths
                    paths    = policy.paths
                  }
                }
              ]
              when = [
                {
                  key       = "request.auth.audiences"
                  notValues = policy.audiences
                }
              ]
            }
          ],
          length(policy.required_groups) == 0 ? [] : [
            {
              to = [
                {
                  operation = {
                    hosts    = [policy.host]
                    notPaths = policy.exempt_paths
                    paths    = policy.paths
                  }
                }
              ]
              when = [
                {
                  key       = "request.auth.claims[groups]"
                  notValues = policy.required_groups
                }
              ]
            }
          ],
          length(policy.required_roles) == 0 ? [] : [
            {
              to = [
                {
                  operation = {
                    hosts    = [policy.host]
                    notPaths = policy.exempt_paths
                    paths    = policy.paths
                  }
                }
              ]
              when = [
                {
                  key       = "request.auth.claims[realm_access][roles]"
                  notValues = policy.required_roles
                }
              ]
            }
          ],
        )
        selector = {
          matchLabels = local.gateway_auth_gateway_selector
        }
      }
    }
  }

  gateway_auth_route_policy_items = flatten([
    for cluster_name, cluster_config in local.gke_clusters : flatten([
      for ns_name, ns in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {}) : [
        for route_name, policy in try(ns.route_auth_policies, {}) : [
          {
            audiences       = try(policy.audiences, [])
            host            = local.dns_zone[cluster_name]
            key             = "${cluster_config.team_key}-${ns_name}-${route_name}-${local.dns_subdomain[cluster_name]}-global"
            mode            = try(policy.mode, "browser")
            path            = ns.routes[route_name].path
            public_paths    = try(policy.public_paths, [])
            required_groups = try(policy.required_groups, [])
            required_roles  = try(policy.required_roles, [])
          },
          {
            audiences       = try(policy.audiences, [])
            host            = "${local.zone}.${local.dns_zone[cluster_name]}"
            key             = "${cluster_config.team_key}-${ns_name}-${route_name}-${local.dns_subdomain[cluster_name]}-zonal"
            mode            = try(policy.mode, "browser")
            path            = ns.routes[route_name].path
            public_paths    = try(policy.public_paths, [])
            required_groups = try(policy.required_groups, [])
            required_roles  = try(policy.required_roles, [])
          },
        ]
        if try(policy.mode, "browser") != "public"
      ]
    ])
  ])

  gateway_auth_custom_authorization_policy_manifests = {
    for key, policy in local.gateway_auth_authorization_policies :
    key => {
      apiVersion = "security.istio.io/v1"
      kind       = "AuthorizationPolicy"
      metadata = {
        name      = policy.custom_authorization_policy_name
        namespace = "istio-ingress"
      }
      spec = {
        action = "CUSTOM"
        provider = {
          name = local.authentik_extension_provider_name
        }
        rules = [
          {
            to = [
              {
                operation = {
                  hosts    = [policy.host]
                  notPaths = policy.exempt_paths
                  paths    = policy.paths
                }
              }
            ]
          }
        ]
        selector = {
          matchLabels = local.gateway_auth_gateway_selector
        }
      }
    }
    if policy.mode == "browser"
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Per-team global (apex) HTTPRoutes derived from each team's Logos-declared namespace routes. Keyed
  # by the team's cluster in this zone. Every route declared under a mesh-enabled namespace becomes an
  # apex HTTPRoute on the team's subdomain ("<subdomain>.osinfra.io"), co-located with its backend
  # Service in the team-prefixed namespace (e.g. "pt-kryptos-istio-test").
  global_routes = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => merge([
      for ns_name, ns in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {}) : {
        for route_name, route in try(ns.routes, {}) :
        "${route_name}-${local.dns_subdomain[cluster_name]}" => {
          backend_namespace = "${cluster_config.team_key}-${ns_name}"
          backend_port      = route.port
          backend_service   = route.service
          host              = local.dns_zone[cluster_name]
          path              = route.path
        }
      }
    ]...)
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  authentik_extension_provider_name = "authentik"

  authentik_dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  authentik_dns_zone_name = module.core_helpers.env == "prod" ? "${local.authentik_dns_subdomain}.osinfra.io" : "${local.authentik_dns_subdomain}.${module.core_helpers.env}.osinfra.io"

  authentik_hostname = "authentik.${local.authentik_dns_zone_name}"

  authentik_issuer_url = "https://${local.authentik_hostname}/application/o/gateway/"

  authentik_jwks_uri = "${local.authentik_issuer_url}jwks/"

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # HTTPRoutes for the gateway cluster, aggregated across every team present in this zone. Gateway
  # (pneuma) clusters receive HTTPRoutes for ALL teams — all external traffic enters through pneuma's
  # ingress gateway. Non-gateway clusters get nothing (they have no gateway data plane). Each team
  # contributes its global (apex) routes plus their zonal probe siblings; route keys embed the team
  # subdomain to avoid collisions across teams.
  routes = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config.team_key == module.core_helpers.team ? merge([
      for peer_name, peer_config in local.gke_clusters :
      merge(local.global_routes[peer_name], local.zonal_routes[peer_name])
    ]...) : {}
  }

  # Per-team zonal probe HTTPRoutes derived from each team's Logos-declared istio-test routes. Keyed
  # by the team's cluster in this zone. Only the istio-test namespace is scaffolded per zone (a
  # platform test convention); each apex route gets a zonal sibling targeting the per-zone Service
  # ("<service>-<zone>") under the zonal host ("<zone>.<subdomain>.osinfra.io").
  zonal_routes = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      for route_name, route in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces["istio-test"].routes, {}) :
      "${route_name}-${local.dns_subdomain[cluster_name]}-${local.zone}" => {
        backend_namespace = "${cluster_config.team_key}-istio-test"
        backend_port      = route.port
        backend_service   = "${route.service}-${local.zone}"
        host              = "${local.zone}.${local.dns_zone[cluster_name]}"
        path              = route.path
      }
    }
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-manifests-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
