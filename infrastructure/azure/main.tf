locals {
  naming = {
    rg           = format("%s-%s-rg", var.resource_naming_prefix, var.environment)
    storage_data = format("%sstorage%s", var.resource_naming_prefix, var.environment)
    acr          = format("%sacr%s", var.resource_naming_prefix, var.environment)
    kv           = format("%s-kv-%s", var.resource_naming_prefix, var.environment)
  }
}

module "resource_group" {
  source      = "./modules/resource_group"
  name        = var.resource_group_name
  location    = var.location
  tags        = var.tags
}

module "logging" {
  source              = "./modules/logging"
  location            = var.location
  resource_group_name = module.resource_group.name
  naming_prefix       = var.resource_naming_prefix
  environment         = var.environment
  tags                = var.tags
}

module "container_registry" {
  source              = "./modules/container_registry"
  resource_group_name = module.resource_group.name
  location            = var.location
  name_prefix         = local.naming.acr
  tags                = var.tags
}

module "primary_storage" {
  source              = "./modules/storage_account"
  resource_group_name = module.resource_group.name
  location            = var.location
  name_prefix         = local.naming.storage_data
  containers          = ["templates", "uploads", "sharepoint", "output"]
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication
  tags                = var.tags
}

module "key_vault" {
  source              = "./modules/key_vault"
  resource_group_name = module.resource_group.name
  location            = var.location
  name                = local.naming.kv
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = var.tags
}

module "api_function" {
  source                    = "./modules/function_app"
  resource_group_name       = module.resource_group.name
  location                  = var.location
  name                      = format("%s-api", var.resource_naming_prefix)
  environment               = var.environment
  application_insights_id   = module.logging.application_insights_id
  application_insights_key  = module.logging.application_insights_instrumentation_key
  storage_account_tier      = var.storage_account_tier
  storage_account_replication = var.storage_account_replication
  tags = var.tags
}

module "pdf_function" {
  source                    = "./modules/function_app"
  resource_group_name       = module.resource_group.name
  location                  = var.location
  name                      = format("%s-pdf", var.resource_naming_prefix)
  environment               = var.environment
  application_insights_id   = module.logging.application_insights_id
  application_insights_key  = module.logging.application_insights_instrumentation_key
  storage_account_tier      = var.storage_account_tier
  storage_account_replication = var.storage_account_replication
  docker_image              = {
    registry_login_server = module.container_registry.login_server
    image_name            = "pdf-converter"
    image_tag             = "latest"
  }
  tags = var.tags
}

module "static_site" {
  source              = "./modules/static_web_app"
  resource_group_name = module.resource_group.name
  location            = var.static_webapp_location
  name                = format("%s-frontend", var.resource_naming_prefix)
  sku                 = var.static_webapp_sku
  tags                = var.tags
}

resource "azurerm_key_vault_access_policy" "api_function" {
  key_vault_id = module.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.api_function.identity_principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "pdf_function" {
  key_vault_id = module.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.pdf_function.identity_principal_id

  secret_permissions = ["Get", "List"]
}

data "azurerm_client_config" "current" {}

