data "github_repository" "REPOSITORY" {
  for_each  = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  full_name = each.key
}

data "azurerm_subscription" "current" {
}

resource "azurerm_resource_group" "AZURE_RESOURCE_GROUP" {
  for_each = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  name     = replace(data.github_repository.REPOSITORY[each.key].full_name, "/", "-")
  location = each.value.CONTROLLER_AZURE_REGION
  tags = {
    Username = each.value.CONTROLLER_OWNER_EMAIL
  }
}

resource "random_integer" "random_number" {
  for_each = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  min      = 10000
  max      = 99999
}

resource "azurerm_storage_account" "AZURE_TFSTATE_STORAGE_ACCOUNT" {
  for_each                 = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  resource_group_name      = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].name
  location                 = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].location
  name                     = "${random_integer.random_number[each.key].result}${substr(lower(replace(each.key, "/\\W|_|\\s/", "")), 0, 19)}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "AZURE_TFSTATE_CONTAINER" {
  for_each             = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  name                 = lower(replace(each.key, "/\\W|_|\\s/", ""))
  storage_account_name = azurerm_storage_account.AZURE_TFSTATE_STORAGE_ACCOUNT[each.key].name
}

module "AZURE_SERVICE_PRINCIPAL" {
  for_each         = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  environment_name = base64encode(each.value.CONTROLLER_REPOSITORY_FULL_NAME)
  #identity_name    = replace(data.github_repository.REPOSITORY[each.value].full_name, '/', '-')
  identity_name   = data.github_repository.REPOSITORY[each.key].name
  source          = "ned1313/github_oidc/azuread"
  version         = ">=1.2.0"
  entity_type     = "environment"
  repository_name = data.github_repository.REPOSITORY[each.key].full_name
}

resource "azurerm_role_assignment" "CONTROLLER_ROLE_ASSIGNMENT" {
  for_each             = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  scope                = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].id
  role_definition_name = "CONTROLLER_ADMINISTRATOR_ROLE"
  principal_id         = module.AZURE_SERVICE_PRINCIPAL[each.key].service_principal.object_id
}
resource "github_repository_environment" "CONTROLLER_REPOSITORY_FULL_NAME" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  environment = base64encode(each.key)
  repository  = data.github_repository.REPOSITORY[each.key].name
  depends_on = [
    azurerm_role_assignment.CONTROLLER_ROLE_ASSIGNMENT
  ]
}
resource "github_actions_secret" "CONTROLLER_ARM_SUBSCRIPTION_ID" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_ARM_SUBSCRIPTION_ID"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = each.value.CONTROLLER_ARM_SUBSCRIPTION_ID
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_ARM_TENANT_ID" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_ARM_TENANT_ID"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = each.value.CONTROLLER_ARM_TENANT_ID
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_ARM_CLIENT_ID" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_ARM_CLIENT_ID"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = module.AZURE_SERVICE_PRINCIPAL[each.key].service_principal.application_id
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_AZURE_TFSTATE_STORAGE_ACCOUNT_NAME" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_AZURE_TFSTATE_STORAGE_ACCOUNT_NAME"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = azurerm_storage_account.AZURE_TFSTATE_STORAGE_ACCOUNT[each.key].name
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_AZURE_RESOURCE_GROUP_NAME" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_AZURE_RESOURCE_GROUP_NAME"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].name
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_AZURE_TFSTATE_CONTAINER_NAME" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_AZURE_TFSTATE_CONTAINER_NAME"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = azurerm_storage_container.AZURE_TFSTATE_CONTAINER[each.key].name
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_OWNER_EMAIL" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_OWNER_EMAIL"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = each.value.CONTROLLER_OWNER_EMAIL
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_AZURE_REGION" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_AZURE_REGION"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  plaintext_value = each.value.CONTROLLER_AZURE_REGION
  repository      = data.github_repository.REPOSITORY[each.key].name
}

resource "github_actions_secret" "CONTROLLER_REPOSITORY_FULL_NAME" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_REPOSITORY_FULL_NAME"
  #  environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  repository      = data.github_repository.REPOSITORY[each.key].name
  plaintext_value = each.value.CONTROLLER_REPOSITORY_FULL_NAME
}

resource "github_actions_secret" "CONTROLLER_REPOSITORY_TOKEN" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_REPOSITORY_TOKEN"
  #environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  repository      = data.github_repository.REPOSITORY[each.key].name
  plaintext_value = each.value.CONTROLLER_REPOSITORY_TOKEN
}

resource "github_actions_secret" "CONTROLLER_APPLICATIONS" {
  for_each    = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  secret_name = "CONTROLLER_APPLICATIONS"
  #environment     = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  repository      = data.github_repository.REPOSITORY[each.key].name
  plaintext_value = each.value.CONTROLLER_APPLICATIONS
}

resource "github_actions_variable" "CONTROLLER_DEPLOYED" {
  for_each      = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
  variable_name = "CONTROLLER_DEPLOYED"
  #environment   = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
  repository = data.github_repository.REPOSITORY[each.key].name
  value      = each.value.CONTROLLER_DEPLOYED
}

#resource "null_resource" "environments" {
#  for_each = { for controller in var.controllers : controller.CONTROLLER_REPOSITORY_FULL_NAME => controller }
#  triggers = {
#    environment = github_actions_variable.CONTROLLER_DEPLOYED[each.key].value
#  }
#  provisioner "local-exec" {
#    command = "gh workflow run authorization.yml -R $repository -f application=$repository"
#    environment = {
#      repository = each.key
#       application = github_repository_environment.CONTROLLER_REPOSITORY_FULL_NAME[each.key].environment
#       #repository    = data.github_repository.REPOSITORY[each.key].name
#      #repository = data.github_repository.REPOSITORY[each.key].full_name
#    }
#  }
#}

