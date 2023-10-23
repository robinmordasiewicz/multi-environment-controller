variable "environments" {
  description = "List of environments that will be created  that will be used to create github branches and environments"
  type = list(object({
    REPOSITORY_FULL_NAME            = string
    REPOSITORY_BRANCH               = string
    ARM_SUBSCRIPTION_ID             = string
    ARM_TENANT_ID                   = string
    AZURE_REGION                    = string
    OWNER_EMAIL                     = string
    DEPLOYED                        = string
    CONTROLLER_REPOSITORY_FULL_NAME = string
    CONTROLLER_REPOSITORY_TOKEN     = string
  }))
  default = []
}

variable "ARM_SUBSCRIPTION_ID" {
  description = "Used for OIDC authentication"
  type        = string
  sensitive   = true
}

variable "ARM_TENANT_ID" {
  description = "Used for OIDC authentication"
  type        = string
  sensitive   = true
}

variable "REPOSITORY_FULL_NAME" {
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
  type        = string
}

variable "CONTROLLER_REPOSITORY_FULL_NAME" {
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
  type        = string
}

#variable "OWNER_EMAIL" {
#  type        = string
#  description = "email address for the owner of resources used to tag azure resource groups"
#}

variable "CONTROLLER_REPOSITORY_TOKEN" {
  description = "(Required) The actions token of the controller repository"
  type        = string
}

variable "DEPLOYMENT_PROVISIONER_ROLE_NAME" {
  description = "Azure Role Name for application provisioner"
  type        = string
}
