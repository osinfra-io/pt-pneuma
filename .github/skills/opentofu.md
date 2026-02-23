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
- `helpers.tofu` - Helper module integration (when applicable)

### Alphabetical Ordering Rules

- **Variables, outputs, locals, tfvars**: Strict alphabetical order
- **Resources/data sources**: Alphabetically by resource type
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
  for_each = local.items
  name = each.key
  description = each.value.description
}
```

### Lifecycle Protection

- Always use `prevent_destroy = true` for critical infrastructure (KMS keys, state buckets, admin accounts)
- Use `ignore_changes` for externally managed fields

```hcl
lifecycle {
  ignore_changes = [attribute]
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

  resource_id = var.resource_id
  attribute = local.computed_value
}
```

## Module Integration

### Module References

- Pin versions using git refs: `source = "github.com/org/repo//path?ref=v1.2.3"`
- Document version in comment: `# v1.2.3`
- Access outputs: `module.<name>.<output>`
- Never hardcode values available from modules

### Module Pattern

```hcl
module "example" {
  source = "github.com/org/module-repo//path?ref=<version>"

  attribute_one = var.input_value
  attribute_two = local.computed_value
  list_attribute = var.list_input
}
```

Common outputs:

- `module.example.labels` - Standardized resource labels
- `module.example.environment` - Environment detection
- `module.example.naming` - Naming conventions
- `module.example.computed_values` - Derived configurations

## Data Transformations

### Flattening Nested Structures

```hcl
locals {
  flat_items = flatten([
    for parent_key, parent in var.nested_structure : [
      for child_key, child_value in parent.children : {
        key = "${parent_key}-${child_key}"
        parent_id = parent_key
        child_id = child_key
        attributes = child_value
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
  unique_items = distinct(flatten([
    for group in var.groups : group.items
  ]))

  non_overlapping = setsubtract(
    local.all_items,
    local.excluded_items
  )
}
```

## Environment Management

### Workspace Pattern

- Workspace naming: `{team}-{component}-{environment}`
- Examples: `pt-logos-main-production`, `regional-sandbox`
- Backend: Encrypted GCS buckets with KMS
- Environment detection: `module.helpers.env` (sb/np/prod)

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
