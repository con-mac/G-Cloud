#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INFRA_DIR="${ROOT_DIR}/infrastructure/azure"
MODULES_DIR="${INFRA_DIR}/modules"

log() {
  printf '\n[azure-bootstrap] %s\n' "$1"
}

write_file() {
  local target_path="$1"
  shift
  local content="$*"
  if [[ -f "$target_path" ]]; then
    log "Updating ${target_path#${ROOT_DIR}/}"
  else
    log "Creating ${target_path#${ROOT_DIR}/}"
  fi
  printf '%s\n' "$content" > "$target_path"
}

log "Scaffolding Terraform directories"
mkdir -p "${INFRA_DIR}" "${MODULES_DIR}" \
  "${MODULES_DIR}/resource_group" \
  "${MODULES_DIR}/storage_account" \
  "${MODULES_DIR}/logging" \
  "${MODULES_DIR}/key_vault" \
  "${MODULES_DIR}/function_app" \
  "${MODULES_DIR}/static_web_app" \
  "${MODULES_DIR}/container_registry"

write_file "${INFRA_DIR}/backend.tf" "terraform {
  backend \"azurerm\" {
    resource_group_name  = var.backend_resource_group
    storage_account_name = var.backend_storage_account
    container_name       = var.backend_container_name
    key                  = format(\"%s/%s.terraform.tfstate\", var.environment, var.state_key_suffix)
  }
}"

write_file "${INFRA_DIR}/providers.tf" "terraform {
  required_version = \">= 1.6.0\"
  required_providers {
    azurerm = {
      source  = \"hashicorp/azurerm\"
      version = \"~> 3.115.0\"
    }
    random = {
      source  = \"hashicorp/random\"
      version = \"~> 3.6.0\"
    }
  }
}

provider \"azurerm\" {
  features {}
}
"

write_file "${INFRA_DIR}/variables.tf" "variable \"environment\" {
  description = \"Deployment environment identifier (e.g. prod, dev)\"
  type        = string
}

variable \"location\" {
  description = \"Azure region for resources\"
  type        = string
  default     = \"uksouth\"
}

variable \"resource_group_name\" {
  description = \"Base name for the primary resource group\"
  type        = string
}

variable \"resource_naming_prefix\" {
  description = \"Short prefix used when generating resource names\"
  type        = string
}

variable \"tags\" {
  description = \"Common tags applied to Azure resources\"
  type        = map(string)
  default     = {}
}

variable \"backend_resource_group\" {
  description = \"Resource group containing the Terraform state storage account\"
  type        = string
}

variable \"backend_storage_account\" {
  description = \"Storage account name for Terraform state\"
  type        = string
}

variable \"backend_container_name\" {
  description = \"Blob container name for Terraform state\"
  type        = string
}

variable \"state_key_suffix\" {
  description = \"Suffix appended to Terraform state blob key\"
  type        = string
  default     = \"infrastructure\"
}

variable \"static_webapp_sku\" {
  description = \"SKU for Azure Static Web App\"
  type        = string
  default     = \"Standard\"
}

variable \"storage_account_tier\" {
  description = \"Performance tier for storage accounts\"
  type        = string
  default     = \"Standard\"
}

variable \"storage_account_replication\" {
  description = \"Replication for storage accounts\"
  type        = string
  default     = \"LRS\"
}
"

write_file "${INFRA_DIR}/outputs.tf" "output \"resource_group_name\" {
  value = module.resource_group.name
}

output \"storage_account_name\" {
  value = module.primary_storage.name
}

output \"function_app_api_name\" {
  value = module.api_function.name
}

output \"function_app_pdf_name\" {
  value = module.pdf_function.name
}

output \"static_site_name\" {
  value = module.static_site.name
}
"

write_file "${INFRA_DIR}/main.tf" "locals {
  naming = {
    rg           = format(\"%s-%s-rg\", var.resource_naming_prefix, var.environment)
    storage_data = format(\"%sstorage%s\", var.resource_naming_prefix, var.environment)
    acr          = format(\"%sacr%s\", var.resource_naming_prefix, var.environment)
    kv           = format(\"%s-kv-%s\", var.resource_naming_prefix, var.environment)
  }
}

module \"resource_group\" {
  source      = \"./modules/resource_group\"
  name        = var.resource_group_name
  location    = var.location
  tags        = var.tags
}

module \"logging\" {
  source              = \"./modules/logging\"
  location            = var.location
  resource_group_name = module.resource_group.name
  naming_prefix       = var.resource_naming_prefix
  environment         = var.environment
  tags                = var.tags
}

module \"container_registry\" {
  source              = \"./modules/container_registry\"
  resource_group_name = module.resource_group.name
  location            = var.location
  name_prefix         = local.naming.acr
  tags                = var.tags
}

module \"primary_storage\" {
  source              = \"./modules/storage_account\"
  resource_group_name = module.resource_group.name
  location            = var.location
  name_prefix         = local.naming.storage_data
  containers          = [\"templates\", \"uploads\", \"sharepoint\", \"output\"]
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication
  tags                = var.tags
}

module \"key_vault\" {
  source              = \"./modules/key_vault\"
  resource_group_name = module.resource_group.name
  location            = var.location
  name                = local.naming.kv
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = var.tags
}

module \"api_function\" {
  source                    = \"./modules/function_app\"
  resource_group_name       = module.resource_group.name
  location                  = var.location
  name                      = format(\"%s-api\", var.resource_naming_prefix)
  environment               = var.environment
  application_insights_id   = module.logging.application_insights_id
  application_insights_key  = module.logging.application_insights_instrumentation_key
  identity_assignments      = []
  storage_account_tier      = var.storage_account_tier
  storage_account_replication = var.storage_account_replication
  app_settings = {
    \"WEBSITE_RUN_FROM_PACKAGE\" = \"1\"
    \"APPINSIGHTS_INSTRUMENTATIONKEY\" = module.logging.application_insights_instrumentation_key
  }
  tags = var.tags
}

module \"pdf_function\" {
  source                    = \"./modules/function_app\"
  resource_group_name       = module.resource_group.name
  location                  = var.location
  name                      = format(\"%s-pdf\", var.resource_naming_prefix)
  environment               = var.environment
  application_insights_id   = module.logging.application_insights_id
  application_insights_key  = module.logging.application_insights_instrumentation_key
  identity_assignments      = []
  storage_account_tier      = var.storage_account_tier
  storage_account_replication = var.storage_account_replication
  docker_image              = {
    registry_login_server = module.container_registry.login_server
    image_name            = format(\"%s/pdf-converter:latest\", module.container_registry.login_server)
  }
  tags = var.tags
}

module \"static_site\" {
  source              = \"./modules/static_web_app\"
  resource_group_name = module.resource_group.name
  location            = var.location
  name                = format(\"%s-frontend\", var.resource_naming_prefix)
  sku                 = var.static_webapp_sku
  tags                = var.tags
}

resource \"azurerm_key_vault_access_policy\" \"api_function\" {
  key_vault_id = module.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.api_function.identity_principal_id

  secret_permissions = [\"Get\", \"List\"]
}

resource \"azurerm_key_vault_access_policy\" \"pdf_function\" {
  key_vault_id = module.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.pdf_function.identity_principal_id

  secret_permissions = [\"Get\", \"List\"]
}

data \"azurerm_client_config\" \"current\" {}
"

write_file "${INFRA_DIR}/terraform.tfvars.example" "environment             = \"prod\"
location                = \"uksouth\"
resource_group_name     = \"gcloud-prod-rg\"
resource_naming_prefix  = \"gcloud\"
backend_resource_group  = \"gcloud-tfstate-rg\"
backend_storage_account = \"gcloudtfstateprod\"
backend_container_name  = \"tfstate\"
tags = {
  owner       = \"Platform\"
  costCentre  = \"G-Cloud\"
  environment = \"prod\"
}
"

write_file "${INFRA_DIR}/README.md" "# Azure Infrastructure

Generated by \`scripts/azure/bootstrap.sh\`.

## Structure
- \`main.tf\` wires the environment together using reusable modules.
- \`terraform.tfvars.example\` captures common defaults—copy to \`terraform.tfvars\` for real deployments.
- Modules under \`modules/\` encapsulate individual Azure services.

## Next steps
1. Create a Terraform state storage account (or update \`backend.tf\` variables).
2. Copy \`terraform.tfvars.example\` to \`terraform.tfvars\` and adjust naming/tag values.
3. Run \`terraform init\`, \`terraform plan\`, and \`terraform apply\` once credentials are configured.
4. Update module inputs (e.g. Key Vault secrets, Function App settings) as the application evolves.
"

write_file "${MODULES_DIR}/resource_group/variables.tf" "variable \"name\" {
  description = \"Resource group name\"
  type        = string
}

variable \"location\" {
  description = \"Azure region\"
  type        = string
}

variable \"tags\" {
  description = \"Tags for resource group\"
  type        = map(string)
  default     = {}
}
"

write_file "${MODULES_DIR}/resource_group/main.tf" "resource \"azurerm_resource_group\" \"this\" {
  name     = var.name
  location = var.location
  tags     = var.tags
}
"

write_file "${MODULES_DIR}/resource_group/outputs.tf" "output \"name\" {
  value = azurerm_resource_group.this.name
}

output \"location\" {
  value = azurerm_resource_group.this.location
}
"

write_file "${MODULES_DIR}/storage_account/variables.tf" "variable \"resource_group_name\" {
  type = string
}

variable \"location\" {
  type = string
}

variable \"name_prefix\" {
  description = \"Base string used to derive a globally unique storage account name\"
  type        = string
}

variable \"containers\" {
  description = \"List of blob containers to create\"
  type        = list(string)
  default     = []
}

variable \"account_tier\" {
  type    = string
  default = \"Standard\"
}

variable \"replication_type\" {
  type    = string
  default = \"LRS\"
}

variable \"tags\" {
  type    = map(string)
  default = {}
}
"

write_file "${MODULES_DIR}/storage_account/main.tf" "resource \"random_string\" \"suffix\" {
  length  = 4
  special = false
  upper   = false
}

resource \"azurerm_storage_account\" \"this\" {
  name                     = substr(replace(lower(var.name_prefix), \"-\", \"\"), 0, 18) # enforce length
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  allow_nested_items_to_be_public = false
  min_tls_version          = \"TLS1_2\"
  tags = var.tags
}

resource \"azurerm_storage_container\" \"containers\" {
  for_each              = toset(var.containers)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = \"private\"
}
"

write_file "${MODULES_DIR}/storage_account/outputs.tf" "output \"name\" {
  value = azurerm_storage_account.this.name
}

output \"primary_connection_string\" {
  value = azurerm_storage_account.this.primary_connection_string
}

output \"primary_access_key\" {
  value = azurerm_storage_account.this.primary_access_key
  sensitive = true
}
"

write_file "${MODULES_DIR}/logging/variables.tf" "variable \"resource_group_name\" {
  type = string
}

variable \"location\" {
  type = string
}

variable \"naming_prefix\" {
  type = string
}

variable \"environment\" {
  type = string
}

variable \"tags\" {
  type    = map(string)
  default = {}
}
"

write_file "${MODULES_DIR}/logging/main.tf" "resource \"azurerm_log_analytics_workspace\" \"this\" {
  name                = format(\"%s-law-%s\", var.naming_prefix, var.environment)
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = \"PerGB2018\"
  retention_in_days   = 30
  tags                = var.tags
}

resource \"azurerm_application_insights\" \"this\" {
  name                = format(\"%s-ai-%s\", var.naming_prefix, var.environment)
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = \"web\"
  tags                = var.tags
}
"

write_file "${MODULES_DIR}/logging/outputs.tf" "output \"application_insights_id\" {
  value = azurerm_application_insights.this.id
}

output \"application_insights_instrumentation_key\" {
  value = azurerm_application_insights.this.instrumentation_key
}

output \"log_analytics_workspace_id\" {
  value = azurerm_log_analytics_workspace.this.id
}
"

write_file "${MODULES_DIR}/key_vault/variables.tf" "variable \"resource_group_name\" {
  type = string
}

variable \"location\" {
  type = string
}

variable \"name\" {
  type = string
}

variable \"tenant_id\" {
  type = string
}

variable \"soft_delete_retention_days\" {
  type    = number
  default = 7
}

variable \"tags\" {
  type    = map(string)
  default = {}
}
"

write_file "${MODULES_DIR}/key_vault/main.tf" "resource \"azurerm_key_vault\" \"this\" {
  name                = replace(var.name, \"_\", \"-\")
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = \"standard\"
  purge_protection_enabled      = true
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = true
  tags                           = var.tags
}
"

write_file "${MODULES_DIR}/key_vault/outputs.tf" "output \"id\" {
  value = azurerm_key_vault.this.id
}

output \"name\" {
  value = azurerm_key_vault.this.name
}
"

write_file "${MODULES_DIR}/function_app/variables.tf" "variable \"resource_group_name\" {
  type = string
}

variable \"location\" {
  type = string
}

variable \"name\" {
  description = \"Short name (without environment) used in resource naming\"
  type        = string
}

variable \"environment\" {
  type = string
}

variable \"storage_account_tier\" {
  type    = string
  default = \"Standard\"
}

variable \"storage_account_replication\" {
  type    = string
  default = \"LRS\"
}

variable \"application_insights_id\" {
  type = string
}

variable \"application_insights_key\" {
  type = string
}

variable \"app_settings\" {
  type    = map(string)
  default = {}
}

variable \"docker_image\" {
  description = \"Optional map with keys registry_login_server and image_name when deploying container-based functions\"
  type        = object({
    registry_login_server = string
    image_name            = string
  })
  default     = null
}

variable \"identity_assignments\" {
  description = \"List of Azure AD object IDs to assign as user managed identities\"
  type        = list(string)
  default     = []
}

variable \"tags\" {
  type    = map(string)
  default = {}
}
"

write_file "${MODULES_DIR}/function_app/main.tf" "resource \"random_string\" \"storage\" {
  length  = 6
  special = false
  upper   = false
}

resource \"azurerm_storage_account\" \"functions\" {
  name                     = substr(replace(lower(format(\"%s%sfa\", var.name, random_string.storage.result)), \"-\", \"\"), 0, 24)
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication
  allow_nested_items_to_be_public = false
  min_tls_version          = \"TLS1_2\"
  tags                     = var.tags
}

resource \"azurerm_service_plan\" \"functions\" {
  name                = format(\"%s-plan\", var.name)
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = \"Linux\"
  sku_name            = \"Y1\"
  tags                = var.tags
}

resource \"azurerm_user_assigned_identity\" \"extra\" {
  for_each            = toset(var.identity_assignments)
  resource_group_name = var.resource_group_name
  location            = var.location
  name                = format(\"%s-identity-%s\", var.name, substr(each.value, 0, 6))
}

resource \"azurerm_linux_function_app\" \"this\" {
  name                       = format(\"%s-%s\", var.name, var.environment)
  resource_group_name        = var.resource_group_name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  identity {
    type = \"SystemAssigned\"
  }

  site_config {
    application_insights_key = var.application_insights_key

    application_stack {
      dynamic \"docker\" {
        for_each = var.docker_image == null ? [] : [var.docker_image]
        content {
          registry_url = docker.value.registry_login_server
          image_name   = docker.value.image_name
        }
      }

      dynamic \"python\" {
        for_each = var.docker_image == null ? [1] : []
        content {
          python_version = \"3.10\"
        }
      }
    }
  }

  app_settings = merge({
    \"FUNCTIONS_EXTENSION_VERSION\" = \"~4\"
    \"FUNCTIONS_WORKER_RUNTIME\"  = var.docker_image == null ? \"python\" : \"custom\"
    \"WEBSITE_RUN_FROM_PACKAGE\"   = var.docker_image == null ? \"1\" : null
    \"APPINSIGHTS_INSTRUMENTATIONKEY\" = var.application_insights_key
  }, var.app_settings)

  tags = var.tags
}
"

write_file "${MODULES_DIR}/function_app/outputs.tf" "output \"name\" {
  value = azurerm_linux_function_app.this.name
}

output \"identity_principal_id\" {
  value = azurerm_linux_function_app.this.identity[0].principal_id
}

output \"default_hostname\" {
  value = azurerm_linux_function_app.this.default_hostname
}
"

write_file "${MODULES_DIR}/static_web_app/variables.tf" "variable \"resource_group_name\" {
  type = string
}

variable \"location\" {
  type = string
}

variable \"name\" {
  type = string
}

variable \"sku\" {
  type    = string
  default = \"Standard\"
}

variable \"tags\" {
  type    = map(string)
  default = {}
}
"

write_file "${MODULES_DIR}/static_web_app/main.tf" "resource \"azurerm_static_site\" \"this\" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = var.sku
  sku_size            = var.sku
  tags                = var.tags
}
"

write_file "${MODULES_DIR}/static_web_app/outputs.tf" "output \"name\" {
  value = azurerm_static_site.this.name
}

output \"default_host\" {
  value = azurerm_static_site.this.default_host_name
}
"

write_file "${MODULES_DIR}/container_registry/variables.tf" "variable \"resource_group_name\" {
  type = string
}

variable \"location\" {
  type = string
}

variable \"name_prefix\" {
  description = \"Base string used for the ACR name\"
  type        = string
}

variable \"tags\" {
  type    = map(string)
  default = {}
}
"

write_file "${MODULES_DIR}/container_registry/main.tf" "resource \"azurerm_container_registry\" \"this\" {
  name                = substr(replace(lower(var.name_prefix), \"-\", \"\"), 0, 50)
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = \"Standard\"
  admin_enabled       = false
  tags                = var.tags
}
"

write_file "${MODULES_DIR}/container_registry/outputs.tf" "output \"id\" {
  value = azurerm_container_registry.this.id
}

output \"login_server\" {
  value = azurerm_container_registry.this.login_server
}
"

log \"Terraform Azure scaffold ready. Review files under infrastructure/azure/.\"
