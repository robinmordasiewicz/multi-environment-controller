variable "environment" {
  type = list(object({
    name                 = string
    ARM_SUBSCRIPTION_ID  = string
    ENVIRONMENT_DEPLOYED = string
    AZURE_REGION         = string
    OWNER_EMAIL          = string
  }))
  default     = []
  description = "List of applications that will be used to create github branches and environments"
}

variable "ENVIRONMENT_AZURE_REGION" {
  type        = string
  description = "Azure region to use for storage account."
  sensitive   = true
}

variable "ENVIRONMENT_ARM_TENANT_ID" {
  type        = string
  sensitive   = true
  description = "Used for OIDC authentication"
}

variable "APPLICATION_REPOSITORY_NAME" {
  type        = string
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
}

variable "APPLICATION_ENVIRONMENT_OWNER_EMAIL" {
  type        = string
  description = "email address for the owner of resources used to tag azure resource groups"
}
