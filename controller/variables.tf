variable "applications" {
  type = list(object({
    REPOSITORY_FULL_NAME = string
    REPOSITORY_TOKEN     = string
    ARM_SUBSCRIPTION_ID  = string
    ARM_TENANT_ID        = string
    AZURE_REGION         = string
    OWNER_EMAIL          = string
    DEPLOYED             = string
  }))
  default     = []
  description = "List of controllers that the registry will authorize"
}

variable "CONTROLLER_REPOSITORY_FULL_NAME" {
  description = "Controller Repository Full Name with org owner and repo <orgowner/repository>"
  type        = string
}
