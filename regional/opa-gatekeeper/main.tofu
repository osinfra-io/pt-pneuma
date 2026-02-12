# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  source = "github.com/osinfra-io/opentofu-kubernetes-opa-gatekeeper//regional?ref=1d4bfa017feea182732487d42e05bd9b8c830a75" # v0.1.5
}
