terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}

# 1. Create the Container App Managed Environment (Consumption / Free-tier eligible)
resource "azurerm_container_app_environment" "env" {
  name                = var.environment_name
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # Note: Do not attach a Log Analytics Workspace ID here if you want to keep costs at strict absolute zero, 
  # as Log Analytics ingestion can generate small data storage fees over time.
}

# 2. Deploy the Java App into the Environment
resource "azurerm_container_app" "app" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  template {
    # Allocating minimal resources (0.25 CPU and 0.5Gi RAM) fits safely within the monthly free grant
    container {
      name   = "java-hello-world"
      image  = var.container_image
      cpu    = "0.25"
      memory = "0.5Gi"
      
      env {
        name  = "JAVA_OPTS"
        value = "-Xms128m -Xmx256m" # Tightly manages Java memory footprints
      }
    }

    # CRITICAL FOR $0.00: Automatically scales to 0 instances when there is no traffic
    min_replicas = 0
    max_replicas = 1
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8080 # Matches standard Spring Boot default port
    
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# Output the public URL to access your app
output "fqdn" {
  value       = azurerm_container_app.app.ingress[0].fqdn
  description = "The public application URL"
}

