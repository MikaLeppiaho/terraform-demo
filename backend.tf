terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"  # Luo etukäteen
    storage_account_name = "tfstatemika" # Luo etukäteen
    container_name       = "state"
    key                  = "demo.tfstate"
  }
}
