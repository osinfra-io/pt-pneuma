# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Single logical Authentik service (pt-pneuma#142): one shared Cloud SQL primary, one secret
  # key and one issuer are created here in main and consumed by every regional authentik workspace,
  # so all stateless regional server/worker instances form one identity provider (not per-zone IdPs).
  authentik_base_url = "https://${local.authentik_hostname}"

  # The Cloud SQL instance is platform-managed by pt-corpus (see cloud_sql in the pt-pneuma Logos
  # tfvars, keyed "authentik"). Discover it in the pneuma project via the google_sql_database_instances
  # data source (cross-repo state access is not permitted) and read its generated name (which corpus
  # prefixes with the instance key) for the database/user.
  # Connection name (project:region:instance) of the same corpus-managed instance, used by the
  # Cloud SQL Auth Proxy sidecar in the Authentik pods to reach the private-IP, ENCRYPTED_ONLY
  # database over Workload Identity.
  authentik_cloud_sql_connection_name = one([
    for instance in data.google_sql_database_instances.authentik.instances :
    instance.connection_name
    if instance.region == local.authentik_primary_region && startswith(instance.name, "authentik-")
  ])

  authentik_cloud_sql_instance_name = one([
    for instance in data.google_sql_database_instances.authentik.instances :
    instance.name
    if instance.region == local.authentik_primary_region && startswith(instance.name, "authentik-")
  ])

  # Private DNS FQDN of the corpus-managed Cloud SQL instance. Corpus creates the record
  # {instance}.{region}.{team} in the environment private zone (gcp.priv[.env].osinfra.io).
  authentik_database_host = "authentik.${local.authentik_primary_region}.sql.${module.core_helpers.team}.${local.authentik_private_dns_domain}"

  authentik_database_name = "authentik"

  authentik_database_user = "authentik"

  # Authentik is a single platform-wide IdP shared by every team, so it is published at the
  # environment-level public zone (authentik.<env>.osinfra.io) rather than under any one team's
  # subdomain. The <env>.osinfra.io zone is owned by pt-corpus in the shared VPC host project; prod
  # drops the env segment. The A record is created below via the main gateway module.
  authentik_hostname = "authentik.${local.authentik_public_dns_domain}"

  authentik_public_dns_domain = module.core_helpers.env == "prod" ? "osinfra.io" : "${module.core_helpers.env}.osinfra.io"

  authentik_public_dns_zone_name = module.core_helpers.env == "prod" ? "osinfra-io" : "${module.core_helpers.env}-osinfra-io"

  # Namespace and chart-created Kubernetes service account for Authentik. The regional authentik
  # workspace deploys into this namespace; the goauthentik chart names its ServiceAccount after the
  # release ("authentik"). Both are needed here to bind Workload Identity for the Cloud SQL Auth Proxy.
  authentik_kubernetes_namespace = "authentik"

  authentik_kubernetes_service_account = "authentik"

  # The primary region hosting the single shared Cloud SQL instance. Present in every environment's
  # active zones; regional clusters reach it privately over the shared VPC.
  authentik_primary_region = "us-east1"

  authentik_private_dns_domain = module.core_helpers.env == "prod" ? "gcp.priv.osinfra.io" : "gcp.priv.${module.core_helpers.env}.osinfra.io"

  # Keys in the Authentik environment Secret, generated once and shared by every regional workspace
  # via main's outputs (mounted into server and worker through the chart's global.envFrom).
  authentik_secret_env = {
    AUTHENTIK_BOOTSTRAP_PASSWORD   = random_password.authentik_admin.result
    AUTHENTIK_BOOTSTRAP_TOKEN      = random_password.authentik_bootstrap_token.result
    AUTHENTIK_POSTGRESQL__PASSWORD = random_password.authentik_database.result
    AUTHENTIK_SECRET_KEY           = random_password.authentik_secret_key.result
  }

  # Active zones per environment — controls which GKE clusters are included in outputs
  # Sandbox and non-production use 2 zones (1 per region) for multi-cluster testing
  # Production uses all 6 zones (3 per region) for full HA

  active_zones = {
    non-production = toset(["us-east1-b", "us-east4-a"])
    production     = toset(["us-east1-b", "us-east1-c", "us-east1-d", "us-east4-a", "us-east4-b", "us-east4-c"])
    sandbox        = toset(["us-east1-b", "us-east4-a"])
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
  # pneuma's gateway (e.g. both pneuma.sb.osinfra.io and kryptos.sb.osinfra.io), plus the
  # environment-level authentik.<env>.osinfra.io record for the shared IdP.
  gateway_dns_for_pneuma = length(data.google_projects.shared_vpc_host.projects) > 0 ? merge(
    merge(values(local.gateway_dns_by_team)...),
    local.authentik_gateway_dns,
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
      if contains(local.active_zones[module.core_helpers.environment], location)
    }
  ]...)

  # GKE namespaces per team, derived from Logos team data.
  # Every team's namespaces — including pneuma's own — are prefixed with the team key (e.g. "openbao"
  # on pt-kryptos becomes "pt-kryptos-openbao", "istio-test" on pt-pneuma becomes
  # "pt-pneuma-istio-test") to ensure namespace uniqueness across all clusters and to satisfy Istio
  # namespace sameness: when a stub Service is created on the pneuma gateway cluster under the same
  # prefixed namespace name, Istio's multi-primary discovery merges the remote team's pod endpoints
  # into the stub automatically. Prefixing uniformly (with no platform-team exception) lets pneuma
  # dogfood the model exactly like a member team.
  gke_namespaces_by_team = {
    for team_key, team in local.teams_with_clusters :
    team_key => {
      for ns_name, ns in try(team.platform_managed_project.kubernetes_engine_namespaces, {}) :
      "${team_key}-${ns_name}" => ns
    }
  }

  # Platform-managed project ID per team, discovered from pt-corpus labels.
  team_project_ids = {
    for team_key in keys(local.teams_with_clusters) :
    team_key => length(data.google_projects.team_platform_managed[team_key].projects) > 0 ? data.google_projects.team_platform_managed[team_key].projects[0].project_id : error("No platform-managed project found for team '${team_key}'; ensure pt-corpus has provisioned the platform-managed project with labels.repository=pt-corpus and labels.team=${team_key}")
  }

  # Teams with kubernetes clusters configured — used as the for_each key for team_platform_managed data source
  teams_with_clusters = {
    for team_key, team in module.core_helpers.teams :
    team_key => team
    if length(team.platform_managed_project.kubernetes_engine_locations) > 0
  }
}
