# Expose the configuration endpoints so your root application can leverage them.
output "cluster_name" {
  value = azurerm_kubernetes_cluster.azureKubernetesCluster.name
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.azureKubernetesCluster.kube_config_raw
  sensitive = true
}

