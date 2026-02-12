# pt-pneuma Repository - Copilot Agent Onboarding Guide

## Repository Summary
**Type**: Infrastructure as Code (OpenTofu/Terraform)
**Purpose**: Kubernetes/GKE infrastructure and cluster management layer, creating Google Cloud projects and GKE clusters while consuming foundational platform data from pt-logos and networking from pt-corpus
**Language**: HCL (HashiCorp Configuration Language)
**Runtime**: OpenTofu v1.10.7+
**Providers**: Google Cloud, Datadog, Kubernetes, Helm

## Critical Build & Validation Commands

**ALWAYS run these commands in this exact order before committing:**

```bash
# 1. Install pre-commit hooks (first time only)
pre-commit install

# 2. Run all validation checks (REQUIRED before every commit)
cd /home/brett/repositories/osinfra-io/pt-pneuma
pre-commit run -a
```

**Expected output**: All hooks should pass with "Passed" status. The hooks run:
- `check-yaml` - Validates YAML syntax
- `end-of-file-fixer` - Ensures files end with newline
- `trailing-whitespace` - Removes trailing whitespace
- `check-symlinks` - Validates symbolic links
- `tofu-fmt` - Formats OpenTofu files (auto-fixes)
- `tofu-validate` - Validates OpenTofu configuration

**Common Issues**:
- If `tofu-validate` fails with "Error: No valid credential sources found", this is expected for local development without GCP credentials. The CI/CD pipeline has proper credentials.
- If `tofu-fmt` fails, it will auto-fix formatting. Run `pre-commit run -a` again to verify.

**Plugin Cache Optimization** (speeds up local validation):
```bash
mkdir -p $HOME/.opentofu.d/plugin-cache
export TF_PLUGIN_CACHE_DIR=$HOME/.opentofu.d/plugin-cache
```

## Repository Structure

**Core OpenTofu Files** (root directory):
- `main.tofu` - Google Cloud project creation and Datadog integration
- `helpers.tofu` - Core helpers module configuration (logos integration)
- `data.tofu` - Data source definitions
- `locals.tofu` - Data transformations and local value definitions
- `variables.tofu` - Input variables with defaults (alphabetically ordered)
- `outputs.tofu` - Output values (alphabetically ordered)
- `providers.tofu` - Provider configurations (Google, Datadog)
- `backend.tofu` - GCS backend with KMS encryption (symlink to shared/)

**Regional Directory** (regional/):
- `regional/main.tofu` - GKE cluster creation across multiple zones
- `regional/helpers.tofu` - Regional helpers module configuration
- `regional/data.tofu` - Remote state data sources
- `regional/locals.tofu` - Regional data transformations
- `regional/variables.tofu` - Regional input variables
- `regional/outputs.tofu` - Regional output values
- `regional/providers.tofu` - Regional provider configurations
- `regional/backend.tofu` - Backend configuration (symlink to ../shared/)

**Regional Subdirectories** (deployed after cluster creation):
- `regional/cert-manager/` - Certificate management using cert-manager
  - `regional/cert-manager/istio-csr/` - Istio CSR integration
- `regional/datadog/` - Datadog operator for cluster monitoring
  - `regional/datadog/manifests/` - Datadog manifest configurations
- `regional/istio/` - Service mesh with Istio
  - `regional/istio/manifests/` - Istio manifest configurations
  - `regional/istio/test/` - Istio testing configurations
- `regional/onboarding/` - Namespace and workload identity onboarding
- `regional/opa-gatekeeper/` - Policy enforcement using OPA Gatekeeper

**Configuration & Environments**:
- `environments/*.tfvars` - Per-environment configuration files
  - `sandbox.tfvars` - Sandbox environment
  - `non-production.tfvars` - Non-production environment
  - `production.tfvars` - Production environment
- `regional/environments/*.tfvars` - Regional per-environment configurations

**Shared Configuration**:
- `shared/backend.tofu` - Single source of truth (11 symlinks: `ln -s ../shared/backend.tofu regional/backend.tofu`)
- `shared/README.md` - Documentation for shared directory pattern

**CI/CD & Automation**:
- `.github/workflows/*.yml` - Environment-specific deployment workflows
- `.github/workflows/dependabot.yml` - Dependency updates
- `.pre-commit-config.yaml` - Pre-commit hook configuration

**Documentation**:
- `README.md` - Comprehensive project documentation
- `.github/copilot-instructions.md` - This file

## Architecture Overview

**Deployment Flow**:

1. **Main Workspace** (`main-{environment}`):
   - Creates Google Cloud Kubernetes project per environment
   - Integrates with Datadog for monitoring
   - Consumes team data from pt-logos via helpers module
   - Uses GitHub Actions infrastructure from pt-corpus

2. **Regional Workspace** (`regional-{environment}`):
   - Creates GKE clusters in zones across multiple regions
   - Consumes project information via remote state from main workspace
   - Consumes networking (VPC, subnets) from pt-corpus projects
   - Aggregates GKE cluster configurations from all teams

3. **Regional Subdirectories** (deployed after cluster creation):
   - cert-manager: Certificate management
   - datadog: Cluster monitoring and APM
   - istio: Service mesh for traffic management
   - onboarding: Namespace and workload identity setup
   - opa-gatekeeper: Policy enforcement

**Resources Created**:
- **Google Cloud Project**: Kubernetes workload project per environment
- **GKE Clusters**: Zonal clusters across multiple regions
- **Datadog Integration**: CSPM and cluster monitoring
- **Kubernetes Add-ons**: cert-manager, Istio, OPA Gatekeeper, Datadog operator
- **Access Controls**: Workload identity bindings, namespace configurations

**Critical Module Pattern**:
- `module.helpers` (opentofu-core-helpers): Fetches team data from pt-logos workspaces
  - Provides: labels, project naming, environment detection, team folder hierarchy, identity groups
  - Configuration: `logos_workspaces = ["pt-pneuma-main-production", "pt-logos-main-production"]`

## Code Standards (CRITICAL)

### File Structure
- **All configuration files**: Variables, outputs, locals, and tfvars MUST be in strict alphabetical order
- **main.tofu structure**: Modules first, then resources alphabetically by resource type
- **Universal alphabetical ordering**: ALL arguments, keys, and properties at EVERY level of configuration must be alphabetically ordered (applies to variables, outputs, locals, resources, data sources, and nested blocks)

### Meta-Arguments Priority
Meta-arguments (`for_each`, `count`, `depends_on`, `lifecycle`, `provider`) MUST be the first arguments in resources/data sources when required:

- **Position**: Always first, before all regular resource configuration arguments
- **Multiple meta-arguments**: Ordered alphabetically among themselves
- **lifecycle blocks**: Are meta-arguments and must be positioned before all regular resource configuration arguments
- **Nested block ordering**: Within nested blocks (lifecycle, provisioner, etc.), use normal alphabetical ordering

**Example**:
```hcl
resource "google_service_account" "github_actions" {
  for_each = local.service_accounts

  depends_on = [google_project_service.this]

  lifecycle {
    prevent_destroy = true
  }

  # Regular arguments in strict alphabetical order
  account_id   = "${each.key}-github"
  display_name = "Service account for GitHub Actions"
  project      = module.project.id
}
```

### Resource Arguments
- **All remaining arguments**: Must be in strict alphabetical order after meta-arguments, regardless of whether they're required or optional
- **No exceptions**: Alphabetical ordering applies to all standard resource arguments

### Formatting Rules
- **List/Map formatting**: Always have an empty newline before any list, map, or logic block unless it's the first argument. Always have an empty newline after any list, map, or logic block unless it's the last argument.
- **Function formatting**: Use single-line formatting for simple function calls. For complex functions with long lines or multiple arguments, break into multiple lines for readability.

**Function formatting examples**:
```hcl
# Simple function - single line
name = upper(var.environment)

# Complex function - multiple lines for readability
attribute_condition = module.helpers.env == "sb" ?
  "assertion.repository_owner_id==\"104685378\"" :
  "assertion.repository_owner_id==\"104685378\" && assertion.ref==\"refs/heads/main\""
```

## Separation of Concerns

**pt-logos** (foundational platform):
- Organizational hierarchy (folders, teams)
- Identity groups and access controls
- Team configurations and metadata
- GitHub team structures

**pt-corpus** (networking layer):
- VPC and subnet creation
- Cloud NAT and Cloud Router
- DNS configurations
- Network peering
- Separate networking project per environment

**pt-pneuma** (Kubernetes layer):
- Kubernetes project creation
- GKE cluster deployment (zonal, across regions)
- Kubernetes add-ons (cert-manager, Istio, Datadog, OPA)
- Namespace and workload identity onboarding
- Consumes VPC from pt-corpus, team data from pt-logos

## Helpers Module Pattern (CRITICAL)

The `helpers.tofu` file configures the opentofu-core-helpers module which provides foundational platform integration:

```hcl
module "helpers" {
  source = "github.com/osinfra-io/opentofu-core-helpers//root?ref=<version>"

  cost_center         = "x001"
  data_classification = "public"
  logos_workspaces    = ["pt-pneuma-main-production", "pt-logos-main-production"]
  repository          = "pt-pneuma"
  team                = "pt-pneuma"
}
```

**Provides**:
- `module.helpers.labels` - Consistent labels for all resources
- `module.helpers.env` - Environment detection (sb/np/prod)
- `module.helpers.project_naming` - Standardized project names and descriptions
- `module.helpers.environment_folder_id` - Folder ID from pt-logos hierarchy
- `module.helpers.teams` - All team data (folders, identity groups, GKE configurations)

**NEVER modify** the helpers module configuration without understanding the pt-logos foundational platform.

## Multi-Environment Workflow

**Environment Progression**:
1. Sandbox → 2. Non-Production → 3. Production

**Workspace Pattern**:
- Main: `main-{environment}` (e.g., `main-sandbox`, `main-production`)
- Regional: `regional-{environment}` (e.g., `regional-sandbox`, `regional-production`)
- Backend: GCS bucket per environment with KMS encryption

## Key Guidelines

✅ **Do**:
- Follow alphabetical ordering rigorously
- Use `pre-commit run -a` before every commit
- Preserve helpers module integration pattern
- Use shared/ directory for backend configuration
- Verify all symlinks work correctly
- Test changes in sandbox first
- Document module versions with comments

❌ **Don't**:
- Modify helpers module configuration without understanding pt-logos
- Create duplicate backend.tofu files (use symlinks)
- Skip environment progression (sandbox → non-prod → prod)
- Remove symlinks or replace with duplicate files
- Hardcode values that come from modules

## Trust These Instructions

These instructions have been validated against the current codebase. Only perform additional searches if information is incomplete or found to be in error. The pre-commit hooks will catch most errors automatically.
