# Call module
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
  }
}

provider "azurerm" {
  features {}
}

# Separate Enterprise Resource Group for Production
resource "azurerm_resource_group" "prod_rg" {
  name     = "aks-producion-rg"
  location = "East US"
}

# Call the Reusable Module with Production Specifications
module "prod_aks" {
  source = "../../modules/aks"

  cluster_name        = "prod-learning-aks"
  resource_group_name = azurerm_resource_group.prod_rg.name
  location            = azurerm_resource_group.prod_rg.location
  dns_prefix          = "prod-enterprise-k8s"
  
  # Production Scale & SLA Configs
  sku_tier   = "Standard"         # Activates 99.95% financially backed Uptime SLA (~$73/mo)
  vm_size    = "Standard_D4s_v5"  # Enterprise tier (4 vCPU, 16GB RAM, Production storage speed)
  node_count = 3                  # Multi-node resiliency across availability zones
  environment = "Prod"
  
  # Production Isolated Network Footprint
  vnet_address_space    = ["10.200.0.0/16"]  # Distinct network spacing to prevent corporate VPN overlaps
  subnet_address_prefix = ["10.200.1.0/24"]
}

# Production App Provider Authentication
provider "kubernetes" {
  host                   = module.prod_aks.kube_config.0.host
  client_certificate     = base64decode(module.prod_aks.kube_config.0.client_certificate)
  client_key             = base64decode(module.prod_aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(module.prod_aks.kube_config.0.cluster_ca_certificate)
}

# Production Web App Scaling (High Availability)
resource "kubernetes_deployment" "prod_web_app" {
  metadata {
    name = "production-web-service"
    labels = { app = "enterprise-frontend" }
  }

  spec {
    replicas = 3 # Spreads pods evenly across your 3 production nodes for redundancy

    selector {
      match_labels = { app = "enterprise-frontend" }
    }

    template {
      metadata {
        labels = { app = "enterprise-frontend" }
      }

      spec {
        container {
          image = "nginx:alpine"
          name  = "prod-web-server"

          # Higher resource limits for production scale
          resources {
            limits = {
              cpu    = "1.0"
              memory = "1Gi"
            }
            requests = {
              cpu    = "0.5"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "prod_web_service" {
  metadata {
    name = "prod-web-service-public"
  }
  spec {
    selector = {
      app = kubernetes_deployment.prod_web_app.metadata.0.labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
