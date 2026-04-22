terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
  }

  # ── Remote state (uncomment for production) ───────────────
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstatevwan"
  #   container_name       = "tfstate"
  #   key                  = "vwan.terraform.tfstate"
  #   use_oidc             = true
  # }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}
