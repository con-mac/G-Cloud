variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  description = "Base string used for the ACR name"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

