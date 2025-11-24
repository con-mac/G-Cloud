#!/bin/bash

# PA Environment Deployment Script
# Interactive deployment script for PA's Azure dev environment

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Prompt for resource name with option to select existing
prompt_resource() {
    local resource_type=$1
    local default_name=$2
    local existing_resources=("${!3}")
    
    echo ""
    print_info "Configuring $resource_type"
    
    if [ ${#existing_resources[@]} -gt 0 ]; then
        echo "Existing resources found:"
        for i in "${!existing_resources[@]}"; do
            echo "  [$i] ${existing_resources[$i]}"
        done
        echo "  [n] Create new"
        read -p "Select option (0-$((${#existing_resources[@]}-1)) or 'n' for new): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -lt "${#existing_resources[@]}" ]; then
            echo "${existing_resources[$choice]}"
            return
        fi
    fi
    
    read -p "Enter $resource_type name [$default_name]: " name
    echo "${name:-$default_name}"
}

# Main deployment function
main() {
    print_info "Starting PA Environment Deployment"
    print_info "This script will deploy the G-Cloud 15 automation tool to PA's Azure dev environment"
    echo ""
    
    check_prerequisites
    
    # Get subscription info
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    print_info "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    
    # Prompt for resource group
    print_info "Step 1: Resource Group Configuration"
    read -p "Enter resource group name [pa-gcloud15-rg]: " RESOURCE_GROUP
    RESOURCE_GROUP=${RESOURCE_GROUP:-pa-gcloud15-rg}
    
    # Check if resource group exists
    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group '$RESOURCE_GROUP' already exists"
        read -p "Use existing resource group? (y/n) [y]: " use_existing
        if [[ "${use_existing:-y}" != "y" ]]; then
            print_error "Please choose a different resource group name"
            exit 1
        fi
    else
        read -p "Enter location for resource group [uksouth]: " LOCATION
        LOCATION=${LOCATION:-uksouth}
        print_info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
        az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
        print_success "Resource group created"
    fi
    
    # Prompt for Function App name
    print_info "Step 2: Function App Configuration"
    read -p "Enter Function App name for backend API [pa-gcloud15-api]: " FUNCTION_APP_NAME
    FUNCTION_APP_NAME=${FUNCTION_APP_NAME:-pa-gcloud15-api}
    
    # Prompt for Static Web App / App Service name
    print_info "Step 3: Frontend Configuration"
    read -p "Enter Static Web App name [pa-gcloud15-web]: " WEB_APP_NAME
    WEB_APP_NAME=${WEB_APP_NAME:-pa-gcloud15-web}
    
    # Prompt for Key Vault
    print_info "Step 4: Key Vault Configuration"
    read -p "Enter Key Vault name [pa-gcloud15-kv]: " KEY_VAULT_NAME
    KEY_VAULT_NAME=${KEY_VAULT_NAME:-pa-gcloud15-kv}
    
    # Prompt for SharePoint configuration
    print_info "Step 5: SharePoint Configuration"
    read -p "Enter SharePoint site URL (e.g., https://paconsulting.sharepoint.com/sites/GCloud15): " SHAREPOINT_SITE_URL
    read -p "Enter SharePoint site ID (leave empty to auto-detect): " SHAREPOINT_SITE_ID
    
    # Prompt for App Registration
    print_info "Step 6: App Registration Configuration"
    read -p "Enter App Registration name [pa-gcloud15-app]: " APP_REGISTRATION_NAME
    APP_REGISTRATION_NAME=${APP_REGISTRATION_NAME:-pa-gcloud15-app}
    
    # Prompt for custom domain
    print_info "Step 7: Custom Domain Configuration"
    read -p "Enter custom domain name [PA-G-Cloud15] (for private DNS): " CUSTOM_DOMAIN
    CUSTOM_DOMAIN=${CUSTOM_DOMAIN:-PA-G-Cloud15}
    
    # Summary
    echo ""
    print_info "Deployment Configuration Summary:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Function App: $FUNCTION_APP_NAME"
    echo "  Web App: $WEB_APP_NAME"
    echo "  Key Vault: $KEY_VAULT_NAME"
    echo "  SharePoint Site: $SHAREPOINT_SITE_URL"
    echo "  App Registration: $APP_REGISTRATION_NAME"
    echo "  Custom Domain: $CUSTOM_DOMAIN"
    echo ""
    
    read -p "Proceed with deployment? (y/n) [y]: " confirm
    if [[ "${confirm:-y}" != "y" ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    # Save configuration
    mkdir -p config
    cat > config/deployment-config.env <<EOF
RESOURCE_GROUP=$RESOURCE_GROUP
FUNCTION_APP_NAME=$FUNCTION_APP_NAME
WEB_APP_NAME=$WEB_APP_NAME
KEY_VAULT_NAME=$KEY_VAULT_NAME
SHAREPOINT_SITE_URL=$SHAREPOINT_SITE_URL
SHAREPOINT_SITE_ID=$SHAREPOINT_SITE_ID
APP_REGISTRATION_NAME=$APP_REGISTRATION_NAME
CUSTOM_DOMAIN=$CUSTOM_DOMAIN
LOCATION=${LOCATION:-uksouth}
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
EOF
    
    print_success "Configuration saved to config/deployment-config.env"
    
    # Run deployment scripts
    print_info "Starting deployment..."
    bash scripts/setup-resources.sh
    bash scripts/deploy-functions.sh
    bash scripts/deploy-frontend.sh
    bash scripts/configure-auth.sh
    
    print_success "Deployment complete!"
    print_info "Next steps:"
    echo "  1. Configure SharePoint permissions in App Registration"
    echo "  2. Test authentication"
    echo "  3. Test SharePoint connectivity"
    echo "  4. Verify private endpoints"
}

# Run main function
main "$@"

