# Call module
# To maximize the free tier, pass the minimal parameters
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "aks-learning-rg"
  location = "East US"
}

# Instantiate your reusable module
module "dev_aks" {
  source = "../../modules/azureKubernetesCluster"

  cluster_name        = "dev-learning-aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "dev-learning-k8s"
  
  # Free tier environment settings
  sku_tier   = "Free"
  vm_size    = "Standard_B2s"
  node_count = 1
  environment = "Dev"
}

