# Define the configuration knobs that higher environments will eventually need to change.
variable "cluster_name" {
  type        = string
  description = "The name of the AKS cluster."
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for the cluster."
}

variable "environment" {
  type        = string
  description = "Deployment environment tag (e.g., Dev, Prod)."
  default     = "Dev"
}

variable "location" {
  type        = string
  description = "The Azure region to deploy resources."
}

variable "node_count" {
  type        = number
  description = "The initial number of worker nodes."
  default     = 1
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group."
}

variable "sku_tier" {
  type        = string
  description = "The SKU tier for the control plane. Allowed values: Free, Standard, Premium."
  default     = "Free"
}

variable "vm_size" {
  type        = string
  description = "The size of the Virtual Machines for the worker nodes."
  default     = "Standard_D2ads_v7"
}

# new networks

variable "subnet_address_prefix" {
  type        = list(string)
  description = "The address prefix for the AKS subnet."
  default     = ["10.0.1.0/24"]
}

variable "vnet_address_space" {
  type        = list(string)
  description = "The address space for the VNet."
  default     = ["10.0.0.0/16"]
}

