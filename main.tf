data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

data "github_repository" "repo" {
  full_name = var.REPOSITORY_NAME
}

module "oidc_sp" {
  for_each         = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment_name = each.value.name
  identity_name    = "${data.github_repository.repo.name}-${each.value.name}"
  source           = "ned1313/github_oidc/azuread"
  version          = ">=1.2.0"
  entity_type      = "environment"
  repository_name  = data.github_repository.repo.full_name
  depends_on       = [data.azurerm_client_config.current, data.azurerm_subscription.current, azurerm_storage_container.container]
}

resource "github_actions_environment_secret" "ARM_SUBSCRIPTION_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = each.key
  secret_name     = "ARM_SUBSCRIPTION_ID"
  plaintext_value = each.value.ARM_SUBSCRIPTION_ID
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_secret" "ARM_TENANT_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = each.key
  secret_name     = "ARM_TENANT_ID"
  plaintext_value = var.ARM_TENANT_ID
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_secret" "ARM_CLIENT_ID" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = each.key
  secret_name     = "ARM_CLIENT_ID"
  plaintext_value = module.oidc_sp[each.key].service_principal.application_id
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_secret" "AZURE_TFSTATE_STORAGE_ACCOUNT_NAME" {
  for_each    = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment = each.key
  secret_name = "AZURE_TFSTATE_STORAGE_ACCOUNT_NAME"
  # plaintext_value = "oidc${lower(each.key)}"
  plaintext_value = azurerm_storage_account.STORAGE_ACCOUNT[each.key].name
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_secret" "AZURE_TFSTATE_RESOURCE_GROUP_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = each.key
  secret_name     = "AZURE_TFSTATE_RESOURCE_GROUP_NAME"
  plaintext_value = "${data.github_repository.repo.name}-${each.key}-TFSTATE"
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_secret" "AZURE_TFSTATE_CONTAINER_NAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = each.key
  secret_name     = "AZURE_TFSTATE_CONTAINER_NAME"
  plaintext_value = azurerm_storage_container.container[each.key].name
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_secret" "TF_VAR_AZURE_USERNAME" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = each.key
  secret_name     = "TF_VAR_AZURE_USERNAME"
  plaintext_value = var.AZURE_USERNAME
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_secret" "TF_VAR_AZURE_REGION" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment     = each.key
  secret_name     = "TF_VAR_AZURE_REGION"
  plaintext_value = var.AZURE_REGION
  repository      = data.github_repository.repo.name
  depends_on      = [github_repository_environment.repo_environment]
}

resource "github_actions_environment_variable" "AZURE_DEPLOYED" {
  for_each      = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment   = github_repository_environment.repo_environment[each.key].environment
  variable_name = "AZURE_DEPLOYED"
  repository    = data.github_repository.repo.name
  value         = each.value.AZURE_DEPLOYED
  depends_on    = [github_repository_environment.repo_environment]
}

resource "null_resource" "environments" {
  for_each = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  triggers = {
    environment = github_actions_environment_variable.AZURE_DEPLOYED[each.key].value
  }
  provisioner "local-exec" {
    command = "gh workflow run terraform-action.yml --ref $deployment_environment -R $repository"
    environment = {
      deployment_environment = each.key
      repository             = data.github_repository.repo.full_name
    }
  }
  depends_on = [github_branch.environment]
}

resource "github_repository_environment" "repo_environment" {
  for_each    = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  environment = each.key
  repository  = data.github_repository.repo.name
  depends_on = [
    azurerm_storage_container.container,
    azurerm_role_assignment.provisioner,
    azurerm_role_assignment.state,
    azurerm_resource_group.terraform_state
  ]
}

resource "github_branch" "environment" {
  for_each   = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  repository = data.github_repository.repo.name
  branch     = each.key
  depends_on = [
    github_actions_environment_variable.AZURE_DEPLOYED,
    github_actions_environment_secret.ARM_SUBSCRIPTION_ID,
    github_actions_environment_secret.ARM_TENANT_ID,
    github_actions_environment_secret.ARM_CLIENT_ID,
    github_actions_environment_secret.AZURE_TFSTATE_STORAGE_ACCOUNT_NAME,
    github_actions_environment_secret.AZURE_TFSTATE_RESOURCE_GROUP_NAME,
    github_actions_environment_secret.AZURE_TFSTATE_CONTAINER_NAME,
    github_actions_environment_secret.TF_VAR_AZURE_USERNAME,
    github_actions_environment_secret.TF_VAR_AZURE_REGION,
  ]
}

resource "github_branch_protection" "protection" {
  for_each      = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  repository_id = data.github_repository.repo.node_id
  pattern       = each.key
  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 1
  }
  depends_on = [github_branch.environment]
}

resource "azurerm_resource_group" "terraform_state" {
  for_each = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  name     = "${data.github_repository.repo.name}-${each.key}-TFSTATE"
  location = var.AZURE_REGION
  tags = {
    Username            = var.AZURE_USERNAME
    Display_Name        = var.AZURE_DISPLAYNAME
    User_Principle_Name = var.AZURE_USER_PRINCIPLE_NAME
  }
  depends_on = [data.azurerm_client_config.current, data.azurerm_subscription.current]
}

resource "random_integer" "oidc" {
  for_each = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  min      = 10000
  max      = 99999
}

resource "azurerm_storage_account" "STORAGE_ACCOUNT" {
  for_each                 = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  resource_group_name      = azurerm_resource_group.terraform_state[each.key].name
  location                 = azurerm_resource_group.terraform_state[each.key].location
  name                     = "${random_integer.oidc[each.key].result}${lower(each.key)}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
  for_each             = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  name                 = lower(each.key)
  storage_account_name = azurerm_storage_account.STORAGE_ACCOUNT[each.key].name
}

resource "azurerm_role_definition" "deployment_environment_provisioner" {
  for_each    = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  name        = "${data.github_repository.repo.name}-${each.key}"
  scope       = "/subscriptions/${each.value.ARM_SUBSCRIPTION_ID}"
  description = "${each.key} - Deployment Environment Provisioner"

  permissions {
    actions     = ["*"]
    not_actions = []
  }
}

resource "azurerm_role_assignment" "provisioner" {
  for_each             = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  scope                = "/subscriptions/${each.value.ARM_SUBSCRIPTION_ID}"
  role_definition_name = azurerm_role_definition.deployment_environment_provisioner[each.key].name
  principal_id         = module.oidc_sp[each.key].service_principal.object_id
  depends_on           = [azurerm_role_definition.deployment_environment_provisioner]
}

resource "azurerm_role_assignment" "state" {
  for_each             = { for deployment_environment in var.environments : deployment_environment.name => deployment_environment }
  scope                = azurerm_storage_container.container[each.key].resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.oidc_sp[each.key].service_principal.object_id
  depends_on           = [azurerm_role_assignment.provisioner]
}

