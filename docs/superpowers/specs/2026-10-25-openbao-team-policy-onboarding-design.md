# OpenBao team policy onboarding design

## Intent

Allow every Logos team declaring OpenBao Authentik groups to have its existing
team-scoped policies managed by Pneuma, including teams without GKE clusters or
additional GCP projects. Keep CI authorization bounded so routine plans cannot
write policies and approved applies cannot administer unrelated OpenBao
policies.

## Goals

- Preserve `<team-key>-openbao-secret-readers`, `...-writers`, and
  `...-admins`, along with existing KV v2 mount paths and policy contents.
- Keep plan access read-only and derive protected-apply write access only from
  exact team policy names declared in Logos.
- Keep bootstrap's canonical baseline policy and declarative OpenTofu policy
  composition aligned.
- Register teams through Nomos Helpers PRs when OpenBao groups are declared,
  including empty environment membership lists and no GKE/projects.
- Make OpenBao configuration consume the canonical shared helpers file.
- Test multiple teams, onboarding, denial boundaries, and policy/group removal.
- Update OpenBao operations and onboarding documentation.

## Non-goals and anti-goals

- Do not rename team policies or change their secret paths, membership meaning,
  or capabilities.
- Do not grant arbitrary ACL policy administration or change protected apply
  approvals.
- Do not introduce a new team-schema opt-in or MCP renderer behavior.
- Do not alter unrelated services, workflows, or secret lifecycle.

## Constraints

- The change spans `pt-pneuma`, the Nomos prompt in `pt-techne-agents`, and the
  OpenBao operations page in `pt-ekklesia-docs`.
- `pt-techne-mcp-server/open_team_helpers_pr` already registers the team's
  production main workspace in both Corpus and Pneuma. The OpenBao workspace
  must consume that same canonical `logos_workspaces` list.
- Nomos already declares the three OpenBao groups and permits empty
  environment memberships; only the condition for opening the Helpers PR
  currently excludes OpenBao-only teams.
- The bootstrap script and OpenTofu configuration read the same checked-in
  GitHub Actions policy files.

## Approaches

1. **Derive authorization from Logos teams (selected).** Keep existing group
   and policy generation. OpenBao ACL path syntax cannot suffix-match policy
   names, so plan receives read-only access to team-prefixed ACL policy paths,
   while apply receives write access only to the exact OpenBao policy names
   derived from the declared team groups. Explicit Terraform dependencies keep
   that authorization in place until removed policies are cleaned up. This
   preserves names and data-driven onboarding without granting write access to
   unrelated team policies.
2. **Add explicit per-team OpenBao enrollment.** Add a new team-schema field
   and update the MCP renderer and Nomos flow, with separate registration
   behavior. This duplicates the existing group declarations and adds schema,
   renderer, and migration scope without improving the authorization boundary.

## Design

OpenBao permits `*` only as the final character of a policy path, so an ACL
cannot suffix-match the existing team policy names. Keep the canonical plan
policy read-only for names beginning with the four valid team-key type prefixes
(`pt-`, `st-`, `ct-`, and `et-`). This remains available to plan deletion after
a team's declaration has been removed, but can read other team-prefixed ACL
policies. In the declarative workspace, derive the exact policy names from
`module.core_helpers.teams` and the declared OpenBao group keys, and add those
exact names to the apply policy with `create`, `read`, `update`, and `delete`.
The canonical apply policy file continues to provide the bootstrap permission
to update its own policy; the declarative workspace composes that baseline with
only the current Logos-derived team policy names before managing team ACLs.
This lets the first authorized apply extend its own policy before it creates
team policies. Leave other authentication, mount, identity, and secret
capabilities unchanged.

Make generated team ACL policies depend on the canonical GitHub Actions policy
resources as well as the KV mount. On addition or policy changes, the apply
authorization is updated before team policies are managed. On removal,
dependent team ACL policies are destroyed before the apply authorization is
narrowed; existing identity alias and group references continue to order
alias, group, then policy cleanup.

Expand the OpenBao configuration tests to assert two teams retain their current
policy names and team-only paths; plan can only read ACL policies under the
`pt-`, `st-`, `ct-`, and `et-` team prefixes; apply can manage only exact
declared OpenBao policy names and cannot manage unrelated ACL policies; and
removing a team's declarations removes its alias, group, and policies while
retaining apply authorization through cleanup. Verify declarative apply policy
composition retains the canonical bootstrap baseline. Include group changes
and empty environment memberships in the onboarding coverage.

Replace `regional/openbao-config/helpers.tofu` with a relative symlink to
`../../shared/helpers.tofu`. Update the Nomos Helpers PR condition so it runs
when the team's spec declares OpenBao groups, even if all environment member
lists are empty and no GKE/project enhancement was requested. Preserve the
existing MCP tool as the only path for editing helpers files.

Update the OpenBao operations page to explain supported OpenBao-only team
onboarding, policy authorization boundaries and cleanup ordering, and how
membership changes flow from Logos through Nomos registration and Pneuma
reconciliation.

## Calls left to the builder

- Choose focused test cases and assertions using the existing test fixtures.
- Follow existing formatting and relative-symlink conventions.
- The plan read boundary is intentionally broader than the current Logos team
  set so it can refresh policies during team removal; it remains read-only and
  restricted to valid team-key type prefixes.
