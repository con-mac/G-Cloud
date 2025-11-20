variable "environment" {
  description = "Deployment environment identifier (e.g. prod, dev)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Base name for the primary resource group"
  type        = string
}

variable "resource_naming_prefix" {
  description = "Short prefix used when generating resource names"
  type        = string
}

variable "tags" {
  description = "Common tags applied to Azure resources"
  type        = map(string)
  default     = {}
}

variable "backend_resource_group" {
  description = "Resource group containing the Terraform state storage account"
  type        = string
}

variable "backend_storage_account" {
  description = "Storage account name for Terraform state"
  type        = string
}

variable "backend_container_name" {
  description = "Blob container name for Terraform state"
  type        = string
}

variable "state_key_suffix" {
  description = "Suffix appended to Terraform state blob key"
  type        = string
  default     = "infrastructure"
}

variable "static_webapp_sku" {
  description = "SKU for Azure Static Web App"
  type        = string
  default     = "Standard"
}

variable "static_webapp_location" {
  description = "Azure region for Static Web App (service limited to specific regions)"
  type        = string
  default     = "westeurope"
}

variable "storage_account_tier" {
  description = "Performance tier for storage accounts"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication" {
  description = "Replication for storage accounts"
  type        = string
  default     = "LRS"
}

