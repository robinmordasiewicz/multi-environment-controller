variable "environments" {
  type = list(object({
    name                = string
    ARM_SUBSCRIPTION_ID = string
    AZURE_DEPLOYED      = string
    OWNER_EMAIL         = string
  }))
  default     = []
  sensitive   = true
  description = "List of applications that will be used to create github branches and environments"
}

variable "AZURE_REGION" {
  type        = string
  description = "Azure region to use for storage account."
  sensitive   = true
}

variable "ARM_TENANT_ID" {
  type        = string
  sensitive   = true
  description = "Used for OIDC authentication"
}

variable "REPOSITORY_TOKEN" {
  type        = string
  sensitive   = true
  description = "(Required) The github PAT for the repository."
}

variable "REPOSITORY_NAME" {
  type        = string
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
}

variable "OWNER_EMAIL" {
  type        = string
  description = "email address for the owner of resources used to tag azure resource groups"
}
