data "github_repository" "APPLICATION_REPOSITORY" {
  full_name = var.APPLICATION_REPOSITORY_FULL_NAME
}

data "github_repository_environments" "APPLICATION_ENVIRONMENTS" {
  repository = data.github_repository.APPLICATION_REPOSITORY.name
}

data "azurerm_subscription" "current" {
}

locals {
  APPLICATION_REPOSITORY_FULL_NAME_NO_SLASH = replace(data.github_repository.APPLICATION_REPOSITORY.full_name, "/", "-")
}

resource "azurerm_resource_group" "ENVIRONMENT_AZURE_RESOURCE_GROUP" {
  for_each = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  name     = "${local.APPLICATION_REPOSITORY_FULL_NAME_NO_SLASH}-${each.key}"
  location = each.value.ENVIRONMENT_AZURE_REGION
  tags = {
    Username = each.value.ENVIRONMENT_OWNER_EMAIL
  }
}

resource "random_integer" "random_number" {
  for_each = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  min      = 10000
  max      = 99999
}

resource "azurerm_storage_account" "ENVIRONMENT_AZURE_TFSTATE_STORAGE_ACCOUNT" {
  for_each                 = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  resource_group_name      = azurerm_resource_group.ENVIRONMENT_AZURE_RESOURCE_GROUP[each.key].name
  location                 = azurerm_resource_group.ENVIRONMENT_AZURE_RESOURCE_GROUP[each.key].location
  name                     = "${random_integer.random_number[each.key].result}${lower(each.key)}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "ENVIRONMENT_AZURE_TFSTATE_CONTAINER" {
  for_each             = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  name                 = lower(each.key)
  storage_account_name = azurerm_storage_account.ENVIRONMENT_AZURE_TFSTATE_STORAGE_ACCOUNT[each.key].name
}

#resource "azurerm_role_definition" "DEPLOYMENT_ENVIRONMENT_PROVISIONER_ROLE" {
#  for_each = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
#  name     = "${local.APPLICATION_REPOSITORY_FULL_NAME_NO_SLASH}-${each.key}-DEPLOYMENT_ENVIRONMENT_PROVISIONER-role"
#  #scope       = azurerm_resource_group.ENVIRONMENT_AZURE_RESOURCE_GROUP[each.key].id
#  #scope       = "/subscriptions/${each.value.ENVIRONMENT_ARM_SUBSCRIPTION_ID}"
#  #scope       = data.azurerm_subscription.current.id
#  scope       = azurerm_resource_group.ENVIRONMENT_AZURE_RESOURCE_GROUP[each.key].id
#  description = "${data.github_repository.APPLICATION_REPOSITORY.full_name} - ${each.key} - Deployment Environment Provisioner Role"
#  permissions {
#    actions     = ["*"]
#    not_actions = []
#  }
#  assignable_scopes = [
#    azurerm_resource_group.ENVIRONMENT_AZURE_RESOURCE_GROUP[each.key].id
#    #data.azurerm_subscription.current.id
#  ]
#}

module "ENVIRONMENT_AZURE_SERVICE_PRINCIPAL" {
  for_each         = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment_name = each.value.APPLICATION_REPOSITORY_BRANCHNAME
  identity_name    = "${local.APPLICATION_REPOSITORY_FULL_NAME_NO_SLASH}-${each.value.APPLICATION_REPOSITORY_BRANCHNAME}"
  source           = "ned1313/github_oidc/azuread"
  version          = ">=1.2.0"
  entity_type      = "environment"
  repository_name  = data.github_repository.APPLICATION_REPOSITORY.full_name
}

resource "azurerm_role_assignment" "ENVIRONMENT_AZURE_PROVISIONER_ROLE_ASSIGNMENT" {
  for_each = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  #scope                = azurerm_resource_group.ENVIRONMENT_AZURE_RESOURCE_GROUP[each.key].id
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
  role_definition_name = "multi-environment-controller_deployment-provisioner"
  principal_id         = module.ENVIRONMENT_AZURE_SERVICE_PRINCIPAL[each.key].service_principal.object_id
}

resource "github_repository_environment" "APPLICATION_REPOSITORY_BRANCHNAME" {
  for_each    = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment = each.key
  repository  = data.github_repository.APPLICATION_REPOSITORY.name
  depends_on = [
    azurerm_role_assignment.ENVIRONMENT_AZURE_PROVISIONER_ROLE_ASSIGNMENT
  ]
}

resource "github_actions_environment_secret" "ENVIRONMENT_ARM_SUBSCRIPTION_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "ENVIRONMENT_ARM_SUBSCRIPTION_ID"
  plaintext_value = each.value.ENVIRONMENT_ARM_SUBSCRIPTION_ID
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "ENVIRONMENT_ARM_TENANT_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "ENVIRONMENT_ARM_TENANT_ID"
  plaintext_value = var.ENVIRONMENT_ARM_TENANT_ID
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "ENVIRONMENT_ARM_CLIENT_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "ENVIRONMENT_ARM_CLIENT_ID"
  plaintext_value = module.ENVIRONMENT_AZURE_SERVICE_PRINCIPAL[each.key].service_principal.application_id
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "ENVIRONMENT_AZURE_TFSTATE_STORAGE_ACCOUNT_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "ENVIRONMENT_AZURE_TFSTATE_STORAGE_ACCOUNT_NAME"
  plaintext_value = azurerm_storage_account.ENVIRONMENT_AZURE_TFSTATE_STORAGE_ACCOUNT[each.key].name
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "ENVIRONMENT_AZURE_RESOURCE_GROUP_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "ENVIRONMENT_AZURE_RESOURCE_GROUP_NAME"
  plaintext_value = azurerm_resource_group.ENVIRONMENT_AZURE_RESOURCE_GROUP[each.key].name
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "AZURE_ENVIRONMENT_AZURE_TFSTATE_CONTAINER_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "AZURE_ENVIRONMENT_AZURE_TFSTATE_CONTAINER_NAME"
  plaintext_value = azurerm_storage_container.ENVIRONMENT_AZURE_TFSTATE_CONTAINER[each.key].name
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "ENVIRONMENT_OWNER_EMAIL" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "ENVIRONMENT_OWNER_EMAIL"
  plaintext_value = each.value.ENVIRONMENT_OWNER_EMAIL
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "ENVIRONMENT_AZURE_REGION" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "ENVIRONMENT_AZURE_REGION"
  plaintext_value = each.value.ENVIRONMENT_AZURE_REGION
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
}

resource "github_actions_environment_secret" "CONTROLLER_REPOSITORY_FULL_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "CONTROLLER_REPOSITORY_FULL_NAME"
  repository      = data.github_repository.APPLICATION_REPOSITORY.APPLICATION_REPOSITORY_BRANCHNAME
  plaintext_value = var.CONTROLLER_REPOSITORY_FULL_NAME
}

resource "github_actions_environment_secret" "CONTROLLER_REPOSITORY_TOKEN" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  secret_name     = "CONTROLLER_REPOSITORY_TOKEN"
  repository      = data.github_repository.APPLICATION_REPOSITORY.name
  plaintext_value = var.CONTROLLER_REPOSITORY_TOKEN
}

resource "github_actions_environment_variable" "ENVIRONMENT_DEPLOYED" {
  for_each      = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  environment   = github_repository_environment.APPLICATION_REPOSITORY_BRANCHNAME[each.key].environment
  variable_name = "ENVIRONMENT_DEPLOYED"
  repository    = data.github_repository.APPLICATION_REPOSITORY.name
  value         = each.value.ENVIRONMENT_DEPLOYED
}

resource "null_resource" "environments" {
  for_each = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
  triggers = {
    environment = github_actions_environment_variable.ENVIRONMENT_DEPLOYED[each.key].value
  }
  provisioner "local-exec" {
    command = "gh workflow run terraform-action.yml --ref $deployment_environment -R $repository"
    environment = {
      deployment_environment = each.key
      repository             = data.github_repository.APPLICATION_REPOSITORY.full_name
    }
  }
}

#resource "github_branch" "environment" {
#  for_each   = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
#  repository = data.github_repository.APPLICATION_REPOSITORY.name
#  branch     = each.key
#  depends_on = [
#    github_actions_environment_variable.ENVIRONMENT_DEPLOYED,
#    github_actions_environment_secret.ENVIRONMENT_ARM_SUBSCRIPTION_ID,
#    github_actions_environment_secret.ENVIRONMENT_ARM_TENANT_ID,
#    github_actions_environment_secret.ENVIRONMENT_ARM_CLIENT_ID,
#    github_actions_environment_secret.AZURE_ENVIRONMENT_AZURE_TFSTATE_CONTAINER_NAME,
#    github_actions_environment_secret.ENVIRONMENT_OWNER_EMAIL,
#    github_actions_environment_secret.ENVIRONMENT_AZURE_REGION,
#  ]
#}

#resource "github_branch_protection" "protection" {
#  for_each      = { for deployment_environment in var.environments : deployment_environment.APPLICATION_REPOSITORY_BRANCHNAME => deployment_environment }
#  repository_id = data.github_repository.APPLICATION_REPOSITORY.node_id
#  pattern       = each.key
#  required_pull_request_reviews {
#    dismiss_stale_reviews           = true
#    required_approving_review_count = 1
#  }
#  depends_on = [github_branch.environment]
#}

