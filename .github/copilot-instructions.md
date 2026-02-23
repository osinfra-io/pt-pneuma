# GitHub Copilot Repository Instructions

## Purpose
This file defines simple, persistent coding standards and repository practices for GitHub Copilot. These instructions are synchronized across all related OpenTofu root module repositories.

## Coding Standards
- Always run pre-commit validation after changing OpenTofu files: `pre-commit run -a`.
- Document complex logic with comments.

### Automated Pre-Commit Execution

**CRITICAL: Copilot must automatically run pre-commit hooks after making ANY changes to OpenTofu files** (`.tofu`, `.tfvars`, or any file in a OpenTofu directory).

This ensures:
- Hooks are updated to latest versions with pinned commit hashes
- Code is properly formatted
- Documentation is up-to-date
- Security checks pass
- All validations succeed

**Workflow:**
1. Make Terraform code changes
2. Run `pre-commit autoupdate --freeze` to update hooks and pin to commit hashes
3. Run `pre-commit run -a` to execute all hooks
4. Report any errors or fixes applied
5. Do not wait to be asked - this is automatic behavior

## Code Quality Principles

- **Keep it simple** - Favor straightforward solutions over clever ones. If there are multiple ways to solve a problem, choose the most obvious and maintainable approach.
- **Less is more** - Write only the code necessary to solve the problem at hand. Every line of code is a liability that must be maintained, tested, and understood.
- **Avoid over-engineering** - Don't add abstraction, flexibility, or complexity for hypothetical future needs. Solve today's problems today; refactor when actual requirements emerge.
- **Value clarity over brevity** - Longer, explicit code that's easy to understand is better than terse, "clever" code that saves a few lines but obscures intent.
- **Prefer explicit over implicit** - Make dependencies, transformations, and logic flows obvious. Magic behaviors and hidden assumptions create maintenance burden.
- **Write code for humans first** - Code is read far more often than it's written. Optimize for the next person who needs to understand and modify it.

## GitHub Actions

- All OpenTofu deployments are handled through GitHub Actions workflows using a reusable called workflow (osinfra-io/github-opentofu-gcp-called-workflows).
- There are two types of workflows:
  - Workflows that run directly on push to main (production only).
  - Workflows that run on PR creation and subsequent commits (sandbox environment), then automatically progress to non-production after merge to main, and finally production after non-production completes successfully.
- When modifying workflows, update the Mermaid diagram in the root README.md to reflect the changes.
- All GitHub Actions must use commit hashes instead of version tags for security and reproducibility.

### Commit Hash Guidelines

- **Use full 40-character SHA** - Never use short hashes; they can be ambiguous
- **Add version comment** - Include the tag/version as an inline comment for readability: `@<hash>  # v<version>`
- **Update deliberately** - When updating an action, update both the hash and the version comment
- **Verify hashes** - Ensure the commit hash matches the tagged version you intend to use

## Repository Practices
- Local development does not have access to OpenTofu state. Tests are run in GitHub Actions workflows.
- Use symlinks for shared configuration files to avoid duplication.

### VS Code Workspaces

Workspace configuration files (`*.code-workspace`) are stored locally outside the repository and managed by individual developers.

**Cross-repository bulk operations are common** - changes often need to be applied consistently across multiple platform repositories.

#### Workspace Workflow Patterns

- **Simultaneous multi-repo editing** - Apply standardization, updates, or patterns across all platform repos at once
- **Consistent changes** - Ensure configurations, workflows, or infrastructure patterns are aligned
- **Workspace-wide search and replace** - Use VS Code's multi-root capabilities to find and update patterns across repos
- **Parallel PR management** - Create and manage pull requests across multiple repositories for coordinated changes

**When performing bulk operations:**
- Verify changes apply correctly to each repository's unique structure

**IMPORTANT - Instruction File Synchronization:**

The `.github/copilot-instructions.md` file **MUST be identical across all kubexx platform repositories**. When making changes to this instructions file:
- Apply the same changes to **all platform repositories** in the current workspace
- Do not wait to be asked - automatically update all repos when modifying instructions
- Maintain consistency to ensure Copilot behavior is uniform across the platform

## References
- [Repository instructions documentation](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions)
