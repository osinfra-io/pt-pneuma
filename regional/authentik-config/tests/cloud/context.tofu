module "core_helpers" {
  source = "./helpers"

  env = var.test_env
}

variable "test_env" {
  default     = "sb"
  description = "Mock environment for cloud root regressions"
  type        = string
}
