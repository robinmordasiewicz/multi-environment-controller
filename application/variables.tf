variable "environments" {
  description = "List of environments that will be created  that will be used to create github branches and environments"
  type = list(object({
    repository_full_name            = string
    REPOSITORY_BRANCH               = string
    arm_subscription_id             = string
    arm_tenant_id                   = string
    AZURE_REGION                    = string
    OWNER_EMAIL                     = string
    DEPLOYED                        = string
    controller_repository_full_name = string
    controller_repository_token     = string
  }))
  default = []
}

variable "arm_subscription_id" {
  description = "Used for OIDC authentication"
  type        = string
  sensitive   = true
}

variable "arm_tenant_id" {
  description = "Used for OIDC authentication"
  type        = string
  sensitive   = true
}

variable "repository_full_name" {
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
  type        = string
}

variable "controller_repository_full_name" {
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
  type        = string
}

variable "controller_repository_token" {
  description = "(Required) The actions token of the controller repository"
  type        = string
}

variable "deployment_provisioner_role_name" {
  description = "Azure Role Name for application provisioner"
  type        = string
}
