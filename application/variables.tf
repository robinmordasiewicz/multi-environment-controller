variable "environments" {
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
  default     = []
  description = "List of environments that will be created  that will be used to create github branches and environments"
}

variable "AZURE_REGION" {
  type        = string
  description = "Azure region to use for storage account."
  sensitive   = true
}

variable "ARM_SUBSCRIPTION_ID" {
  type        = string
  sensitive   = true
  description = "Used for OIDC authentication"
}

variable "ARM_TENANT_ID" {
  type        = string
  sensitive   = true
  description = "Used for OIDC authentication"
}

variable "REPOSITORY_FULL_NAME" {
  type        = string
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
}

variable "CONTROLLER_REPOSITORY_FULL_NAME" {
  type        = string
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
}

variable "OWNER_EMAIL" {
  type        = string
  description = "email address for the owner of resources used to tag azure resource groups"
}

variable "CONTROLLER_REPOSITORY_TOKEN" {
  type        = string
  description = "(Required) The actions token of the controller repository"
}

