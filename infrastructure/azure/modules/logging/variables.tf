variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "naming_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

