# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_http_port" {
  description = "HTTP port exposed by the Authentik server Service"
  type        = number
  default     = 80
}

variable "authentik_namespace" {
  description = "Namespace containing the Authentik server"
  type        = string
  default     = "authentik"
}

variable "authentik_service" {
  description = "Authentik server Service name"
  type        = string
  default     = "authentik-server"
}

variable "diagnostic_namespace" {
  description = "Namespace containing the diagnostic Service"
  type        = string
  default     = "istio-test"
}

variable "diagnostic_service" {
  description = "Diagnostic Service name"
  type        = string
  default     = "istio-test"
}

variable "diagnostic_service_port" {
  description = "Diagnostic Service HTTP port"
  type        = number
  default     = 8080
}

variable "gateway_name" {
  description = "AgentGateway Gateway name"
  type        = string
  default     = "agentgateway-proxy"
}

variable "hostname" {
  description = "Local hostname routed through the Istio ingress Gateway"
  type        = string
  default     = "agentgateway.localhost"
}

variable "istio_gateway_name" {
  description = "Istio ingress Gateway name"
  type        = string
  default     = "gateway"
}

variable "istio_gateway_namespace" {
  description = "Namespace containing the Istio ingress Gateway"
  type        = string
  default     = "istio-ingress"
}

variable "istio_ingress_principal" {
  description = "Istio principal allowed to reach the AgentGateway admin port"
  type        = string
  default     = "cluster.local/ns/istio-ingress/sa/gateway-istio"
}

variable "namespace" {
  description = "Namespace containing AgentGateway"
  type        = string
}
