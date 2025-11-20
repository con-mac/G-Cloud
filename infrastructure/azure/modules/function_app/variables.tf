variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name" {
  description = "Short name (without environment) used in resource naming"
  type        = string
}

variable "environment" {
  type = string
}

variable "storage_account_tier" {
  type    = string
  default = "Standard"
}

variable "storage_account_replication" {
  type    = string
  default = "LRS"
}

variable "application_insights_id" {
  type = string
}

variable "application_insights_key" {
  type = string
}

variable "app_settings" {
  type    = map(string)
  default = {}
}

variable "docker_image" {
  description = "Optional map describing a container image for the function app"
  type = object({
    registry_login_server = string
    image_name            = string
    image_tag             = string
  })
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

