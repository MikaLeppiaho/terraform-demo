terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"             # Luo etukäteen
    storage_account_name = "tfstate"                # Luo etukäteen
    container_name       = "state"
    key                  = "demo.tfstate"
  }
}

provider "azurerm" {
  features {}
}