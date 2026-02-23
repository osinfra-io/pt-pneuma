# pt-pneuma

[![Dependabot](https://img.shields.io/github/actions/workflow/status/osinfra-io/pt-pneuma/dependabot.yml?branch=main&style=for-the-badge&logo=github&label=Dependabot)](https://github.com/osinfra-io/pt-pneuma/actions/workflows/dependabot.yml)

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

## GitHub Actions Workflow

```mermaid
graph LR
    A[Trigger] --> B[Main]

    B --> C1[Regional:<br/>us-east1-b]
    B --> C2[Regional:<br/>us-east1-c]
    B --> C3[Regional:<br/>us-east1-d]

    C1 --> D1[Onboarding]
    C2 --> D2[Onboarding]
    C3 --> D3[Onboarding]

    D1 --> E1[cert-manager]
    D2 --> E2[cert-manager]
    D3 --> E3[cert-manager]

    E1 --> F1[cert-manager<br/>Istio CSR]
    E2 --> F2[cert-manager<br/>Istio CSR]
    E3 --> F3[cert-manager<br/>Istio CSR]

    F1 --> G1[Datadog]
    F2 --> G2[Datadog]
    F3 --> G3[Datadog]

    G1 --> H1[Datadog<br/>Manifests]
    G2 --> H2[Datadog<br/>Manifests]
    G3 --> H3[Datadog<br/>Manifests]

    H1 --> I1[Istio<br/>Manifests]
    H2 --> I2[Istio<br/>Manifests]
    H3 --> I3[Istio<br/>Manifests]

    I1 --> J1[Istio Test]
    I2 --> J2[Istio Test]
    I3 --> J3[Istio Test]

    J1 --> K1[Istio]
    J2 --> K2[Istio]
    J3 --> K3[Istio]

    K1 --> L1[Onboarding]
    K2 --> L2[Onboarding]
    K3 --> L3[Onboarding]

    L1 --> M1[OPA<br/>Gatekeeper]
    L2 --> M2[OPA<br/>Gatekeeper]
    L3 --> M3[OPA<br/>Gatekeeper]

    style A fill:#e1f5ff
    style B fill:#fff4e6
    style C1 fill:#d4edda
    style C2 fill:#d4edda
    style C3 fill:#d4edda
```

**Workflow Details:**

- **Three Workflows**: Sandbox, Non-Production, Production (identical job structure)
- **Total Jobs**: 73 (1 Main + 72 regional zone jobs across 6 zones)
- **Zones**: us-east1-b, us-east1-c, us-east1-d, us-east4-a, us-east4-b, us-east4-c (diagram shows 3 for clarity)
- **Job Chain per Zone** (12 jobs): Regional → Onboarding → cert-manager → cert-manager Istio CSR → Datadog → Datadog Manifests → Istio Manifests → Istio Test → Istio → Onboarding → OPA Gatekeeper
- **Triggers**:
  - Sandbox: Pull request (opened, synchronize), excluding .md files
  - Non-Production: Push to main, excluding .md files
  - Production: Triggered when Non-Production workflow completes successfully
- **Job Dependencies**: All 6 regional jobs run in parallel after main, then each zone follows the same sequential chain
- **Called Workflow**: [osinfra-io/github-opentofu-gcp-called-workflows](https://github.com/osinfra-io/github-opentofu-gcp-called-workflows) (v0.2.9)

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
