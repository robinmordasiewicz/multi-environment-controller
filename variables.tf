variable "environments" {
  type = list(object({
    APPLICATION_REPOSITORY_FULL_NAME = string
    ENVIRONMENT_BRANCH_NAME          = string
    ENVIRONMENT_ARM_SUBSCRIPTION_ID  = string
    ENVIRONMENT_ARM_TENANT_ID        = string
    ENVIRONMENT_AZURE_REGION         = string
    ENVIRONMENT_OWNER_EMAIL          = string
    ENVIRONMENT_DEPLOYED             = string
    CONTROLLER_REPOSITORY_FULL_NAME  = string
    CONTROLLER_REPOSITORY_TOKEN      = string
  }))
  default     = []
  description = "List of environments that will be created  that will be used to create github branches and environments"
}

#variable "ENVIRONMENT_AZURE_REGION" {
#  type        = string
#  description = "Azure region to use for storage account."
#  sensitive   = true
#}

#variable "ENVIRONMENT_ARM_TENANT_ID" {
#  type        = string
#  sensitive   = true
#  description = "Used for OIDC authentication"
#}

variable "APPLICATION_REPOSITORY_FULL_NAME" {
  type        = string
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
}
variable "CONTROLLER_REPOSITORY_FULL_NAME" {
  type        = string
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
}

#variable "ENVIRONMENT_OWNER_EMAIL" {
#  type        = string
#  description = "email address for the owner of resources used to tag azure resource groups"
#}

variable "CONTROLLER_REPOSITORY_TOKEN" {
  type        = string
  description = "(Required) The actions token of the controller repository"
}
