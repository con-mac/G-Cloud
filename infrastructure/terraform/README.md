# Terraform Infrastructure

This directory contains Terraform configurations for deploying the G-Cloud Automation System to Azure.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Azure subscription with appropriate permissions

## Setup

1. **Authenticate with Azure:**
   ```bash
   az login
   az account set --subscription "<subscription-id>"
   ```

2. **Create a backend storage account (one-time setup):**
   ```bash
   # Create resource group for Terraform state
   az group create --name terraform-state-rg --location uksouth
   
   # Create storage account
   az storage account create \
     --name tfstate<unique-id> \
     --resource-group terraform-state-rg \
     --location uksouth \
     --sku Standard_LRS
   
   # Create container
   az storage container create \
     --name tfstate \
     --account-name tfstate<unique-id>
   ```

3. **Create a `terraform.tfvars` file:**
   ```hcl
   project_name        = "gcloud-automation"
   environment         = "dev"
   location            = "uksouth"
   db_admin_username   = "gcloadmin"
   db_admin_password   = "<secure-password>"
   app_secret_key      = "<random-secret-key>"
   ```

4. **Create a backend configuration file `backend.hcl`:**
   ```hcl
   resource_group_name  = "terraform-state-rg"
   storage_account_name = "tfstate<unique-id>"
   container_name       = "tfstate"
   key                  = "gcloud-automation-dev.tfstate"
   ```

## Usage

### Initialise Terraform
```bash
terraform init -backend-config=backend.hcl
```

### Plan deployment
```bash
terraform plan -var-file="terraform.tfvars"
```

### Apply configuration
```bash
terraform apply -var-file="terraform.tfvars"
```

### Destroy infrastructure
```bash
terraform destroy -var-file="terraform.tfvars"
```

## Environments

Create separate `.tfvars` files for each environment:

- `terraform.dev.tfvars` - Development environment
- `terraform.staging.tfvars` - Staging environment
- `terraform.prod.tfvars` - Production environment

Deploy to a specific environment:
```bash
terraform apply -var-file="terraform.prod.tfvars"
```

## Resources Created

This Terraform configuration creates the following Azure resources:

- **Resource Group**: Container for all resources
- **App Service Plan**: Hosts the web applications
- **App Services** (2): Backend API and Frontend web app
- **PostgreSQL Flexible Server**: Database server
- **Redis Cache**: Caching and session storage
- **Storage Account**: Blob storage for documents
- **Key Vault**: Secrets management
- **Application Insights**: Monitoring and telemetry
- **Log Analytics Workspace**: Centralised logging

## Cost Estimation

**Development Environment (approximate monthly cost):**
- App Service Plan (B2): £50
- PostgreSQL Flexible Server (B1ms): £25
- Redis Cache (Basic C0): £12
- Storage Account (LRS): £5
- Application Insights: £5
- **Total**: ~£97/month

**Production Environment will be higher based on SKU selections.**

## Security Notes

- Never commit `.tfvars` files with sensitive data
- Use Azure Key Vault for production secrets
- Enable managed identities where possible
- Review network security groups and firewall rules
- Enable audit logging for all resources

## Troubleshooting

### Backend initialisation fails
Ensure the storage account and container exist and you have access.

### Resource already exists
If a resource name is taken, modify the `project_name` variable.

### Permission denied
Ensure you have Owner or Contributor role on the subscription.

## Further Reading

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure PostgreSQL Documentation](https://docs.microsoft.com/en-us/azure/postgresql/)

