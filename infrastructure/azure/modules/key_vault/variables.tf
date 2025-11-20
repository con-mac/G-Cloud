variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}

