# pt-pneuma

Kubernetes/GKE infrastructure and cluster management layer.

## Architecture

**Main Deployment** (`main.tofu`):

- Creates Google Cloud projects per environment (sandbox, non-production, production) for Kubernetes workloads
- Integrates with Datadog for monitoring
- Consumes team and folder data from pt-logos via helpers module
- Uses GitHub Actions infrastructure (service accounts, workload identity, state storage) from pt-corpus

**Regional Deployment** (`regional/`):

- Creates GKE clusters in zones across multiple regions (us-east1-a/b/c, us-east4-a/b/c)
- Consumes project information from pt-pneuma main workspace via remote state
- Consumes networking (VPC, subnets) from pt-corpus projects
- Aggregates GKE cluster configurations from all teams via pt-logos

**Regional Subdirectories** (deployed after cluster creation):

- `cert-manager/` - Certificate management using cert-manager
- `datadog/` - Datadog operator for cluster monitoring and APM
- `istio/` - Service mesh with Istio for traffic management and observability
- `onboarding/` - Namespace and workload identity onboarding for applications
- `opa-gatekeeper/` - Policy enforcement using Open Policy Agent Gatekeeper

## Deployment Flow

1. **Main** → Creates Kubernetes project for environment (sandbox/non-production/production)
2. **Regional/Zonal** → Deploys GKE clusters in the project across multiple zones
3. **Regional Subdirectories** → Deploy cluster add-ons and configurations:
   - cert-manager → Certificate management
   - datadog → Monitoring and APM
   - istio → Service mesh
   - onboarding → Namespace and workload identity setup
   - opa-gatekeeper → Policy enforcement

## Separation of Concerns

- **pt-logos**: Foundational platform (teams, folders, identity groups, team configurations)
- **pt-corpus**: Networking infrastructure (VPC, subnets, DNS, NAT) in separate networking project
- **pt-pneuma**: Kubernetes infrastructure (projects) and GKE clusters (zonal deployments)
