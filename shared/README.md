# Shared Configuration Files

This directory contains shared configuration files that are used across multiple directories in the repository via symbolic links.

## Backend Configuration

The `backend.tofu` file in this directory defines the OpenTofu backend configuration for state storage. It is symlinked from:

- Root directory: `backend.tofu -> shared/backend.tofu`
- Regional directory: `regional/backend.tofu -> ../shared/backend.tofu`
- Service-specific directories (2 levels deep): `regional/*/backend.tofu -> ../../shared/backend.tofu`
- Nested service directories (3 levels deep): `regional/*/*/backend.tofu -> ../../../shared/backend.tofu`

This approach ensures:

- Single source of truth for backend configuration
- Easier maintenance (update once, applies everywhere)
- Consistency across all workspaces
- Reduced duplication

## Adding New Directories

When creating new directories that require backend configuration, create a symbolic link to this file using the appropriate relative path:

```bash
# For directories at root level
ln -s shared/backend.tofu backend.tofu

# For directories in regional/
ln -s ../shared/backend.tofu regional/new-service/backend.tofu

# For nested directories in regional/service/
ln -s ../../shared/backend.tofu regional/service/new-feature/backend.tofu

# For deeply nested directories
ln -s ../../../shared/backend.tofu regional/service/feature/component/backend.tofu
```
