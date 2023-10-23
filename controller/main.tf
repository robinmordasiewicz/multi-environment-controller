data "github_repository" "REPOSITORY" {
  for_each  = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  full_name = each.key
}

data "github_repository" "CONTROLLER_REPOSITORY" {
  full_name = var.CONTROLLER_REPOSITORY_FULL_NAME
}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  application_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}

data "azuread_client_config" "current" {}

resource "azuread_application" "AZURE_APPLICATION" {
  for_each     = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  display_name = replace(data.github_repository.REPOSITORY[each.key].full_name, "/", "-")
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

resource "azuread_service_principal" "AZURE_SERVICE_PRINCIPAL" {
  for_each       = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  application_id = azuread_application.AZURE_APPLICATION[each.key].application_id
  owners         = [data.azuread_client_config.current.object_id]
}

data "azurerm_subscription" "subscription" {
  for_each        = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  subscription_id = each.value.ARM_SUBSCRIPTION_ID
}

resource "azurerm_role_assignment" "ROLE_ASSIGNMENT" {
  for_each = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  #scope                = azurerm_resource_group.TFSTATE_RESOURCE_GROUP[each.key].id
  scope                = data.azurerm_subscription.subscription[each.key].id
  role_definition_name = "ADMINISTRATOR_ROLE"
  principal_id         = azuread_service_principal.AZURE_SERVICE_PRINCIPAL[each.key].object_id
}

resource "azuread_application_federated_identity_credential" "AZURE_FEDERATED_IDENTITY" {
  for_each              = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  application_object_id = azuread_application.AZURE_APPLICATION[each.key].object_id
  display_name          = azuread_application.AZURE_APPLICATION[each.key].display_name
  description           = "GitHub OIDC for ${data.github_repository.REPOSITORY[each.key].full_name}."
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${data.github_repository.CONTROLLER_REPOSITORY.full_name}:environment:${github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment}"
}

resource "github_repository_environment" "REPOSITORY_FULL_NAME" {
  for_each    = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  environment = base64encode(each.key)
  repository  = data.github_repository.CONTROLLER_REPOSITORY.name
  depends_on = [
    azurerm_role_assignment.ROLE_ASSIGNMENT
  ]
}

resource "github_actions_environment_secret" "ARM_CLIENT_ID" {
  for_each        = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  secret_name     = "APPLICATION_ARM_CLIENT_ID"
  environment     = github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = azuread_service_principal.AZURE_SERVICE_PRINCIPAL[each.key].application_id
  repository      = data.github_repository.CONTROLLER_REPOSITORY.name
}

resource "github_actions_environment_secret" "OWNER_EMAIL" {
  for_each        = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  secret_name     = "APPLICATION_OWNER_EMAIL"
  environment     = github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = each.value.OWNER_EMAIL
  repository      = data.github_repository.CONTROLLER_REPOSITORY.name
}

resource "github_actions_environment_secret" "AZURE_REGION" {
  for_each        = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  secret_name     = "APPLICATION_AZURE_REGION"
  environment     = github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = each.value.AZURE_REGION
  repository      = data.github_repository.CONTROLLER_REPOSITORY.name
}

resource "github_actions_environment_secret" "REPOSITORY_FULL_NAME" {
  for_each        = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  secret_name     = "APPLICATION_REPOSITORY_FULL_NAME"
  environment     = github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment
  repository      = data.github_repository.CONTROLLER_REPOSITORY.name
  plaintext_value = each.value.REPOSITORY_FULL_NAME
}

resource "github_actions_environment_secret" "REPOSITORY_TOKEN" {
  for_each        = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  secret_name     = "APPLICATION_REPOSITORY_TOKEN"
  environment     = github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment
  repository      = data.github_repository.CONTROLLER_REPOSITORY.name
  plaintext_value = each.value.REPOSITORY_TOKEN
}

resource "github_actions_environment_variable" "DEPLOYED" {
  for_each      = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  variable_name = "APPLICATION_DEPLOYED"
  environment   = github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment
  repository    = data.github_repository.CONTROLLER_REPOSITORY.name
  value         = each.value.DEPLOYED
}

resource "null_resource" "environments" {
  for_each = { for application in var.applications : application.REPOSITORY_FULL_NAME => application }
  triggers = {
    ARM_CLIENT_ID        = github_actions_environment_secret.ARM_CLIENT_ID[each.key].plaintext_value
    OWNER_EMAIL          = github_actions_environment_secret.OWNER_EMAIL[each.key].plaintext_value
    AZURE_REGION         = github_actions_environment_secret.AZURE_REGION[each.key].plaintext_value
    REPOSITORY_FULL_NAME = github_actions_environment_secret.REPOSITORY_FULL_NAME[each.key].plaintext_value
    REPOSITORY_TOKEN     = github_actions_environment_secret.REPOSITORY_TOKEN[each.key].plaintext_value
    DEPLOYED             = github_actions_environment_variable.DEPLOYED[each.key].value
  }
  provisioner "local-exec" {
    command = "gh workflow run application.yml -F application=${github_repository_environment.REPOSITORY_FULL_NAME[each.key].environment}"
  }
}
