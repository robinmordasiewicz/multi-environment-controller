terraform {
  required_version = "1.5.7"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "5.34.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.41.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.78.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
  backend "azurerm" {}
}

provider "github" {}
provider "tls" {}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
  use_oidc                   = true
}

provider "azuread" {
  use_oidc = true
}
