output "env" {
  description = "Fixture environment."
  value       = "sb"
}

output "environment" {
  description = "Fixture long environment name."
  value       = "sandbox"
}

output "team" {
  description = "Fixture gateway team."
  value       = "pt-pneuma"
}

output "teams" {
  description = "Resolved route intent without Logos state."
  value = {
    pt-pneuma = {
      dns_subdomain = "pneuma"
      platform_managed_project = {
        kubernetes_engine_namespaces = {
          istio-test = {
            route_auth_policies = {
              browser = {
                mode            = "browser"
                public_paths    = ["/istio-test/metadata"]
                required_groups = ["test-users"]
              }
              api = {
                audiences       = ["test-api"]
                mode            = "api-jwt"
                required_groups = ["api-users"]
                required_roles  = ["reader"]
              }
              public = {
                mode = "public"
              }
            }
            routes = {
              browser = {
                path    = "/istio-test"
                port    = 8080
                service = "istio-test"
              }
              api = {
                path    = "/api"
                port    = 8080
                service = "api"
              }
              public = {
                path    = "/public"
                port    = 8080
                service = "public"
              }
            }
          }
        }
      }
    }
  }
}
