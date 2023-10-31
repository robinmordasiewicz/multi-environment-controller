output "service_principal" {
  description = "Azure Service Principal"
  value       = module.azure_service_principal.service_principal
}
#output "azuread_application" {
#  description = "The full application object associated with the service principal."
#  value       = module.azure_service_principal.azuread_application.oidc
#}
