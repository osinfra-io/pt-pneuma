# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "application_group_members" {
  default     = {}
  description = "Current environment's declared Google emails keyed by exact team-qualified group name. Managed browser requirements are checked per request after forward-auth, independently of cached group claims."
  type        = map(list(string))

  validation {
    condition = alltrue([
      for name, members in var.application_group_members :
      can(regex("^[a-z]+-[a-z0-9-]+: [A-Za-z][A-Za-z0-9]*( [A-Za-z0-9]+)*$", name)) &&
      length(members) == length(distinct(members)) && alltrue([
        for email in members : can(regex("^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(\\.[a-z0-9-]+)+$", email))
      ])
    ])
    error_message = "Application memberships require unique lowercase emails and exact team-qualified group names."
  }
}

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
    condition = alltrue(flatten([
      for policy in values(var.policies) : [
        for name in concat(policy.required_groups, policy.required_roles) :
        !strcontains(name, ": ") || contains(keys(var.application_group_members), name)
      ] if policy.mode == "browser"
    ]))
    error_message = "Every team-qualified browser requirement must resolve to a declared application membership list, including empty lists."
  }

  validation {
    condition = alltrue([
      for policy in values(var.policies) :
      can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", policy.host)) &&
      can(regex("^/[A-Za-z0-9_./-]*$", policy.path)) &&
      alltrue([for path in policy.public_paths : can(regex("^/[A-Za-z0-9_./-]*\\*?$", path))]) &&
      alltrue([
        for name in concat(policy.required_groups, policy.required_roles) :
        can(regex("^[!-~]+( [!-~]+)*$", name)) && !strcontains(name, "|") && !strcontains(name, ",")
      ])
      if policy.mode == "browser" && anytrue([
        for name in concat(policy.required_groups, policy.required_roles) :
        contains(keys(var.application_group_members), name)
      ])
    ])
    error_message = "Managed browser policies require lowercase literal hosts, unencoded paths, and unambiguous ASCII group names."
  }

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

  validation {
    condition = alltrue(flatten([
      for policy in values(var.policies) : [
        for path in policy.public_paths :
        path != trimsuffix(policy.path, "/") &&
        !(endswith(path, "*") && startswith(trimsuffix(policy.path, "/"), trimsuffix(path, "*")))
      ] if policy.mode == "browser"
    ]))
    error_message = "Browser public paths must not match the protected route root, including prefix wildcard matches."
  }
}
