data "github_repository" "REPOSITORY" {
  full_name = var.REPOSITORY_FULL_NAME
}

data "azurerm_subscription" "current" {
}

locals {
  REPOSITORY_FULL_NAME_NO_SLASH = replace(data.github_repository.REPOSITORY.full_name, "/", "-")
}

resource "azurerm_resource_group" "AZURE_RESOURCE_GROUP" {
  for_each = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  name     = "${local.REPOSITORY_FULL_NAME_NO_SLASH}-${each.key}"
  location = each.value.AZURE_REGION
  tags = {
    Username = each.value.OWNER_EMAIL
  }
}

resource "random_integer" "random_number" {
  for_each = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  min      = 10000
  max      = 99999
}

resource "azurerm_storage_account" "TFSTATE_STORAGE_ACCOUNT" {
  for_each                 = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  resource_group_name      = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].name
  location                 = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].location
  name                     = "${random_integer.random_number[each.key].result}${lower(each.key)}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "AZURE_TFSTATE_CONTAINER" {
  for_each             = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  name                 = lower(each.key)
  storage_account_name = azurerm_storage_account.TFSTATE_STORAGE_ACCOUNT[each.key].name
}

module "AZURE_SERVICE_PRINCIPAL" {
  for_each         = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment_name = each.value.REPOSITORY_BRANCH
  identity_name    = "${local.REPOSITORY_FULL_NAME_NO_SLASH}-${each.value.REPOSITORY_BRANCH}"
  source           = "ned1313/github_oidc/azuread"
  version          = ">=1.2.0"
  entity_type      = "environment"
  repository_name  = data.github_repository.REPOSITORY.full_name
}

resource "azurerm_role_assignment" "AZURE_PROVISIONER_ROLE_ASSIGNMENT" {
  for_each = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  #scope                = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].id
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
  role_definition_name = var.DEPLOYMENT_PROVISIONER_ROLE_NAME
  principal_id         = module.AZURE_SERVICE_PRINCIPAL[each.key].service_principal.object_id
}

resource "github_repository_environment" "REPOSITORY_BRANCH" {
  for_each    = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment = each.key
  repository  = data.github_repository.REPOSITORY.name
  depends_on = [
    azurerm_role_assignment.AZURE_PROVISIONER_ROLE_ASSIGNMENT
  ]
}

resource "github_actions_environment_secret" "ARM_SUBSCRIPTION_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "ARM_SUBSCRIPTION_ID"
  plaintext_value = var.ARM_SUBSCRIPTION_ID
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "ARM_TENANT_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "ARM_TENANT_ID"
  plaintext_value = var.ARM_TENANT_ID
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "ARM_CLIENT_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "ARM_CLIENT_ID"
  plaintext_value = module.AZURE_SERVICE_PRINCIPAL[each.key].service_principal.application_id
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "AZURE_STORAGE_ACCOUNT_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "AZURE_STORAGE_ACCOUNT_NAME"
  plaintext_value = azurerm_storage_account.TFSTATE_STORAGE_ACCOUNT[each.key].name
  repository      = data.github_repository.REPOSITORY.name
}
resource "github_actions_environment_secret" "AZURE_STORAGE_ACCOUNT_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "AZURE_STORAGE_ACCOUNT_ID"
  plaintext_value = azurerm_storage_account.TFSTATE_STORAGE_ACCOUNT[each.key].id
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "AZURE_SERVICE_PRINCIPLE_UUID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "AZURE_SERVICE_PRINCIPLE_UUID"
  plaintext_value = data.azurerm_client_config.current.object_id
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "AZURE_RESOURCE_GROUP_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "AZURE_RESOURCE_GROUP_NAME"
  plaintext_value = azurerm_resource_group.AZURE_RESOURCE_GROUP[each.key].name
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "TFSTATE_CONTAINER_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "TFSTATE_CONTAINER_NAME"
  plaintext_value = azurerm_storage_container.AZURE_TFSTATE_CONTAINER[each.key].name
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "OWNER_EMAIL" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "OWNER_EMAIL"
  plaintext_value = each.value.OWNER_EMAIL
  repository      = data.github_repository.REPOSITORY.name
}

resource "github_actions_environment_secret" "AZURE_REGION" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  secret_name     = "AZURE_REGION"
  plaintext_value = each.value.AZURE_REGION
  repository      = data.github_repository.REPOSITORY.name
}

#resource "github_actions_environment_secret" "REPOSITORY_FULL_NAME" {
#  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
#  environment     = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
#  secret_name     = "REPOSITORY_FULL_NAME"
#  repository      = data.github_repository.REPOSITORY.name
#  plaintext_value = var.REPOSITORY_FULL_NAME
#}

resource "github_actions_secret" "CONTROLLER_REPOSITORY_TOKEN" {
  secret_name     = "CONTROLLER_REPOSITORY_TOKEN"
  repository      = data.github_repository.REPOSITORY.name
  plaintext_value = var.CONTROLLER_REPOSITORY_TOKEN
}

resource "github_actions_secret" "CONTROLLER_REPOSITORY_FULL_NAME" {
  secret_name     = "CONTROLLER_REPOSITORY_FULL_NAME"
  repository      = data.github_repository.REPOSITORY.name
  plaintext_value = var.CONTROLLER_REPOSITORY_FULL_NAME
}

resource "github_actions_environment_variable" "DEPLOYED" {
  for_each      = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment   = github_repository_environment.REPOSITORY_BRANCH[each.key].environment
  variable_name = "DEPLOYED"
  repository    = data.github_repository.REPOSITORY.name
  value         = each.value.DEPLOYED
}

resource "null_resource" "environments" {
  for_each = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  triggers = {
    ARM_SUBSCRIPTION_ID             = github_actions_environment_secret.ARM_SUBSCRIPTION_ID[each.key].plaintext_value
    ARM_TENANT_ID                   = github_actions_environment_secret.ARM_TENANT_ID[each.key].plaintext_value
    ARM_CLIENT_ID                   = github_actions_environment_secret.ARM_CLIENT_ID[each.key].plaintext_value
    AZURE_STORAGE_ACCOUNT_NAME    = github_actions_environment_secret.AZURE_STORAGE_ACCOUNT_NAME[each.key].plaintext_value
    AZURE_RESOURCE_GROUP_NAME       = github_actions_environment_secret.AZURE_RESOURCE_GROUP_NAME[each.key].plaintext_value
    TFSTATE_CONTAINER_NAME          = github_actions_environment_secret.TFSTATE_CONTAINER_NAME[each.key].plaintext_value
    OWNER_EMAIL                     = github_actions_environment_secret.OWNER_EMAIL[each.key].plaintext_value
    AZURE_REGION                    = github_actions_environment_secret.AZURE_REGION[each.key].plaintext_value
    #CONTROLLER_REPOSITORY_FULL_NAME = github_actions_environment_secret.CONTROLLER_REPOSITORY_FULL_NAME.plaintext_value
    #CONTROLLER_REPOSITORY_TOKEN     = github_actions_environment_secret.CONTROLLER_REPOSITORY_TOKEN.plaintext_value
    DEPLOYED                        = github_actions_environment_variable.DEPLOYED[each.key].value
    principal_id                    = module.AZURE_SERVICE_PRINCIPAL[each.key].service_principal.object_id
  }
  provisioner "local-exec" {
    command = "gh workflow run environment.yml --ref ${each.key} -R ${data.github_repository.REPOSITORY.full_name}"
  }
}

#resource "github_branch" "environment" {
#  for_each   = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
#  repository = data.github_repository.REPOSITORY.name
#  branch     = each.key
#  depends_on = [
#    github_actions_environment_variable.DEPLOYED,
#    github_actions_environment_secret.ARM_SUBSCRIPTION_ID,
#    github_actions_environment_secret.ARM_TENANT_ID,
#    github_actions_environment_secret.ARM_CLIENT_ID,
#    github_actions_environment_secret.TFSTATE_CONTAINER_NAME,
#    github_actions_environment_secret.OWNER_EMAIL,
#    github_actions_environment_secret.AZURE_REGION,
#  ]
#}

#resource "github_branch_protection" "protection" {
#  for_each      = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
#  repository_id = data.github_repository.REPOSITORY.node_id
#  pattern       = each.key
#  required_pull_request_reviews {
#    dismiss_stale_reviews           = true
#    required_approving_review_count = 1
#  }
#  depends_on = [github_branch.environment]
#}

