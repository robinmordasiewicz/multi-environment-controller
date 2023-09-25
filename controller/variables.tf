variable "controllers" {
  type = list(object({
    CONTROLLER_REPOSITORY_FULL_NAME = string
    CONTROLLER_REPOSITORY_TOKEN     = string
    CONTROLLER_ARM_SUBSCRIPTION_ID  = string
    CONTROLLER_ARM_TENANT_ID        = string
    CONTROLLER_AZURE_REGION         = string
    CONTROLLER_OWNER_EMAIL          = string
    CONTROLLER_DEPLOYED             = string
    CONTROLLER_APPLICATIONS         = string
  }))
  default     = []
  description = "List of controllers that the registry will authorize"
}
