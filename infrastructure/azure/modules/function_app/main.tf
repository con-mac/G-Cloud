locals {
  base_app_settings = {
    "FUNCTIONS_EXTENSION_VERSION"      = "~4"
    "APPINSIGHTS_INSTRUMENTATIONKEY"   = var.application_insights_key
  }

  python_app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }

  docker_app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "custom"
  }
}

resource "random_string" "storage" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_account" "functions" {
  name                     = substr(replace(lower(format("%s%sfa", var.name, random_string.storage.result)), "-", ""), 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication
  allow_nested_items_to_be_public = false
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_service_plan" "functions" {
  name                = format("%s-plan", var.name)
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

resource "azurerm_linux_function_app" "this" {
  name                       = format("%s-%s", var.name, var.environment)
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_insights_key = var.application_insights_key

    application_stack {
      python_version = var.docker_image == null ? "3.10" : null

      dynamic "docker" {
        for_each = var.docker_image == null ? [] : [var.docker_image]
        content {
          registry_url = docker.value.registry_login_server
          image_name   = docker.value.image_name
          image_tag    = docker.value.image_tag
        }
      }
    }
  }

  app_settings = merge(
    local.base_app_settings,
    var.docker_image == null ? local.python_app_settings : local.docker_app_settings,
    var.app_settings,
  )

  tags = var.tags
}

