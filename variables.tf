variable "environments" {
  type = list(object({
    name                = string
    ARM_SUBSCRIPTION_ID = string
    AZURE_DEPLOYED      = string
  }))
  default = []
}

variable "AZURE_REGION" {
  type        = string
  description = "(Optional) Azure region to use for storage account. Defaults to Canada Central."
  default     = "CanadaCentral"
}

variable "AZURE_USERNAME" {
  type = string
}

variable "ARM_TENANT_ID" {
  type = string
}

variable "REPOSITORY_TOKEN" {
  type      = string
  sensitive = true
}

# The GitHub repo where we'll be creating secrets and environments
variable "REPOSITORY_NAME" {
  type        = string
  description = "(Required) The name of the repository we're using in the form (org | user)/repo"
}

