variable "resource_group_name" {
  type        = string
  description = "Name of your existing free AKS resource group"
}

variable "location" {
  type        = string
  description = "The Azure region (e.g., East US)"
}

variable "environment_name" {
  type        = string
  description = "Name for the container apps managed environment"
  default     = "hello-world-env"
}

variable "app_name" {
  type        = string
  description = "Globally unique name for your application endpoint"
}

variable "container_image" {
  type        = string
  description = "The Docker image path (e.g., ghcr.io/your-username/hello-world-java:latest)"
  default     = "://microsoft.com" # Default placeholder image
}

