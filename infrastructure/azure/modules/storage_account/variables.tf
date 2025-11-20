variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  description = "Base string used to derive a globally unique storage account name"
  type        = string
}

variable "containers" {
  description = "List of blob containers to create"
  type        = list(string)
  default     = []
}

variable "account_tier" {
  type    = string
  default = "Standard"
}

variable "replication_type" {
  type    = string
  default = "LRS"
}

variable "tags" {
  type    = map(string)
  default = {}
}

