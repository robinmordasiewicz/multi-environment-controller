terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~>5.34.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.41.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.71.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.5.1"
    }
  }
  backend "azurerm" {
  }
}

provider "github" {}

provider "azurerm" {
  features {}
  use_oidc = true
}

provider "azuread" {
  use_oidc = true
}
