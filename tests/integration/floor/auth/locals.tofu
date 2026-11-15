# Local Values
# https://opentofu.org/docs/language/values/locals

# The verification identity needs the approver group floor-api enforces and the
# group the authentik application binds, which only authenticates the caller.

locals {
  # An address keeps the local accounts distinct from the other local identities.
  verify_email = "${var.username}@localhost"

  verify_group_ids = [authentik_group.floor_approvers.id, data.authentik_group.all.id]
  visitor_email    = "${var.visitor_username}@localhost"
}
