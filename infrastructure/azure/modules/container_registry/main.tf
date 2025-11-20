locals {
  normalized_prefix = substr(replace(lower(var.name_prefix), "-", ""), 0, 40)
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_container_registry" "this" {
  name                = substr(format("%s%s", local.normalized_prefix, random_string.suffix.result), 0, 50)
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = var.tags
}

