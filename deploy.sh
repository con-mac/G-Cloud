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

# Search for existing resources
search_resource_groups() {
    az group list --query "[].name" -o tsv 2>/dev/null || echo ""
}

search_storage_accounts() {
    local rg=$1
    az storage account list --resource-group "$rg" --query "[].name" -o tsv 2>/dev/null || echo ""
}

search_private_dns_zones() {
    local rg=$1
    az network private-dns zone list --resource-group "$rg" --query "[].name" -o tsv 2>/dev/null || echo ""
}

search_app_insights() {
    local rg=$1
    az resource list --resource-group "$rg" --resource-type "Microsoft.Insights/components" --query "[].name" -o tsv 2>/dev/null || echo ""
}

# Prompt for resource choice: existing, new, or skip
prompt_resource_choice() {
    local resource_type=$1
    local default_name=$2
    local resource_group=$3
    local search_func=$4
    
    echo ""
    print_info "Configuring $resource_type"
    
    # Search for existing resources
    local existing_resources
    if [ -n "$resource_group" ] && az group show --name "$resource_group" &> /dev/null; then
        existing_resources=($($search_func "$resource_group"))
    else
        existing_resources=()
    fi
    
    # Build options array
    local options=()
    local option_count=0
    
    if [ ${#existing_resources[@]} -gt 0 ]; then
        echo "Existing $resource_type resources found:"
        for i in "${!existing_resources[@]}"; do
            echo "  [$option_count] Use existing: ${existing_resources[$i]}"
            options+=("existing:${existing_resources[$i]}")
            ((option_count++))
        done
    fi
    
    echo "  [$option_count] Create new"
    options+=("new")
    ((option_count++))
    
    echo "  [$option_count] Skip"
    options+=("skip")
    
    # Get user choice
    read -p "Select option (0-$option_count) [0]: " choice
    choice=${choice:-0}
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "$option_count" ]; then
        local selected="${options[$choice]}"
        
        if [[ "$selected" == "existing:"* ]]; then
            echo "existing:${selected#existing:}"
        elif [[ "$selected" == "new" ]]; then
            read -p "Enter $resource_type name [$default_name]: " name
            echo "new:${name:-$default_name}"
        else
            echo "skip:"
        fi
    else
        print_warning "Invalid choice, defaulting to create new"
        read -p "Enter $resource_type name [$default_name]: " name
        echo "new:${name:-$default_name}"
    fi
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
    
    # Search for existing resource groups
    existing_rgs=($(search_resource_groups))
    
    if [ ${#existing_rgs[@]} -gt 0 ]; then
        echo "Existing resource groups found:"
        for i in "${!existing_rgs[@]}"; do
            echo "  [$i] ${existing_rgs[$i]}"
        done
        echo "  [n] Create new"
        read -p "Select option (0-$((${#existing_rgs[@]}-1)) or 'n' for new): " rg_choice
        
        if [[ "$rg_choice" =~ ^[0-9]+$ ]] && [ "$rg_choice" -lt "${#existing_rgs[@]}" ]; then
            RESOURCE_GROUP="${existing_rgs[$rg_choice]}"
            print_success "Using existing resource group: $RESOURCE_GROUP"
            # Get location from existing RG
            LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
        else
            read -p "Enter resource group name [pa-gcloud15-rg]: " RESOURCE_GROUP
            RESOURCE_GROUP=${RESOURCE_GROUP:-pa-gcloud15-rg}
            
            # Check if name already exists
            if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
                print_error "Resource group '$RESOURCE_GROUP' already exists. Please choose a different name."
                exit 1
            fi
            
            read -p "Enter location for resource group [uksouth]: " LOCATION
            LOCATION=${LOCATION:-uksouth}
            print_info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
            az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
            print_success "Resource group created"
        fi
    else
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
            LOCATION=$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)
        else
            read -p "Enter location for resource group [uksouth]: " LOCATION
            LOCATION=${LOCATION:-uksouth}
            print_info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
            az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
            print_success "Resource group created"
        fi
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
    
    # Prompt for Storage Account
    print_info "Step 8: Storage Account Configuration"
    STORAGE_CHOICE=$(prompt_resource_choice "Storage Account" "${FUNCTION_APP_NAME}st" "$RESOURCE_GROUP" "search_storage_accounts")
    STORAGE_CHOICE_TYPE=$(echo "$STORAGE_CHOICE" | cut -d: -f1)
    STORAGE_ACCOUNT_NAME=$(echo "$STORAGE_CHOICE" | cut -d: -f2-)
    
    # Prompt for Private DNS Zone
    print_info "Step 9: Private DNS Zone Configuration"
    PRIVATE_DNS_CHOICE=$(prompt_resource_choice "Private DNS Zone" "privatelink.azurewebsites.net" "$RESOURCE_GROUP" "search_private_dns_zones")
    PRIVATE_DNS_CHOICE_TYPE=$(echo "$PRIVATE_DNS_CHOICE" | cut -d: -f1)
    PRIVATE_DNS_ZONE_NAME=$(echo "$PRIVATE_DNS_CHOICE" | cut -d: -f2-)
    
    # Prompt for Application Insights
    print_info "Step 10: Application Insights Configuration"
    APP_INSIGHTS_CHOICE=$(prompt_resource_choice "Application Insights" "${FUNCTION_APP_NAME}-insights" "$RESOURCE_GROUP" "search_app_insights")
    APP_INSIGHTS_CHOICE_TYPE=$(echo "$APP_INSIGHTS_CHOICE" | cut -d: -f1)
    APP_INSIGHTS_NAME=$(echo "$APP_INSIGHTS_CHOICE" | cut -d: -f2-)
    
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
    echo "  Storage Account: $STORAGE_CHOICE_TYPE ($STORAGE_ACCOUNT_NAME)"
    echo "  Private DNS Zone: $PRIVATE_DNS_CHOICE_TYPE ($PRIVATE_DNS_ZONE_NAME)"
    echo "  Application Insights: $APP_INSIGHTS_CHOICE_TYPE ($APP_INSIGHTS_NAME)"
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
STORAGE_ACCOUNT_CHOICE=$STORAGE_CHOICE_TYPE
STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME
PRIVATE_DNS_CHOICE=$PRIVATE_DNS_CHOICE_TYPE
PRIVATE_DNS_ZONE_NAME=$PRIVATE_DNS_ZONE_NAME
APP_INSIGHTS_CHOICE=$APP_INSIGHTS_CHOICE_TYPE
APP_INSIGHTS_NAME=$APP_INSIGHTS_NAME
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

