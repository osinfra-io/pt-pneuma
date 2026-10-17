# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "hostname" {
  description = "Local hostname routed through the Istio ingress Gateway"
  type        = string
  default     = "openbao.localhost"
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

variable "namespace" {
  description = "Namespace containing OpenBao"
  type        = string
}

variable "service_name" {
  description = "OpenBao Service name"
  type        = string
  default     = "openbao"
}

variable "service_port" {
  description = "OpenBao Service port"
  type        = number
  default     = 8200
}
