terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Uncomment after creating the storage account for remote state:
  #   az storage account create --name tfstateafsa --resource-group rg-azure-fullstack-app \
  #     --location northeurope --sku Standard_LRS
  #   az storage container create --name tfstate --account-name tfstateafsa
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-azure-fullstack-app"
  #   storage_account_name = "tfstateafsa"
  #   container_name       = "tfstate"
  #   key                  = "terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
