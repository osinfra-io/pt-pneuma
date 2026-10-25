# OpenBao Team Policy Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Logos-declared OpenBao teams to be registered and reconciled without GKE/projects while keeping protected-apply policy writes narrowly authorized.

**Architecture:** Derive exact team ACL policy write paths from the OpenBao groups in `module.core_helpers.teams`; keep plan access read-only under valid team-key prefixes so removal plans can refresh deleted-team policies. Reuse the existing Nomos Helpers PR and make OpenBao consume the canonical shared helpers file, then document the onboarding and cleanup behavior.

**Tech Stack:** OpenTofu, OpenBao ACL policies, HCL tests, GitHub Copilot agent Markdown, promptfoo evaluations, Docusaurus Markdown.

**Spec:** `docs/superpowers/specs/2026-10-25-openbao-team-policy-onboarding-design.md`

## Global Constraints

- Preserve `<team-key>-openbao-secret-readers`, `...-writers`, and `...-admins`, along with existing KV v2 mount paths and policy contents.
- Plan access is read-only for ACL policy names beginning with `pt-`, `st-`, `ct-`, and `et-`; apply write access is limited to exact OpenBao policy names derived from Logos declarations.
- Do not introduce a new team-schema opt-in or MCP renderer behavior.
- Do not grant arbitrary ACL policy administration or change protected apply approvals.
- Use the existing MCP `open_team_helpers_pr` tool for helpers registration; do not hand-write team `.tfvars`.
- Keep bootstrap policy files and declarative authorization composition aligned; update the OpenBao operations/onboarding page.

## Review Focus

- **Read-only boundary:** plan can read team-prefixed policies but never create/update/delete them; pin the four prefixes and read-only capabilities in `github-actions_plan_reads_team_acl_policies_read_only`.
- **Write boundary:** apply can manage exact declared OpenBao policy names for two teams, not an unrelated ACL policy; pin in `github_actions_apply_manages_only_declared_team_acl_policies`.
- **Removal ordering:** removed groups/policies remain authorized through cleanup before apply access is narrowed; pin the generated apply policy plus resource dependency and verify the removal plan in `team_policy_removal_keeps_apply_authorization`.
- **OpenBao-only enrollment:** empty environment membership lists and no GKE/projects still invoke the Helpers PR; assert in the existing confirmed-onboarding promptfoo case.
- **Helpers drift:** OpenBao reads the same helpers content the MCP tool updates; verify the relative symlink resolves to `shared/helpers.tofu` and is not a duplicate file.

---

### Task 1: Bound OpenBao team-policy authorization

**Files:**
- Modify: `pneuma/pt-pneuma/regional/openbao-config/policies/github-actions-plan.hcl`
- Modify: `pneuma/pt-pneuma/regional/openbao-config/policies/github-actions-apply.hcl`
- Modify: `pneuma/pt-pneuma/regional/openbao-config/locals.tofu`
- Modify: `pneuma/pt-pneuma/regional/openbao-config/main.tofu`
- Test: `pneuma/pt-pneuma/regional/openbao-config/tests/oidc-and-team-policies.tftest.hcl`

**Interfaces:**
- Consumes: `local.openbao_groups`, keyed by `"${team_key}/${group_key}"`, and `local.github_actions_roles`, which load the canonical policy files.
- Produces: The plan ACL permits only `read` for `pt-*`, `st-*`, `ct-*`, and `et-*` policy paths. The declarative apply ACL composes the checked-in bootstrap policy with exact `sys/policies/acl/<team-key>-openbao-secret-<role>` paths for the currently declared groups.

- [ ] **Step 1: Add failing policy-boundary tests.** Add tests named `github_actions_plan_reads_team_acl_policies_read_only` and `github_actions_apply_manages_only_declared_team_acl_policies`. Assert plan has only `read` on each of the four team-type prefixes; apply policy contains exact ACL paths for two declared teams and all their declared roles; and an undeclared/unrelated ACL policy path is absent.
- [ ] **Step 2: Run the OpenBao configuration tests to confirm the new assertions fail.**

Run from `pneuma/pt-pneuma/regional/openbao-config`: `tofu test`

Expected: the new policy assertions fail against the current Pneuma-only ACL scope.

- [ ] **Step 3: Implement canonical and derived ACL policy composition.** Keep plan's four team-prefix ACL rules read-only. Narrow the checked-in apply baseline to the exact `pt-pneuma-openbao-plan` and `pt-pneuma-openbao-apply` ACL policies; then compose exact team ACL paths from `local.openbao_groups` into the declarative apply policy. Preserve the checked-in policy files as the bootstrap source.
- [ ] **Step 4: Add explicit ACL lifecycle ordering and team/group-change coverage.** Make `vault_policy.team` depend on both `vault_mount.team_kv2` and `vault_policy.github_actions`. Add `team_policy_removal_keeps_apply_authorization` to cover removal of aliases, groups, and policies while the apply policy still grants the deleting run access. Add a declared-group change case proving only the currently declared OpenBao policy names receive apply ACL paths.
- [ ] **Step 5: Run formatting and OpenBao tests.**

Run from `pneuma/pt-pneuma/regional/openbao-config`: `tofu fmt -check && tofu test`

Expected: formatting succeeds and all OpenBao configuration tests pass.

### Task 2: Register OpenBao-only teams through Nomos

**Files:**
- Modify: `techne/pt-techne-agents/.github/agents/nomos.agent.md`
- Modify: `techne/pt-techne-agents/evals/promptfooconfig-multiturn.yaml`

**Interfaces:**
- Consumes: Existing `authentik_groups` declarations and the current `pt-techne-mcp-server/open_team_helpers_pr` tool.
- Produces: Nomos opens the Helpers PR when OpenBao groups are declared, even if every membership list is empty and no GKE cluster or additional project is configured.

- [ ] **Step 1: Extend the confirmed-onboarding evaluation.** Assert the existing `st-nova` onboarding case calls `open_team_helpers_pr` with `team_key: st-nova`; this case has empty OpenBao memberships and no GKE/projects.
- [ ] **Step 2: Run the targeted multi-turn evaluation to confirm the new assertion fails.**

Run from `techne/pt-techne-agents`: `promptfoo eval -c evals/promptfooconfig-multiturn.yaml --no-cache`

Expected: the existing onboarding scenario fails its new Helpers PR assertion. This evaluation requires `ANTHROPIC_API_KEY`.

- [ ] **Step 3: Update the Nomos Helpers PR condition and merge guidance.** Open the existing Helpers PR when the team spec declares any `openbao-secret-*` groups, including groups with empty environment memberships. Preserve the existing GKE/project triggers, tool parameters, and Logos-before-Helpers merge ordering.
- [ ] **Step 4: Rerun the multi-turn evaluation.**

Run from `techne/pt-techne-agents`: `promptfoo eval -c evals/promptfooconfig-multiturn.yaml --no-cache`

Expected: the confirmed onboarding scenario calls `open_team_helpers_pr` for `st-nova` while retaining its empty membership lists.

### Task 3: Share helpers registration with OpenBao

**Files:**
- Replace: `pneuma/pt-pneuma/regional/openbao-config/helpers.tofu` with a symlink to `../../shared/helpers.tofu`

**Interfaces:**
- Consumes: The canonical `pneuma/pt-pneuma/shared/helpers.tofu`, updated by the existing MCP Helpers PR.
- Produces: OpenBao configuration discovers the same Logos workspaces as other Pneuma workspaces.

- [ ] **Step 1: Replace the duplicate file with the relative symlink.** Confirm both files currently have identical content before replacing the tracked OpenBao copy.
- [ ] **Step 2: Verify the link and contents.**

Run from `pneuma/pt-pneuma`: `test -L regional/openbao-config/helpers.tofu && test "$(readlink regional/openbao-config/helpers.tofu)" = "../../shared/helpers.tofu" && cmp shared/helpers.tofu regional/openbao-config/helpers.tofu`

Expected: all checks succeed.

### Task 4: Document OpenBao team onboarding and operations

**Files:**
- Modify: `ekklesia/pt-ekklesia-docs/docs/platform-grouping/pneuma/open-bao.md`

**Interfaces:**
- Consumes: The completed authorization lifecycle, Nomos Helpers PR behavior, and the existing Logos team/group declaration model.
- Produces: The operator page explains OpenBao-only onboarding, empty memberships, the authorization boundaries, and safe team-policy cleanup.

- [ ] **Step 1: Update the OpenBao team-access and operator-bootstrap sections.** Explain that Logos declarations are the team source of truth, the Nomos Helpers PR registers teams even without GKE/projects, empty membership lists are valid, plan reads are bounded/read-only, apply writes only exact declared team policy names, and policy authorization remains until removal cleanup completes.
- [ ] **Step 2: Review the rendered Markdown changes for consistency with the implementation.** Preserve existing endpoint, mount, policy-name, and protected-approval instructions.

### Task 5: Run repository validation

**Files:**
- Validate: `pneuma/pt-pneuma`, `techne/pt-techne-agents`, and `ekklesia/pt-ekklesia-docs`

- [ ] **Step 1: Run the Pneuma OpenBao formatting and test commands from Task 1.**
- [ ] **Step 2: Run the Nomos multi-turn evaluation from Task 2 when `ANTHROPIC_API_KEY` is available; otherwise record that it could not run.**
- [ ] **Step 3: Run the repository pre-commit checks in Pneuma and Ekklesia before committing, following the platform requirement to run `pre-commit autoupdate --freeze` once per repo per session before `pre-commit run -a`.** `pt-techne-agents` has no `.pre-commit-config.yaml`.
- [ ] **Step 4: Review each repository's final diff and confirm no unrelated files changed.**
