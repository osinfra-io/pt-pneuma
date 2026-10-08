# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "extension_provider_name" {
  default     = "authentik"
  description = "Name shared by the mesh extension provider and browser CUSTOM policies."
  type        = string
}

variable "gateway_name" {
  default     = "gateway"
  description = "Gateway targeted by browser policies and selected by the inbound header filter."
  type        = string
}

variable "gateway_namespace" {
  default     = "istio-ingress"
  description = "Namespace containing the Gateway and rendered authorization resources."
  type        = string
}

variable "outpost_namespace" {
  default     = "authentik"
  description = "Namespace of the region-local Authentik outpost Service."
  type        = string
}

variable "outpost_path_prefix" {
  default     = "/outpost.goauthentik.io/auth/envoy"
  description = "Envoy forward-auth endpoint on the Authentik outpost."
  type        = string

  validation {
    condition     = startswith(var.outpost_path_prefix, "/")
    error_message = "The outpost path prefix must begin with /."
  }
}

variable "outpost_service_name" {
  default     = "authentik-server"
  description = "Region-local Service hosting the embedded Authentik outpost."
  type        = string
}

variable "outpost_service_port" {
  default     = 80
  description = "HTTP Service port hosting the embedded Authentik outpost."
  type        = number

  validation {
    condition     = var.outpost_service_port >= 1 && var.outpost_service_port <= 65535 && floor(var.outpost_service_port) == var.outpost_service_port
    error_message = "The outpost Service port must be an integer from 1 through 65535."
  }
}

variable "policies" {
  default     = {}
  description = "Resolved host/route intent keyed by stable policy identity (including the cluster prefix in Pneuma). Browser groups/roles are enforced by Authentik application bindings, not CUSTOM policy JWT claims."

  type = map(object({
    audiences       = optional(list(string), [])
    host            = string
    mode            = optional(string, "browser")
    path            = string
    public_paths    = optional(list(string), [])
    required_groups = optional(list(string), [])
    required_roles  = optional(list(string), [])
  }))

  validation {
    condition     = alltrue([for policy in values(var.policies) : contains(["api-jwt", "browser", "public"], policy.mode)])
    error_message = "Route auth policy mode must be api-jwt, browser, or public."
  }

  validation {
    condition = alltrue(flatten([
      for policy in values(var.policies) : [
        for path in policy.public_paths : startswith(path, "/") && !contains(["/", "/*", "*"], path)
      ]
    ]))
    error_message = "Public paths must start with / and must not exempt the entire route (/, /*, or *)."
  }

  validation {
    condition     = alltrue([for policy in values(var.policies) : length(policy.host) > 0 && startswith(policy.path, "/")])
    error_message = "Each route policy must have a nonempty host and a path beginning with /."
  }
}
