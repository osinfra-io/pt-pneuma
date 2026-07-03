# Moved Blocks
# https://opentofu.org/docs/language/moved

# The per-team for_each refactor re-keyed these modules from their original
# single-instance addresses to pt-pneuma-keyed addresses. The sandbox
# environment had a partial apply that left old unkeyed state addresses and
# existing GCP resources; removed + import reconcile state with GCP reality
# without destroying live resources.

removed {
  from = module.google_kubernetes_engine

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.kubernetes_cert_manager

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.kubernetes_istio

  lifecycle {
    destroy = false
  }
}

import {
  id = "projects/${local.team_project_ids["pt-pneuma"]}/global/addresses/istio-gateway-mci"
  to = module.kubernetes_istio["pt-pneuma"].google_compute_global_address.istio_gateway_mci
}

import {
  id = "projects/${local.team_project_ids["pt-pneuma"]}/global/securityPolicies/istio-gateway"
  to = module.kubernetes_istio["pt-pneuma"].google_compute_security_policy.istio_gateway
}

import {
  id = "projects/${local.team_project_ids["pt-pneuma"]}/global/sslPolicies/istio-gateway"
  to = module.kubernetes_istio["pt-pneuma"].google_compute_ssl_policy.istio_gateway
}
