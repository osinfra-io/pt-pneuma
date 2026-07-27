# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  gateway_auth_guardrail_constraint_template_manifest = {
    apiVersion = "templates.gatekeeper.sh/v1"
    kind       = "ConstraintTemplate"

    metadata = {
      name = "k8sprotectgatewayauth"
    }

    spec = {
      crd = {
        spec = {
          names = {
            kind = "K8sProtectGatewayAuth"
          }

          validation = {
            openAPIV3Schema = {
              properties = {
                allowedGroups = {
                  items = {
                    type = "string"
                  }

                  type = "array"
                }

                allowedUsers = {
                  items = {
                    type = "string"
                  }

                  type = "array"
                }

                protectedKinds = {
                  items = {
                    properties = {
                      apiGroup = {
                        type = "string"
                      }

                      kind = {
                        type = "string"
                      }
                    }

                    type = "object"
                  }

                  type = "array"
                }

                protectedNamespaces = {
                  items = {
                    type = "string"
                  }

                  type = "array"
                }
              }

              type = "object"
            }
          }
        }
      }

      targets = [
        {
          code = [
            {
              engine = "Rego"

              source = {
                rego    = file("${path.module}/k8sprotectgatewayauth/k8sprotectgatewayauth.rego")
                version = "v1"
              }
            }
          ]

          target = "admission.k8s.gatekeeper.sh"
        }
      ]
    }
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name. Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
