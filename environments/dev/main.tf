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
  # Properly routes relative file system path up to the modules tree
  source = "../../modules/azureContainerApp"

  # Uses resource from azurerm_resource_group above
  resource_group_name = module.aks.rg.name
  location            = module.aks.rg.location
  
  app_name         = "my-unique-java-helloworld-app"
  environment_name = "hello-world-env"
  container_image  = "://microsoft.com" 
}

# Exposes your public link upon a successful deployment run
output "java_app_url" {
  value = "https://${module.free_java_backend.fqdn}"
  description = "The public web URL of your deployed Java application"
}

