variable "regions" {
  description = "List of Azure regions to deploy"
  type        = list(string)
  default     = ["westeurope", "eastus"]
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "demo"
}