# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  dns_zone = one(keys(data.terraform_remote_state.main.outputs.gateway_dns))

  common_istio_test_virtual_services = {
    "istio-test" = {
      destination_host = "istio-test.istio-test.svc.cluster.local"
      host             = local.dns_zone
    }
  }

  failover_from_region = module.helpers.region
  failover_to_region   = module.helpers.region == "us-east1" ? "us-east4" : "us-east1"

  istio_test_virtual_services = {
    "istio-test-${module.helpers.region}-${module.helpers.zone}" = {
      destination_host = "istio-test-${module.helpers.region}-${module.helpers.zone}.istio-test.svc.cluster.local"
      host             = "${module.helpers.region}-${module.helpers.zone}.${local.dns_zone}"
    }
  }
}
