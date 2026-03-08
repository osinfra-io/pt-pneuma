# OpenTofu

Specialized guidance for OpenTofu (Terraform) infrastructure-as-code workflows.

## File Structure & Organization

### Standard Files

- `main.tofu` - Resource and module declarations
- `data.tofu` - Data source definitions
- `locals.tofu` - Complex data transformations
- `variables.tofu` - Input variables with validation
- `outputs.tofu` - Output values
- `providers.tofu` - Provider configurations
- `backend.tofu` - State storage configuration
- `helpers.tofu` - Always present; invokes `pt-arche-core-helpers` which is the central source for environment detection, labels, team data, and project naming — check here before hardcoding any of those values

### Logic Belongs in Locals

All conditional logic, string transformations, and computed values **must live in `locals.tofu`**, not inline in resource or module arguments. Module and resource blocks should reference `local.*` values — never contain ternaries, `replace()`, `format()`, or other expressions directly.

```hcl
# ✅ Correct — logic in locals, module arguments are simple references
locals {
  dns_name = var.env == "prod" ? "example.com." : "${var.env}.example.com."
}

module "dns" {
  dns_name = local.dns_name
}

# ❌ Wrong — logic inline in module argument
module "dns" {
  dns_name = var.env == "prod" ? "example.com." : "${var.env}.example.com."
}
```

### Alphabetical Ordering Rules

- **Variables, outputs, locals, tfvars**: Strict alphabetical order
- **Modules**: Alphabetically by module name (the label after `module`)
- **Resources/data sources**: Alphabetically by resource name (the label after the resource type)
- **All arguments**: Alphabetically ordered at every nesting level
- **Meta-arguments first**: `count`, `depends_on`, `for_each`, `lifecycle`, `provider` (alphabetically among themselves)
- **Exception**: Logical grouping allowed only for team membership variables with comment annotation

### Formatting

- **Lists/Maps**: Empty newline before and after (unless first/last argument)
- **Functions**: Single-line for simple calls; multi-line for complex nested functions
- **Indentation**: 2 spaces (enforced by `tofu fmt`)

## Resource Patterns

### Meta-Arguments Priority

```hcl
resource "example" "this" {
  depends_on = [example.dependency]
  for_each   = local.items

  description = each.value.description
  name        = each.key
}
```

### Lifecycle Protection

- Always use `prevent_destroy = true` for critical infrastructure (KMS keys, state buckets, admin accounts)
- Use `ignore_changes` for externally managed fields

```hcl
lifecycle {
  ignore_changes  = [attribute]
  prevent_destroy = true
}
```

### Conditional Resource Creation

**OpenTofu v1.11+ introduced the `enabled` meta-argument for cleaner conditional resource creation.**

**Prefer `enabled` over `count` for conditional resources:**

```hcl
# Modern approach (OpenTofu v1.11+)
resource "example" "conditional" {
  lifecycle {
    enabled = local.should_create
  }

  # Access directly without [0] indexing
  name = "example"
}

# Legacy approach (avoid)
resource "example" "conditional" {
  count = local.should_create ? 1 : 0

  # Requires array indexing [0]
  name = "example"
}
```

**Benefits of `enabled`:**

- Direct resource access (no `[0]` indexing)
- Proper null state handling when disabled
- Cleaner syntax and intent
- Works with complex boolean conditions

**Common pattern for organization-level resources:**

```hcl
locals {
  is_primary_workspace = terraform.workspace == "primary-workspace-name"
}

resource "example" "this" {
  lifecycle {
    enabled = local.is_primary_workspace && var.resource_id != null
  }

  attribute   = local.computed_value
  resource_id = var.resource_id
}
```

## Module Integration

### Module References

- Always pin `source` to a commit SHA — never use a branch or semver tag
- The SHA must be followed by a version comment on the same line: `?ref=<sha>  # v1.2.3`
- Access outputs: `module.<name>.<output>`
- Never hardcode values available from modules

### Module Pattern

```hcl
module "example" {
  source = "github.com/org/module-repo//path?ref=<commit_sha>"  # v1.2.3

  attribute_one = var.input_value
  attribute_two = local.computed_value
  list_attribute = var.list_input
}
```

### `module.helpers` Key Outputs

`module.helpers` (from `pt-arche-core-helpers`) is available in every root module and provides:

- `module.helpers.env` - Short environment name: `sb`, `np`, `prod`
- `module.helpers.environment` - Full environment name: `sandbox`, `non-production`, `production`
- `module.helpers.environment_folder_id` - GCP folder ID for the current environment
- `module.helpers.labels` - Standard resource labels map for all GCP resources
- `module.helpers.region` - Current deployment region
- `module.helpers.team` - Current team identifier (e.g., `pt-pneuma`)
- `module.helpers.teams` - Map of all team data from pt-logos (folders, identity groups, GitHub repos, etc.)
- `module.helpers.zone` - Current deployment zone (regional subdirectory only)

## Remote State

- `terraform_remote_state` is **only used within the same repository** — a repo's regional or subdirectory code may read its own main or regional state, but never another repo's state directly
- Cross-repo state (e.g., pt-logos) is **never accessed via `terraform_remote_state`**; it is consumed exclusively through `module.helpers`

## Data Transformations

### Flattening Nested Structures

```hcl
locals {
  flat_items = flatten([
    for parent_key, parent in var.nested_structure : [
      for child_key, child_value in parent.children : {
        attributes = child_value
        child_id   = child_key
        key        = "${parent_key}-${child_key}"
        parent_id  = parent_key
      }
    ]
  ])
}
```

### String Transformation

```hcl
locals {
  normalized_values = {
    for value in local.input_values :
    value => replace(replace(value, "special_char", "replacement"), "pattern", "substitute")
  }
}
```

### Deduplication

```hcl
locals {
  non_overlapping = setsubtract(
    local.all_items,
    local.excluded_items
  )

  unique_items = distinct(flatten([
    for group in var.groups : group.items
  ]))
}
```

## Environment Management

### Workspace Pattern

- Main workspace: `main-{env}` (e.g., `main-production`, `main-sandbox`)
- Zonal workspace: `{zone}-{env}` (e.g., `us-east1-b-production`)
- Subdirectory workspace: `{zone}-{subdirectory}-{env}` (e.g., `us-east1-b-cert-manager-production`, `us-east1-b-opa-gatekeeper-sandbox`)
- Backend: Encrypted GCS buckets with KMS
- Environment detection: `module.helpers.env` returns short form (`sb`, `np`, `prod`); `module.helpers.environment` returns long form (`sandbox`, `non-production`, `production`)

### Environment Progression

1. **Sandbox** (`sb`) - Development and testing
2. **Non-Production** (`np`) - Staging/UAT
3. **Production** (`prod`) - Live environment

### Conditional Resources

**For map-based resources:**

```hcl
locals {
  should_create = terraform.workspace == "target-workspace"
}

resource "example" "conditional" {
  for_each = local.should_create ? local.resource_map : {}
  # ...
}
```

**For single resources (OpenTofu v1.11+):**

```hcl
resource "example" "conditional" {
  lifecycle {
    enabled = local.should_create
  }
  # ...
}
```

## Validation & Testing

### Pre-Commit Hooks

- `tofu fmt` - Auto-formats files
- `tofu validate` - Validates configuration syntax
- `check-yaml` - YAML syntax validation
- `trailing-whitespace` - Removes trailing whitespace
- `end-of-file-fixer` - Ensures files end with newline

### Plugin Cache (Performance)

```bash
mkdir -p $HOME/.opentofu.d/plugin-cache
export TF_PLUGIN_CACHE_DIR=$HOME/.opentofu.d/plugin-cache
```

## Repository-Specific Patterns

### pt-pneuma (Kubernetes/GKE Layer)

**Purpose:** Manages GKE clusters and Kubernetes workloads with nested deployment structure.

**Unique Characteristics:**

- **Multi-environment + multi-regional:** Manages clusters across multiple zones (us-east1-a/b/c, us-east4-a/b/c)
- **Four-level nested structure:** Root → `regional/` → Subdirectories (cert-manager, datadog, istio, onboarding, opa-gatekeeper)
- **Sequential deployment:** Main → Regional → Regional subdirectories (with dependencies)
- **Remote state consumption:** Uses remote state to consume upstream dependencies from pt-corpus projects
- **Cluster aggregation:** Pulls GKE cluster configurations from all teams via pt-logos helpers module
- **Shared resources:** `shared/` directory for cross-environment resources

**Workflow:** PR triggers sandbox → Merge triggers non-production → Success triggers production. Each level fans out to regional zones, then to nested subdirectories.

## References

- [OpenTofu Documentation](https://opentofu.org/docs/)
