resource "azurerm_key_vault" "this" {
  name                = replace(var.name, "_", "-")
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
  purge_protection_enabled      = true
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = true
  tags                           = var.tags
}

