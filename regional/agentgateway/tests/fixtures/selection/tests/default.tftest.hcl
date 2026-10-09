override_module {
  target = module.core_helpers
  outputs = {
    labels = {
      env  = "sandbox"
      team = "pt-pneuma"
    }
    region = "us-east1"
    team   = "pt-pneuma"
    zone   = "b"
  }
}

variables {
  clusters = {
    pt-pneuma-us-east1-b = {
      project_id = "pneuma-test"
      team_key   = "pt-pneuma"
    }
    pt-pneuma-us-east4-a = {
      project_id = "pneuma-test"
      team_key   = "pt-pneuma"
    }
    st-ethos-us-east1-b = {
      project_id = "ethos-test"
      team_key   = "st-ethos"
    }
  }
  state_bucket             = "pneuma-test-state"
  state_kms_encryption_key = "projects/pneuma-test/locations/us/keyRings/test/cryptoKeys/state"
  state_prefix             = "pt-pneuma"
}

run "gateway_clusters_only_in_target_zone" {
  command = plan

  assert {
    condition     = keys(local.gateway_clusters) == ["pt-pneuma-us-east1-b"]
    error_message = "Only the Pneuma gateway cluster in this workspace's zone may receive agentgateway."
  }
}

run "unpublished_admin_denies_every_principal" {
  command = plan

  assert {
    condition = (
      local.admin_closed_manifest.spec.action == "DENY" &&
      local.admin_closed_manifest.spec.rules[0].to[0].operation.ports == ["15000"] &&
      !contains(keys(local.admin_closed_manifest.spec.rules[0]), "from")
    )
    error_message = "The unpublished administrator listener must deny every mesh principal."
  }
}
