# Call module
# To maximize the free tier, pass the minimal parameters
terraform {
  backend "azurerm" {}

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

  cluster_name        = "test-aks-cluster"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "test-aks-k8s"
  
  # Free tier environment settings
  sku_tier   = "Free"
  vm_size    = "Standard_D2ads_v7"
  node_count = 1
  environment = "Dev"
}
# ==========================================
# Call your new Minimalist Free Java App Module
# ==========================================

module "free_java_backend" {
  source = "../../modules/azureContainerApp"

  # Pass properties from your existing infrastructure directly
  resource_group_name = azurerm_resource_group.your_existing_aks_rg.name
  location            = azurerm_resource_group.your_existing_aks_rg.location
  
  app_name        = "helloworld-app"
  
  # For setup, we can use a placeholder. Once your GitHub Actions pipeline builds 
  # your custom image to a free registry like GHCR, swap this string out.
  container_image = "://microsoft.com" 
}

# Optional root output to easily find your web application URL in the terminal
output "java_app_url" {
  value = "https://${module.free_java_backend.fqdn}"
}

