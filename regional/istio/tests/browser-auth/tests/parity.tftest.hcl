# Test
# https://opentofu.org/docs/cli/commands/test

override_data {
  target = module.legacy_manifests.data.terraform_remote_state.main
  values = {
    outputs = {
      authentik_kubernetes_namespace = "authentik"
      gateway_dns = {
        pt-pneuma = {
          "pneuma.sb.osinfra.io" = {}
        }
      }
    }
  }
}

override_data {
  target = module.legacy_manifests.data.terraform_remote_state.authentik_config
  values = {
    outputs = {}
  }
}

override_data {
  target = module.legacy_mesh.data.terraform_remote_state.main
  values = {
    outputs = {
      authentik_kubernetes_namespace = "authentik"
      gateway_dns = {
        pt-pneuma = {
          "pneuma.sb.osinfra.io" = {}
        }
      }
      gke_clusters = {
        pt-pneuma-us-east1-b = {
          team_key = "pt-pneuma"
        }
      }
    }
  }
}

override_data {
  target = module.legacy_mesh.data.terraform_remote_state.authentik_config
  values = {
    outputs = {}
  }
}

run "production_parity" {
  command = plan

  assert {
    condition     = length(module.legacy_manifests.application_access_filters) == 0
    error_message = "Legacy browser routes must not acquire a managed-access guard or require new identity headers."
  }

  assert {
    condition     = length(module.legacy_manifests.custom_manifests) == 2 && jsonencode(module.shared.custom_authorization_policy_manifests) == jsonencode(module.legacy_manifests.custom_manifests)
    error_message = "Shared CUSTOM rendering must equal the real production global/zonal browser manifests."
  }

  assert {
    condition     = jsonencode(module.shared.extension_provider) == jsonencode(module.legacy_mesh.extension_providers["pt-pneuma-us-east1-b"][0])
    error_message = "Shared mesh extension provider must equal production's fail-closed configuration."
  }

  assert {
    condition     = jsonencode(module.shared.callback_routes) == jsonencode(module.legacy_manifests.callback_routes["pt-pneuma-us-east1-b"])
    error_message = "Shared callback route names and backends must equal production."
  }

  assert {
    condition = alltrue([
      for key, policy in module.legacy_manifests.gateway_auth_authorization_policies :
      jsonencode(policy.paths) == jsonencode(module.shared.resolved_policies[key].paths) &&
      jsonencode(policy.exempt_paths) == jsonencode(module.shared.resolved_policies[key].exempt_paths) &&
      policy.deny_authorization_policy_name == module.shared.resolved_policies[key].deny_authorization_policy_name &&
      jsonencode(policy.required_groups) == jsonencode(module.shared.resolved_policies[key].required_groups)
    ])
    error_message = "Resolved policy paths, exemptions, names and group intent must not change."
  }

  assert {
    condition = length(module.legacy_manifests.jwt_manifests) == 2 && alltrue([
      for manifest in values(module.legacy_manifests.jwt_manifests) :
      manifest.spec.action == "DENY" &&
      length(manifest.spec.rules) == 4 &&
      manifest.spec.rules[0].from[0].source.notRequestPrincipals[0] == "*" &&
      manifest.spec.rules[1].when[0].key == "request.auth.audiences" &&
      jsonencode(manifest.spec.rules[1].when[0]) == jsonencode({ key = "request.auth.audiences", notValues = ["test-api"] }) &&
      manifest.spec.rules[2].when[0].key == "request.auth.claims[groups]" &&
      jsonencode(manifest.spec.rules[2].when[0]) == jsonencode({ key = "request.auth.claims[groups]", notValues = ["api-users"] }) &&
      manifest.spec.rules[3].when[0].key == "request.auth.claims[roles]" &&
      jsonencode(manifest.spec.rules[3].when[0]) == jsonencode({ key = "request.auth.claims[roles]", notValues = ["reader"] })
    ])
    error_message = "Production API JWT resources must retain principal/audience/group/role enforcement."
  }
}

run "managed_cloud_adapter" {
  command = plan

  assert {
    condition     = module.legacy_manifests.admin_allow.spec.action == "ALLOW" && module.legacy_manifests.admin_allow.spec.rules[0].from[0].source.principals == ["cluster.local/ns/istio-ingress/sa/gateway-istio"] && module.legacy_manifests.admin_allow.spec.rules[0].to[0].operation.ports == ["15000"] && module.legacy_manifests.admin_allow.metadata.namespace == "pt-pneuma-agentgateway"
    error_message = "Only the authenticated ingress gateway may reach the admin port through mesh default-deny."
  }

  assert {
    condition     = module.legacy_manifests.admin_deny.spec.action == "DENY" && module.legacy_manifests.admin_deny.spec.rules[0].from[0].source.notPrincipals == ["cluster.local/ns/istio-ingress/sa/gateway-istio"] && module.legacy_manifests.admin_deny.spec.rules[0].to[0].operation.ports == ["15000"]
    error_message = "Other in-mesh workloads must not bypass browser authentication by reaching the admin port directly."
  }

  override_module {
    target = module.legacy_manifests.module.core_helpers
    outputs = {
      env         = "sb"
      environment = "sandbox"
      team        = "pt-pneuma"
      teams = {
        pt-pneuma = {
          dns_subdomain = "pneuma"
          authentik_groups = {
            agentgateway-admins = {
              description = "UI access"
              name        = "pt-pneuma: agentgateway Admins"
              members = {
                production = ["production@example.com"]
                sandbox    = ["sandbox@example.com"]
              }
            }
          }
          platform_managed_project = {
            kubernetes_engine_namespaces = {
              agentgateway = {
                routes = {
                  ui = {
                    path    = "/ui"
                    port    = 15000
                    service = "agentgateway-admin"
                  }
                }
                route_auth_policies = {
                  ui = {
                    mode            = "browser"
                    required_groups = ["pt-pneuma: agentgateway Admins"]
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = module.legacy_manifests.application_group_members["pt-pneuma: agentgateway Admins"] == tolist(["sandbox@example.com"])
    error_message = "The cloud gateway must consume the selected environment's core-helper memberships."
  }

  assert {
    condition     = length(module.legacy_manifests.application_access_filters) == 1 && module.legacy_manifests.application_access_filters["pt-pneuma-us-east1-b/application_access"].cluster_name == "pt-pneuma-us-east1-b"
    error_message = "Each gateway cluster must own its managed-access filter under a stable cluster key."
  }

  assert {
    condition     = module.legacy_manifests.application_access_filters["pt-pneuma-us-east1-b/application_access"].manifest.spec.configPatches[0].patch.operation == "INSERT_AFTER"
    error_message = "Cloud managed-access enforcement must run after successful forward-auth."
  }

  assert {
    condition     = module.legacy_manifests.platform_routes["pt-pneuma-us-east1-b"]["agentgateway-admin"].host == "agentgateway.sb.osinfra.io" && module.legacy_manifests.platform_routes["pt-pneuma-us-east1-b"]["agentgateway-admin"].path == "/" && module.legacy_manifests.platform_routes["pt-pneuma-us-east1-b"]["agentgateway-admin"].backend_port == 15000
    error_message = "The admin surface must use the dedicated platform host, not a stream-team hostname."
  }

  assert {
    condition     = alltrue([for routes in values(module.legacy_manifests.platform_routes) : alltrue([for name in keys(routes) : length(name) <= 253 && can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", name))])])
    error_message = "Route keys become Kubernetes metadata names and must be valid lowercase DNS names."
  }

  assert {
    condition     = module.legacy_manifests.callback_routes["pt-pneuma-us-east1-b"]["authentik-callback-${substr(sha1("agentgateway.sb.osinfra.io"), 0, 8)}"].host == "agentgateway.sb.osinfra.io"
    error_message = "The dedicated host must have its own outpost callback route."
  }

  assert {
    condition     = module.legacy_manifests.gateway_auth_authorization_policies["pt-pneuma-us-east1-b-agentgateway-admin"].cluster_name == "pt-pneuma-us-east1-b" && module.legacy_manifests.custom_manifests["pt-pneuma-us-east1-b-agentgateway-admin"].spec.rules[0].to[0].operation.hosts == ["agentgateway.sb.osinfra.io"]
    error_message = "Dedicated-host authorization resources must remain keyed to their own gateway cluster."
  }
}
