data "github_repository" "repository" {
  for_each  = { for application in var.applications : application.repository_full_name => application }
  full_name = each.key
}

data "github_repository" "controller_repository" {
  full_name = var.controller_repository_full_name
}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  application_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}

data "azuread_client_config" "current" {}

resource "azuread_application" "azure_application" {
  for_each     = { for application in var.applications : application.repository_full_name => application }
  display_name = replace(data.github_repository.repository[each.key].full_name, "/", "-")
  owners       = [data.azuread_client_config.current.object_id]
  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Group.ReadWrite.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["User.Read.All"]
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "azure_service_principal" {
  for_each       = { for application in var.applications : application.repository_full_name => application }
  application_id = azuread_application.azure_application[each.key].application_id
  owners         = [data.azuread_client_config.current.object_id]
}

data "azurerm_subscription" "subscription" {
  for_each        = { for application in var.applications : application.repository_full_name => application }
  subscription_id = each.value.arm_subscription_id
}

resource "azurerm_role_assignment" "role_assignment" {
  for_each = { for application in var.applications : application.repository_full_name => application }
  #scope                = azurerm_resource_group.TFSTATE_RESOURCE_GROUP[each.key].id
  scope                = data.azurerm_subscription.subscription[each.key].id
  role_definition_name = "administrator_role"
  principal_id         = azuread_service_principal.azure_service_principal[each.key].object_id
}

resource "azuread_application_federated_identity_credential" "azure_federated_identity" {
  for_each              = { for application in var.applications : application.repository_full_name => application }
  application_object_id = azuread_application.azure_application[each.key].object_id
  display_name          = azuread_application.azure_application[each.key].display_name
  description           = "GitHub OIDC for ${data.github_repository.repository[each.key].full_name}."
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${data.github_repository.controller_repository.full_name}:environment:${github_repository_environment.repository_full_name[each.key].environment}"
}

resource "github_repository_environment" "repository_full_name" {
  for_each    = { for application in var.applications : application.repository_full_name => application }
  environment = base64encode(each.key)
  repository  = data.github_repository.controller_repository.name
  depends_on = [
    azurerm_role_assignment.role_assignment
  ]
}

resource "github_actions_environment_secret" "arm_client_id" {
  for_each        = { for application in var.applications : application.repository_full_name => application }
  secret_name     = "APPLICATION_ARM_CLIENT_ID"
  environment     = github_repository_environment.repository_full_name[each.key].environment
  plaintext_value = azuread_service_principal.azure_service_principal[each.key].application_id
  repository      = data.github_repository.controller_repository.name
}

resource "github_actions_environment_secret" "owner_email" {
  for_each        = { for application in var.applications : application.repository_full_name => application }
  secret_name     = "APPLICATION_OWNER_EMAIL"
  environment     = github_repository_environment.repository_full_name[each.key].environment
  plaintext_value = each.value.owner_email
  repository      = data.github_repository.controller_repository.name
}

resource "github_actions_environment_secret" "azure_region" {
  for_each        = { for application in var.applications : application.repository_full_name => application }
  secret_name     = "APPLICATION_AZURE_REGION"
  environment     = github_repository_environment.repository_full_name[each.key].environment
  plaintext_value = each.value.azure_region
  repository      = data.github_repository.controller_repository.name
}

resource "github_actions_environment_secret" "repository_full_name" {
  for_each        = { for application in var.applications : application.repository_full_name => application }
  secret_name     = "APPLICATION_REPOSITORY_FULL_NAME"
  environment     = github_repository_environment.repository_full_name[each.key].environment
  repository      = data.github_repository.controller_repository.name
  plaintext_value = each.value.repository_full_name
}

resource "github_actions_environment_secret" "repository_token" {
  for_each        = { for application in var.applications : application.repository_full_name => application }
  secret_name     = "APPLICATION_REPOSITORY_TOKEN"
  environment     = github_repository_environment.repository_full_name[each.key].environment
  repository      = data.github_repository.controller_repository.name
  plaintext_value = each.value.repository_token
}

resource "github_actions_environment_variable" "deployed" {
  for_each      = { for application in var.applications : application.repository_full_name => application }
  variable_name = "APPLICATION_DEPLOYED"
  environment   = github_repository_environment.repository_full_name[each.key].environment
  repository    = data.github_repository.controller_repository.name
  value         = each.value.deployed
}

resource "null_resource" "environments" {
  for_each = { for application in var.applications : application.repository_full_name => application }
  triggers = {
    arm_client_id        = github_actions_environment_secret.arm_client_id[each.key].plaintext_value
    owner_email          = github_actions_environment_secret.owner_email[each.key].plaintext_value
    azure_region         = github_actions_environment_secret.azure_region[each.key].plaintext_value
    repository_full_name = github_actions_environment_secret.repository_full_name[each.key].plaintext_value
    repository_token     = github_actions_environment_secret.repository_token[each.key].plaintext_value
    deployed             = github_actions_environment_variable.deployed[each.key].value
  }
  provisioner "local-exec" {
    command = "gh workflow run application.yml -F application=${github_repository_environment.repository_full_name[each.key].environment}"
  }
}
