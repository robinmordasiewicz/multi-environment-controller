data "github_repository" "repository" {
  full_name = var.repository_full_name
}

data "azurerm_subscription" "current" {}

locals {
  repository_full_name_no_slash = replace(data.github_repository.repository.full_name, "/", "-")
}

resource "azurerm_resource_group" "azure_resource_group" {
  for_each = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  name     = "${local.repository_full_name_no_slash}-${each.key}"
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

#resource "azurerm_log_analytics_workspace" "analytics_workspace" {
#  for_each            = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
#  name                = "${random_integer.random_number[each.key].result}${lower(each.key)}"
#  resource_group_name = azurerm_resource_group.azure_resource_group[each.key].name
#  location            = azurerm_resource_group.azure_resource_group[each.key].location
#  sku                 = "PerGB2018"
#  retention_in_days   = 30
#}

resource "azurerm_storage_account" "tfstate_storage_account" {
  for_each                  = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  resource_group_name       = azurerm_resource_group.azure_resource_group[each.key].name
  location                  = azurerm_resource_group.azure_resource_group[each.key].location
  name                      = "${random_integer.random_number[each.key].result}${lower(each.key)}"
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
  #public_network_access_enabled = false
  #blob_properties {
  #  last_access_time_enabled = true
  #  delete_retention_policy {
  #    days = 5
  #  }
  #}
  #queue_properties {
  #  logging {
  #    delete                = true
  #    read                  = true
  #    write                 = true
  #    version               = "1.0"
  #    retention_policy_days = 10
  #  }
  #}
}

#resource "azurerm_log_analytics_storage_insights" "analytics_storage_insights_ok" {
#  for_each             = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
#  name                 = "${each.key}-storageinsightconfig"
#  resource_group_name  = azurerm_resource_group.azure_resource_group[each.key].name
#  workspace_id         = azurerm_log_analytics_workspace.analytics_workspace[each.key].id
#  storage_account_id   = azurerm_storage_account.tfstate_storage_account[each.key].id
#  storage_account_key  = azurerm_storage_account.tfstate_storage_account[each.key].primary_access_key
#  blob_container_names = ["blob-[each.key]"]
#}

resource "azurerm_storage_container" "azure_tfstate_container" {
  for_each             = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  name                 = lower(each.key)
  storage_account_name = azurerm_storage_account.tfstate_storage_account[each.key].name
  #container_access_type = "private"
}

module "azure_service_principal" {
  for_each         = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment_name = each.value.REPOSITORY_BRANCH
  identity_name    = "${local.repository_full_name_no_slash}-${each.value.REPOSITORY_BRANCH}"
  source           = "git::https://github.com/ned1313/terraform-azuread-github_oidc.git?ref=ba992e5473e1a0fbe0093d84b2890f9e6b0ff0ab"
  entity_type      = "environment"
  repository_name  = data.github_repository.repository.full_name
}

resource "azurerm_role_assignment" "azure_provisioner_role_assignment" {
  for_each = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  #scope                = azurerm_resource_group.azure_resource_group[each.key].id
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}"
  role_definition_name = var.deployment_provisioner_role_name
  principal_id         = module.azure_service_principal[each.key].service_principal.object_id
}

resource "github_repository_environment" "repository_branch" {
  for_each    = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment = each.key
  repository  = data.github_repository.repository.name
  depends_on = [
    azurerm_role_assignment.azure_provisioner_role_assignment
  ]
}

resource "github_actions_environment_secret" "arm_subscription_id" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "ARM_SUBSCRIPTION_ID"
  plaintext_value = var.arm_subscription_id
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "arm_tenant_id" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "ARM_TENANT_ID"
  plaintext_value = var.arm_tenant_id
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "arm_client_id" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "ARM_CLIENT_ID"
  plaintext_value = module.azure_service_principal[each.key].service_principal.application_id
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "azure_service_principal_uuid" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "AZURE_SERVICE_PRINCIPAL_UUID"
  plaintext_value = module.azure_service_principal[each.key].service_principal.object_id
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "azure_storage_account_name" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "AZURE_STORAGE_ACCOUNT_NAME"
  plaintext_value = azurerm_storage_account.tfstate_storage_account[each.key].name
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "azure_storage_account_id" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "AZURE_STORAGE_ACCOUNT_ID"
  plaintext_value = azurerm_storage_account.tfstate_storage_account[each.key].id
  repository      = data.github_repository.repository.name
}


resource "github_actions_environment_secret" "azure_resource_group_name" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "AZURE_RESOURCE_GROUP_NAME"
  plaintext_value = azurerm_resource_group.azure_resource_group[each.key].name
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "tfstate_container_name" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "TFSTATE_CONTAINER_NAME"
  plaintext_value = azurerm_storage_container.azure_tfstate_container[each.key].name
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "owner_email" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "OWNER_EMAIL"
  plaintext_value = each.value.OWNER_EMAIL
  repository      = data.github_repository.repository.name
}

resource "github_actions_environment_secret" "azure_region" {
  for_each        = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment     = github_repository_environment.repository_branch[each.key].environment
  secret_name     = "AZURE_REGION"
  plaintext_value = each.value.AZURE_REGION
  repository      = data.github_repository.repository.name
}

resource "github_actions_secret" "controller_repository_token" {
  secret_name     = "CONTROLLER_REPOSITORY_TOKEN"
  repository      = data.github_repository.repository.name
  plaintext_value = var.controller_repository_token
}

resource "github_actions_secret" "controller_repository_full_name" {
  secret_name     = "CONTROLLER_REPOSITORY_FULL_NAME"
  repository      = data.github_repository.repository.name
  plaintext_value = var.controller_repository_full_name
}

resource "github_actions_environment_variable" "deployed" {
  for_each      = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  environment   = github_repository_environment.repository_branch[each.key].environment
  variable_name = "DEPLOYED"
  repository    = data.github_repository.repository.name
  value         = each.value.DEPLOYED
}

resource "null_resource" "environments" {
  for_each = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
  triggers = {
    arm_subscription_id        = github_actions_environment_secret.arm_subscription_id[each.key].plaintext_value
    arm_tenant_id              = github_actions_environment_secret.arm_tenant_id[each.key].plaintext_value
    arm_client_id              = github_actions_environment_secret.arm_client_id[each.key].plaintext_value
    azure_storage_account_name = github_actions_environment_secret.azure_storage_account_name[each.key].plaintext_value
    azure_resource_group_name  = github_actions_environment_secret.azure_resource_group_name[each.key].plaintext_value
    tfstate_container_name     = github_actions_environment_secret.tfstate_container_name[each.key].plaintext_value
    owner_email                = github_actions_environment_secret.owner_email[each.key].plaintext_value
    azure_region               = github_actions_environment_secret.azure_region[each.key].plaintext_value
    deployed                   = github_actions_environment_variable.deployed[each.key].value
    principal_id               = module.azure_service_principal[each.key].service_principal.object_id
  }
  provisioner "local-exec" {
    command = "gh workflow run environment.yml --ref ${each.key} -R ${data.github_repository.repository.full_name}"
  }
}

#resource "github_branch_protection" "protection" {
#  for_each      = { for deployment_environment in var.environments : deployment_environment.REPOSITORY_BRANCH => deployment_environment }
#  repository_id = data.github_repository.repository.node_id
#  pattern       = each.key
#  required_pull_request_reviews {
#    dismiss_stale_reviews           = true
#    required_approving_review_count = 1
#  }
#  depends_on = [github_branch.environment]
#}
