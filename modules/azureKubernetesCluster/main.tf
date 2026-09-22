# ====================================================================
# Custom Virtual Network (Free)
# ====================================================================
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.cluster_name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
}

# ====================================================================
# Dedicated Subnet for AKS Nodes (Free)
# ====================================================================
resource "azurerm_subnet" "subnet" {
  name                 = "aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_address_prefix
}

# ====================================================================
# The AKS Cluster (Single block managing the topology dynamically)
# ====================================================================
resource "azurerm_kubernetes_cluster" "azureKubernetesCluster" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  sku_tier            = var.sku_tier # Dynamic tiering (Free vs Standard)

  default_node_pool {
    name       = "default"
    vm_size    = var.vm_size
    node_count = var.node_count
    
    # Binds node pools directly to our custom subnet
    vnet_subnet_id      = azurerm_subnet.subnet.id
    enable_auto_scaling = false
  }

  identity {
    type = "SystemAssigned"
  }

  # Advanced IP Management Profile
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
  }

  tags = {
    Environment = var.environment
  }
}

