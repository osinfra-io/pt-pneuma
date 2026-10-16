# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "secret_env" {
  description = "Locally generated bootstrap and database credentials, supplied through an ignored tfvars file"
  sensitive   = true
  type        = map(string)
}
