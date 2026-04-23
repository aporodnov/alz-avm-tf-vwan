terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4, != 2.9.0"
    }
  }

  # ── Remote state ──────────────────────────────────────────
  # All backend values are supplied at init time via
  # -backend-config so each profile (Prod / Lab) can
  # target its own subscription, storage account, and state file.
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}
