# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "approver_group" {
  description = "Authentik group whose members may approve plans through floor-api"
  type        = string
  default     = "pt-techne: floor Approvers"
}

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

variable "fixture_namespace" {
  description = "Namespace holding the floor fixture Terraform objects"
  type        = string
  default     = "pt-techne-floor-fixture"
}

variable "gateway_name" {
  description = "AgentGateway Gateway name"
  type        = string
  default     = "agentgateway-proxy"
}

variable "gateway_namespace" {
  description = "Namespace containing the AgentGateway Gateway"
  type        = string
  default     = "agentgateway"
}

variable "gateway_principal" {
  description = "Istio principal of the AgentGateway proxy, the only workload allowed to reach floor-api"
  type        = string
  default     = "cluster.local/ns/agentgateway/sa/agentgateway-proxy"
}

variable "git_repository" {
  description = "GitRepository the sandbox repoints at a pull request head"
  type        = string
  default     = "fixture"
}

variable "github_repository" {
  description = "Owner and repository of the floor fixture configuration"
  type        = string
  default     = "osinfra-io/pt-techne-floor-fixture"
}

variable "github_token_checksum" {
  description = "Checksum of the GitHub token secret, which rolls the pods when the token changes"
  type        = string
}

variable "github_token_secret" {
  description = "Secret holding the GitHub token floor-api reads pull requests and writes comments with"
  type        = string
  default     = "floor-github-token"
}

variable "hostname" {
  description = "Local hostname routed through the Istio ingress Gateway"
  type        = string
  default     = "floor.localhost"
}

variable "image" {
  description = "floor-api container image"
  type        = string
  default     = "pt-techne-floor-api:local"
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
  description = "Namespace containing floor-api"
  type        = string
  default     = "floor-system"
}

variable "request_timeout" {
  description = "HTTPRoute request timeout, above the floor-api revision timeout so an approve is not cut short while the planner re-plans"
  type        = string
  default     = "240s"
}

variable "service_port" {
  description = "Port floor-api listens on"
  type        = number
  default     = 8080
}

variable "version_label" {
  description = "Release of floor-api reported to Datadog"
  type        = string
  default     = "local"
}
