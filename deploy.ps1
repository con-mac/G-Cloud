# PA Environment Deployment Script (PowerShell)
# Interactive deployment script for PA's Azure dev environment

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Azure CLI
    try {
        $azVersion = az version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI not found"
        }
    } catch {
        Write-Error "Azure CLI is not installed. Please install it first."
        exit 1
    }
    
    # Check if logged in
    try {
        $account = az account show 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Not logged in"
        }
    } catch {
        Write-Error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

# Prompt for resource name with option to select existing
function Get-ResourceName {
    param(
        [string]$ResourceType,
        [string]$DefaultName,
        [string[]]$ExistingResources = @()
    )
    
    Write-Host ""
    Write-Info "Configuring $ResourceType"
    
    if ($ExistingResources.Count -gt 0) {
        Write-Host "Existing resources found:"
        for ($i = 0; $i -lt $ExistingResources.Count; $i++) {
            Write-Host "  [$i] $($ExistingResources[$i])"
        }
        Write-Host "  [n] Create new"
        $choice = Read-Host "Select option (0-$($ExistingResources.Count - 1)) or 'n' for new"
        
        if ($choice -match '^\d+$' -and [int]$choice -lt $ExistingResources.Count) {
            return $ExistingResources[[int]$choice]
        }
    }
    
    $name = Read-Host "Enter $ResourceType name [$DefaultName]"
    if ([string]::IsNullOrWhiteSpace($name)) {
        return $DefaultName
    }
    return $name
}

# Main deployment function
function Start-Deployment {
    Write-Info "Starting PA Environment Deployment"
    Write-Info "This script will deploy the G-Cloud 15 automation tool to PA's Azure dev environment"
    Write-Host ""
    
    Test-Prerequisites
    
    # Get subscription info
    $subscription = az account show | ConvertFrom-Json
    $SUBSCRIPTION_ID = $subscription.id
    $SUBSCRIPTION_NAME = $subscription.name
    Write-Info "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    
    # Prompt for resource group
    Write-Info "Step 1: Resource Group Configuration"
    $RESOURCE_GROUP = Read-Host "Enter resource group name [pa-gcloud15-rg]"
    if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
        $RESOURCE_GROUP = "pa-gcloud15-rg"
    }
    
    # Check if resource group exists
    $rgExists = az group show --name $RESOURCE_GROUP 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Resource group '$RESOURCE_GROUP' already exists"
        $useExisting = Read-Host "Use existing resource group? (y/n) [y]"
        if ([string]::IsNullOrWhiteSpace($useExisting) -or $useExisting -ne "n") {
            # Use existing
        } else {
            Write-Error "Please choose a different resource group name"
            exit 1
        }
    } else {
        $LOCATION = Read-Host "Enter location for resource group [uksouth]"
        if ([string]::IsNullOrWhiteSpace($LOCATION)) {
            $LOCATION = "uksouth"
        }
        Write-Info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
        az group create --name $RESOURCE_GROUP --location $LOCATION | Out-Null
        Write-Success "Resource group created"
    }
    
    # Prompt for Function App name
    Write-Info "Step 2: Function App Configuration"
    $FUNCTION_APP_NAME = Read-Host "Enter Function App name for backend API [pa-gcloud15-api]"
    if ([string]::IsNullOrWhiteSpace($FUNCTION_APP_NAME)) {
        $FUNCTION_APP_NAME = "pa-gcloud15-api"
    }
    
    # Prompt for Static Web App / App Service name
    Write-Info "Step 3: Frontend Configuration"
    $WEB_APP_NAME = Read-Host "Enter Static Web App name [pa-gcloud15-web]"
    if ([string]::IsNullOrWhiteSpace($WEB_APP_NAME)) {
        $WEB_APP_NAME = "pa-gcloud15-web"
    }
    
    # Prompt for Key Vault
    Write-Info "Step 4: Key Vault Configuration"
    $KEY_VAULT_NAME = Read-Host "Enter Key Vault name [pa-gcloud15-kv]"
    if ([string]::IsNullOrWhiteSpace($KEY_VAULT_NAME)) {
        $KEY_VAULT_NAME = "pa-gcloud15-kv"
    }
    
    # Prompt for SharePoint configuration
    Write-Info "Step 5: SharePoint Configuration"
    $SHAREPOINT_SITE_URL = Read-Host "Enter SharePoint site URL (e.g., https://paconsulting.sharepoint.com/sites/GCloud15)"
    $SHAREPOINT_SITE_ID = Read-Host "Enter SharePoint site ID (leave empty to auto-detect)"
    
    # Prompt for App Registration
    Write-Info "Step 6: App Registration Configuration"
    $APP_REGISTRATION_NAME = Read-Host "Enter App Registration name [pa-gcloud15-app]"
    if ([string]::IsNullOrWhiteSpace($APP_REGISTRATION_NAME)) {
        $APP_REGISTRATION_NAME = "pa-gcloud15-app"
    }
    
    # Prompt for custom domain
    Write-Info "Step 7: Custom Domain Configuration"
    $CUSTOM_DOMAIN = Read-Host "Enter custom domain name [PA-G-Cloud15] (for private DNS)"
    if ([string]::IsNullOrWhiteSpace($CUSTOM_DOMAIN)) {
        $CUSTOM_DOMAIN = "PA-G-Cloud15"
    }
    
    # Summary
    Write-Host ""
    Write-Info "Deployment Configuration Summary:"
    Write-Host "  Resource Group: $RESOURCE_GROUP"
    Write-Host "  Function App: $FUNCTION_APP_NAME"
    Write-Host "  Web App: $WEB_APP_NAME"
    Write-Host "  Key Vault: $KEY_VAULT_NAME"
    Write-Host "  SharePoint Site: $SHAREPOINT_SITE_URL"
    Write-Host "  App Registration: $APP_REGISTRATION_NAME"
    Write-Host "  Custom Domain: $CUSTOM_DOMAIN"
    Write-Host ""
    
    $confirm = Read-Host "Proceed with deployment? (y/n) [y]"
    if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm -eq "y") {
        # Save configuration
        if (-not (Test-Path "config")) {
            New-Item -ItemType Directory -Path "config" | Out-Null
        }
        
        $configContent = @"
RESOURCE_GROUP=$RESOURCE_GROUP
FUNCTION_APP_NAME=$FUNCTION_APP_NAME
WEB_APP_NAME=$WEB_APP_NAME
KEY_VAULT_NAME=$KEY_VAULT_NAME
SHAREPOINT_SITE_URL=$SHAREPOINT_SITE_URL
SHAREPOINT_SITE_ID=$SHAREPOINT_SITE_ID
APP_REGISTRATION_NAME=$APP_REGISTRATION_NAME
CUSTOM_DOMAIN=$CUSTOM_DOMAIN
LOCATION=$($LOCATION ?? 'uksouth')
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
"@
        
        $configContent | Out-File -FilePath "config\deployment-config.env" -Encoding utf8
        
        Write-Success "Configuration saved to config\deployment-config.env"
        
        # Run deployment scripts
        Write-Info "Starting deployment..."
        & ".\scripts\setup-resources.ps1"
        & ".\scripts\deploy-functions.ps1"
        & ".\scripts\deploy-frontend.ps1"
        & ".\scripts\configure-auth.ps1"
        
        Write-Success "Deployment complete!"
        Write-Info "Next steps:"
        Write-Host "  1. Configure SharePoint permissions in App Registration"
        Write-Host "  2. Test authentication"
        Write-Host "  3. Test SharePoint connectivity"
        Write-Host "  4. Verify private endpoints"
    } else {
        Write-Info "Deployment cancelled"
        exit 0
    }
}

# Run main function
Start-Deployment

