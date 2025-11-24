#!/bin/bash

# Configure Authentication Script
# Sets up Microsoft 365 SSO integration

set -e

# Load configuration
if [ ! -f config/deployment-config.env ]; then
    echo "Error: deployment-config.env not found. Please run deploy.sh first."
    exit 1
fi

source config/deployment-config.env

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

print_info "Configuring Microsoft 365 SSO authentication..."

# Check if App Registration exists
print_info "Checking for App Registration: $APP_REGISTRATION_NAME"
APP_ID=$(az ad app list --display-name "$APP_REGISTRATION_NAME" --query "[0].appId" -o tsv)

if [ -z "$APP_ID" ] || [ "$APP_ID" == "null" ]; then
    print_warning "App Registration not found. Creating..."
    
    # Get Web App URL
    WEB_APP_URL="https://${WEB_APP_NAME}.azurewebsites.net"
    
    # Create App Registration
    APP_ID=$(az ad app create \
        --display-name "$APP_REGISTRATION_NAME" \
        --web-redirect-uris "${WEB_APP_URL}/auth/callback" \
        --query appId -o tsv)
    
    print_success "App Registration created: $APP_ID"
    
    # Create service principal
    az ad sp create --id "$APP_ID" --output none
    
    # Add API permissions for SharePoint/Graph
    print_info "Adding API permissions..."
    print_warning "NOTE: The following permissions need to be added manually in Azure Portal:"
    print_warning "  - Microsoft Graph: User.Read"
    print_warning "  - Microsoft Graph: Files.ReadWrite.All (or Sites.ReadWrite.All)"
    print_warning "  - Microsoft Graph: offline_access"
    print_warning "Admin consent will be required for these permissions"
else
    print_success "App Registration found: $APP_ID"
fi

# Create client secret
print_info "Creating client secret..."
SECRET=$(az ad app credential reset --id "$APP_ID" --query password -o tsv)

# Store in Key Vault
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "AzureADClientId" \
    --value "$APP_ID" \
    --output none

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "AzureADClientSecret" \
    --value "$SECRET" \
    --output none

# Get tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "AzureADTenantId" \
    --value "$TENANT_ID" \
    --output none

# Update Function App settings
print_info "Updating Function App with authentication settings..."
az functionapp config appsettings set \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings \
        "AZURE_AD_TENANT_ID=@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/AzureADTenantId/)" \
        "AZURE_AD_CLIENT_ID=@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/AzureADClientId/)" \
        "AZURE_AD_CLIENT_SECRET=@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/AzureADClientSecret/)" \
    --output none

# Update Web App settings
print_info "Updating Web App with authentication settings..."
az webapp config appsettings set \
    --name "$WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings \
        "VITE_AZURE_AD_TENANT_ID=$TENANT_ID" \
        "VITE_AZURE_AD_CLIENT_ID=$APP_ID" \
        "VITE_AZURE_AD_REDIRECT_URI=${WEB_APP_URL}/auth/callback" \
    --output none

print_success "Authentication configuration complete!"
print_warning "IMPORTANT: Grant admin consent for API permissions in Azure Portal"
print_warning "IMPORTANT: Configure SharePoint site permissions for the App Registration"

