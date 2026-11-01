# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  agentgateway_gateway_dns = module.core_helpers.environment == "sandbox" ? {
    for host, record in local.authentik_gateway_dns :
    replace(host, "authentik.", "agentgateway.") => record
  } : {}

  # Single logical Authentik service (pt-pneuma#142): one shared Cloud SQL primary, one secret
  # key and one issuer are created here in main and consumed by every regional authentik workspace,
  # so all stateless regional server/worker instances form one identity provider (not per-zone IdPs).
  authentik_base_url = "https://${local.authentik_hostname}"

  # Authentik's token-authenticated management API receives generated JSON and uses PUT/DELETE,
  # which trigger false positives in Cloud Armor's protocol and method enforcement rules. There is
  # no scoped WAF exclusion for HTTP method/protocol enforcement, so this remains a full allow rule.
  authentik_cloud_armor_allow_rules = {
    authentik_api = {
      description = "Allow token-authenticated Authentik API requests"
      expression  = "has(request.headers['host']) && request.headers['host'] == '${local.authentik_hostname}' && request.path.startsWith('/api/v3/') && has(request.headers['authorization']) && request.headers['authorization'].startsWith('Bearer ')"
      priority    = 9000
    }
  }

  authentik_cloud_armor_method_enforcement_exceptions = [
    {
      hostname    = local.authentik_hostname
      methods     = ["DELETE", "PATCH", "PUT"]
      path_prefix = "/api/v3/"
    }
  ]

  # The Google OAuth flow's "scope" query parameter (e.g. "userinfo.profile") is false-positive
  # matched by the preconfigured LFI WAF rule (owasp-crs-v030301-id930120-lfi). Authentik re-wraps
  # the original query string (including "scope") inside its own "query" parameter at every step of
  # the flow (browser callback -> /if/flow/<slug>/ -> /api/v3/flows/executor/<slug>/), including
  # built-in system flows (e.g. default-source-authentication for returning users) whose slugs are
  # not defined by this repo. Excluding just the "scope" and "query" parameter values from the LFI
  # rule's inspection (rather than allowing the whole request past every preconfigured WAF rule)
  # fixes the false positive while still running SQLi/XSS/RCE/etc. checks on this traffic.
  #
  # Google also appends "prompt=none" to the callback, which the preconfigured RCE WAF rule
  # (owasp-crs-v030301-id932115-rce) reads as the Windows "prompt" command once it is wrapped in the
  # "query" parameter. The same exclusion is applied to that rule.
  authentik_cloud_armor_waf_exclusions = [
    {
      request_query_param_names = ["scope", "query"]
      target_rule_ids           = ["owasp-crs-v030301-id930120-lfi"]
      target_rule_set           = "lfi-v33-stable"
    },
    {
      request_query_param_names = ["query"]
      target_rule_ids           = ["owasp-crs-v030301-id932115-rce"]
      target_rule_set           = "rce-v33-stable"
    }
  ]

  # Connection name (project:region:instance) of the corpus-managed instance, used by the Cloud SQL
  # Auth Proxy sidecar in the Authentik pods to reach the private-IP, ENCRYPTED_ONLY database over
  # Workload Identity.
  authentik_cloud_sql_connection_name = one(local.authentik_cloud_sql_instances[*].connection_name)

  authentik_cloud_sql_instance_name = one(local.authentik_cloud_sql_instances[*].name)

  # The Cloud SQL instance is platform-managed by pt-corpus (see cloud_sql in the pt-pneuma Logos
  # tfvars, keyed "authentik"). Discover it in the pneuma project via the google_sql_database_instances
  # data source (cross-repo state access is not permitted) and read its generated name (which corpus
  # prefixes with the instance key) for the database/user. one() errors on more than one match; the
  # zero-match case is caught by the precondition on google_sql_database.authentik.
  authentik_cloud_sql_instances = [
    for instance in data.google_sql_database_instances.authentik.instances :
    instance
    if instance.region == local.authentik_primary_region && startswith(instance.name, "authentik-")
  ]

  authentik_cloud_sql_member = "serviceAccount:${google_service_account.authentik_cloud_sql.email}"

  # Private DNS FQDN of the corpus-managed Cloud SQL instance. Corpus creates the record
  # {instance}.{region}.{team} in the environment private zone (gcp.priv[.env].osinfra.io).
  authentik_database_host = "authentik.${local.authentik_primary_region}.sql.${module.core_helpers.team}.${local.authentik_private_dns_domain}"

  authentik_database_name = "authentik"

  authentik_database_user = "authentik"

  # Apex A record for the shared platform Authentik IdP, published in the environment-level
  # <env>.osinfra.io public zone (owned by pt-corpus in the shared VPC host project). It is merged
  # into the main gateway module's DNS input only — not the gateway_dns output that regional/istio
  # zonal-prefixes — so it resolves to the single MCI global address, not per-zone gateway LBs.
  authentik_gateway_dns = length(data.google_projects.shared_vpc_host.projects) > 0 ? {
    (local.authentik_hostname) = {
      managed_zone = local.authentik_public_dns_zone_name
      project      = data.google_project.shared_vpc_host.project_id
    }
  } : {}

  # Authentik is a single platform-wide IdP shared by every team, so it is published at the
  # environment-level public zone (authentik.<env>.osinfra.io) rather than under any one team's
  # subdomain. The <env>.osinfra.io zone is owned by pt-corpus in the shared VPC host project; prod
  # drops the env segment. The A record is created below via the main gateway module.
  authentik_hostname = "authentik.${local.authentik_public_dns_domain}"

  # Platform-installed (unprefixed) namespace created in regional/authentik and the chart-created
  # Kubernetes service account for Authentik. Both are needed here to bind Workload Identity for the
  # Cloud SQL Auth Proxy.
  authentik_kubernetes_namespace = "authentik"

  authentik_kubernetes_service_account = "authentik"

  # The primary region hosting the single shared Cloud SQL instance. Present in every environment's
  # active zones; regional clusters reach it privately over the shared VPC.
  authentik_primary_region = "us-east1"

  authentik_private_dns_domain = module.core_helpers.env == "prod" ? "gcp.priv.osinfra.io" : "gcp.priv.${module.core_helpers.env}.osinfra.io"

  authentik_public_dns_domain = module.core_helpers.env == "prod" ? "osinfra.io" : "${module.core_helpers.env}.osinfra.io"

  authentik_public_dns_zone_name = module.core_helpers.env == "prod" ? "osinfra-io" : "${module.core_helpers.env}-osinfra-io"

  # Keys in the Authentik environment Secret, generated once and shared by every regional workspace
  # via main's outputs (mounted into server and worker through the chart's global.envFrom).
  authentik_secret_env = {
    AUTHENTIK_BOOTSTRAP_PASSWORD   = random_password.authentik_admin.result
    AUTHENTIK_BOOTSTRAP_TOKEN      = random_password.authentik_bootstrap_token.result
    AUTHENTIK_POSTGRESQL__PASSWORD = random_password.authentik_database.result
    AUTHENTIK_SECRET_KEY           = random_password.authentik_secret_key.result
  }

  authentik_workload_identity_member = "serviceAccount:${local.team_project_ids[module.core_helpers.team]}.svc.id.goog[${local.authentik_kubernetes_namespace}/${local.authentik_kubernetes_service_account}]"

  cloud_armor_method_enforcement_exception_expression = join(" || ", [
    for scope in concat(local.authentik_cloud_armor_method_enforcement_exceptions, [
      {
        hostname    = local.openbao_hostname
        methods     = ["DELETE", "LIST", "PATCH", "PUT"]
        path_prefix = "/v1/"
      }
    ]) :
    "(has(request.headers['host']) && request.headers['host'] == ${jsonencode(scope.hostname)} && request.path.startsWith(${jsonencode(scope.path_prefix)}) && request.method.matches(${jsonencode(join("|", [for method in sort(tolist(scope.methods)) : "^${method}$"]))}))"
  ])

  cloud_armor_preconfigured_waf_rules = [
    {
      action      = "deny(403)"
      description = "OWASP: SQL injection"
      name        = "sqli-v33-stable"
      preview     = false
      priority    = 10000
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Cross-site scripting"
      name        = "xss-v33-stable"
      preview     = false
      priority    = 10010
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Local file inclusion"
      name        = "lfi-v33-stable"
      preview     = false
      priority    = 10020
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Remote file inclusion"
      name        = "rfi-v33-stable"
      preview     = false
      priority    = 10030
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Remote code execution"
      name        = "rce-v33-stable"
      preview     = false
      priority    = 10040
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Method enforcement"
      name        = "methodenforcement-v33-stable"
      preview     = false
      priority    = 10050
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Scanner detection"
      name        = "scannerdetection-v33-stable"
      preview     = false
      priority    = 10060
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Protocol attack"
      name        = "protocolattack-v33-stable"
      preview     = false
      priority    = 10070
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: PHP injection attack"
      name        = "php-v33-stable"
      preview     = false
      priority    = 10080
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Session fixation"
      name        = "sessionfixation-v33-stable"
      preview     = false
      priority    = 10090
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: Java attack"
      name        = "java-v33-stable"
      preview     = false
      priority    = 10100
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "OWASP: NodeJS attack"
      name        = "nodejs-v33-stable"
      preview     = false
      priority    = 10110
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "Log4j vulnerability"
      name        = "cve-canary"
      preview     = false
      priority    = 10120
      sensitivity = 1
    },
    {
      action      = "deny(403)"
      description = "JSON-based SQL injection bypass vulnerability"
      name        = "json-sqli-canary"
      preview     = false
      priority    = 10130
      sensitivity = 1
    },
  ]

  cloud_armor_waf_exclusions_by_rule_set = {
    for rule in local.cloud_armor_preconfigured_waf_rules : rule.name => [
      for exclusion in local.authentik_cloud_armor_waf_exclusions : exclusion
      if exclusion.target_rule_set == rule.name
    ]
  }

  cloud_armor_waf_rule_expressions = {
    for rule in local.cloud_armor_preconfigured_waf_rules : rule.name =>
    rule.name == "methodenforcement-v33-stable" && length(local.authentik_cloud_armor_method_enforcement_exceptions) > 0 ?
    "evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}}) && !(${local.cloud_armor_method_enforcement_exception_expression})" :
    rule.name == "rce-v33-stable" ?
    "(evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}}) && !(${local.openbao_kv_waf_exception_expression})) || evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}, 'opt_out_rule_ids': ['owasp-crs-v030301-id932100-rce']})" :
    "evaluatePreconfiguredWaf('${rule.name}', {'sensitivity': ${rule.sensitivity}})"
  }

  # Slim GKE cluster map passed to zone workspaces as TF_VAR_clusters.
  clusters_slim = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      project_id = cluster_config.project_id
      team_key   = cluster_config.team_key
    }
  }

  # DNS subdomain per team (e.g., "pneuma"), sourced from team config in pt-logos.
  # Falls back to the team key with its topology prefix stripped (e.g. "pt-pneuma" → "pneuma").
  dns_subdomains = {
    for team_key, team in local.teams_with_clusters :
    team_key => team.dns_subdomain != null ? team.dns_subdomain : replace(team_key, "/^[a-z]+-/", "")
  }

  # Team DNS zone config per team, following env-first naming convention
  # prod: pneuma.osinfra.io / pneuma-osinfra-io   sb: pneuma.sb.osinfra.io / pneuma-sb-osinfra-io
  dns_zones = {
    for team_key, subdomain in local.dns_subdomains :
    team_key => {
      dns_name = module.core_helpers.env == "prod" ? "${subdomain}.osinfra.io" : "${subdomain}.${module.core_helpers.env}.osinfra.io"
      name     = module.core_helpers.env == "prod" ? "${subdomain}-osinfra-io" : "${subdomain}-${module.core_helpers.env}-osinfra-io"
    }
  }

  # Environment key for logos lookup (title case with hyphens preserved)
  # Converts workspace environment (e.g., "non-production") to logos format (e.g., "Non-Production")
  environment_key = title(module.core_helpers.environment)

  # Gateway DNS configuration for Istio per team
  # Constructs DNS zone information for each team's public DNS zone created in pt-corpus
  gateway_dns_by_team = {
    for team_key in keys(local.teams_with_clusters) :
    team_key => length(data.google_projects.shared_vpc_host.projects) > 0 ? {
      (local.dns_zones[team_key].dns_name) = {
        managed_zone = local.dns_zones[team_key].name
        project      = data.google_project.shared_vpc_host.project_id
      }
    } : {}
  }

  # Merged gateway DNS for all teams — passed to pneuma's MCI module instance so the
  # single MCI global address creates DNS A records for every team that routes through
  # pneuma's gateway (e.g. pneuma.sb.osinfra.io and any member team subdomain), plus the
  # environment-level authentik.<env>.osinfra.io record for the shared IdP.
  gateway_dns_for_pneuma = length(data.google_projects.shared_vpc_host.projects) > 0 ? merge(
    merge(values(local.gateway_dns_by_team)...),
    local.authentik_gateway_dns,
    local.agentgateway_gateway_dns,
  ) : {}


  # GKE clusters aggregated from all teams, filtered by active zones for this environment
  # Derives cluster name as {team_key}-{location} from the flat locations map in pt-logos
  # Merges project_id for each team so regional workspaces can construct correct cluster resource IDs
  gke_clusters = merge([
    for team_key, team in local.teams_with_clusters : {
      for location, config in team.platform_managed_project.kubernetes_engine_locations :
      "${team_key}-${location}" => merge(config, {
        project_id = local.team_project_ids[team_key]
        team_key   = team_key
      })
      if contains(var.active_zones, location)
    }
  ]...)

  # GKE fleet host project per team; the host team itself has none.
  gke_fleet_host_project_id_by_team = {
    for team_key in keys(local.teams_with_clusters) :
    team_key => team_key == module.core_helpers.team ? "" : local.team_project_ids[module.core_helpers.team]
  }

  # GKE namespaces per team, derived from Logos team data.
  # Every namespace declared in Logos team data is prefixed with the team key (e.g. "istio-test" on
  # pt-pneuma becomes "pt-pneuma-istio-test") to ensure namespace uniqueness across all clusters and
  # to satisfy Istio namespace sameness: when a stub Service is created on the pneuma gateway cluster
  # under the same prefixed namespace name, Istio's multi-primary discovery merges the remote team's
  # pod endpoints into the stub automatically. Pneuma's platform workloads (authentik, openbao,
  # agentgateway) are installed by their own workspaces in unprefixed namespaces, like cert-manager.
  gke_namespaces_by_team = {
    for team_key, team in local.teams_with_clusters :
    team_key => {
      for ns_name, ns in try(team.platform_managed_project.kubernetes_engine_namespaces, {}) :
      "${team_key}-${ns_name}" => ns
    }
  }

  # Only the host team's Istio instance creates gateway DNS records.
  istio_gateway_dns_by_team = {
    for team_key in keys(local.teams_with_clusters) :
    team_key => team_key == module.core_helpers.team ? local.gateway_dns_for_pneuma : {}
  }

  kubernetes_engine_workload_identity_service_account_emails = {
    for team_key, google_kubernetes_engine in module.google_kubernetes_engine :
    team_key => google_kubernetes_engine.workload_identity_service_account_emails
  }

  kubernetes_istio_gateway_mci_global_addresses = {
    for team_key, istio in module.kubernetes_istio :
    team_key => istio.gateway_mci_global_address
  }

  openbao_kms_member = "serviceAccount:${google_service_account.openbao_kms.email}"

  # Seal settings consumed by the regional openbao workspaces to render the gcpckms seal stanza.
  openbao_kms_seal = {
    crypto_key = google_kms_crypto_key.openbao_unseal.name
    key_ring   = google_kms_key_ring.openbao_unseal.name
    project    = google_kms_key_ring.openbao_unseal.project
    region     = google_kms_key_ring.openbao_unseal.location
  }

  openbao_global_dns = length(data.google_projects.shared_vpc_host.projects) > 0 ? {
    (local.openbao_hostname) = {
      dns_name     = "${local.openbao_hostname}."
      managed_zone = local.authentik_public_dns_zone_name
      project      = data.google_project.shared_vpc_host.project_id
    }
  } : {}

  # OpenBao has a dedicated global GKE multi-cluster ingress, separate from the Istio mesh gateway.
  openbao_hostname = "openbao.${local.authentik_public_dns_domain}"

  # KV secret values can legitimately contain shell commands that trigger RCE signature 932100.
  # Exempt only that signature for KV writes; OpenBao still validates the token and enforces ACLs.
  openbao_kv_waf_exception_expression = "has(request.headers['host']) && request.headers['host'] == '${local.openbao_hostname}' && request.path.startsWith('/v1/kv2/data/') && request.method.matches('^POST$|^PUT$') && has(request.headers['x-vault-token']) && request.headers['x-vault-token'] != ''"

  openbao_workload_identity_member = "serviceAccount:${local.team_project_ids[module.core_helpers.team]}.svc.id.goog[openbao/openbao]"

  shared_ingress_policy_name = "shared-ingress"

  # Platform-managed project ID per team, discovered from pt-corpus labels.
  team_project_ids = {
    for team_key in keys(local.teams_with_clusters) :
    team_key => length(data.google_projects.team_platform_managed[team_key].projects) > 0 ? data.google_projects.team_platform_managed[team_key].projects[0].project_id : error("No platform-managed project found for team '${team_key}'; ensure pt-corpus has provisioned the platform-managed project with labels.repository=pt-corpus and labels.team=${team_key}")
  }

  # Teams with kubernetes clusters configured — used as the for_each key for team_platform_managed data source
  teams_with_clusters = {
    for team_key, team in module.core_helpers.teams :
    team_key => team
    if try(length(team.platform_managed_project.kubernetes_engine_locations), 0) > 0
  }
}
