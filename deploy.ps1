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

# Search for existing resources
function Search-ResourceGroups {
    try {
        $rgs = az group list --query "[].name" -o tsv 2>&1
        if ($LASTEXITCODE -eq 0 -and $rgs) {
            return $rgs -split "`n" | Where-Object { $_ -ne "" }
        }
    } catch {}
    return @()
}

function Search-FunctionApps {
    param([string]$ResourceGroup)
    try {
        $apps = az functionapp list --resource-group $ResourceGroup --query "[].name" -o tsv 2>&1
        if ($LASTEXITCODE -eq 0 -and $apps) {
            return $apps -split "`n" | Where-Object { $_ -ne "" }
        }
    } catch {}
    return @()
}

function Search-WebApps {
    param([string]$ResourceGroup)
    try {
        $apps = az webapp list --resource-group $ResourceGroup --query "[].name" -o tsv 2>&1
        if ($LASTEXITCODE -eq 0 -and $apps) {
            return $apps -split "`n" | Where-Object { $_ -ne "" }
        }
    } catch {}
    return @()
}

function Search-StorageAccounts {
    param([string]$ResourceGroup)
    try {
        $accounts = az storage account list --resource-group $ResourceGroup --query "[].name" -o tsv 2>&1
        if ($LASTEXITCODE -eq 0 -and $accounts) {
            return $accounts -split "`n" | Where-Object { $_ -ne "" }
        }
    } catch {}
    return @()
}

function Search-PrivateDnsZones {
    param([string]$ResourceGroup)
    try {
        $zones = az network private-dns zone list --resource-group $ResourceGroup --query "[].name" -o tsv 2>&1
        if ($LASTEXITCODE -eq 0 -and $zones) {
            return $zones -split "`n" | Where-Object { $_ -ne "" }
        }
    } catch {}
    return @()
}

function Search-AppInsights {
    param([string]$ResourceGroup)
    try {
        $insights = az resource list --resource-group $ResourceGroup --resource-type "Microsoft.Insights/components" --query "[].name" -o tsv 2>&1
        if ($LASTEXITCODE -eq 0 -and $insights) {
            return $insights -split "`n" | Where-Object { $_ -ne "" }
        }
    } catch {}
    return @()
}

# Prompt for resource choice: existing, new, or skip
function Get-ResourceChoice {
    param(
        [string]$ResourceType,
        [string]$DefaultName,
        [string]$ResourceGroup,
        [scriptblock]$SearchFunction
    )
    
    Write-Host ""
    Write-Info "Configuring $ResourceType"
    
    # Search for existing resources
    $existingResources = @()
    if (-not [string]::IsNullOrWhiteSpace($ResourceGroup)) {
        try {
            $rgCheck = az group show --name $ResourceGroup 2>&1
            if ($LASTEXITCODE -eq 0) {
                $existingResources = & $SearchFunction $ResourceGroup
            }
        } catch {}
    }
    
    # Build options
    $options = @()
    $optionCount = 0
    
    if ($existingResources.Count -gt 0) {
        Write-Host "Existing $ResourceType resources found:"
        foreach ($resource in $existingResources) {
            Write-Host "  [$optionCount] Use existing: $resource"
            $options += "existing:$resource"
            $optionCount++
        }
    }
    
    Write-Host "  [$optionCount] Create new"
    $options += "new"
    $optionCount++
    
    Write-Host "  [$optionCount] Skip"
    $options += "skip"
    
    # Get user choice
    $choice = Read-Host "Select option (0-$optionCount) [0]"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = 0
    }
    
    if ($choice -match '^\d+$' -and [int]$choice -le $optionCount) {
        $selected = $options[[int]$choice]
        
        if ($selected -like "existing:*") {
            return "existing:$($selected -replace 'existing:','')"
        } elseif ($selected -eq "new") {
            $name = Read-Host "Enter $ResourceType name [$DefaultName]"
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = $DefaultName
            }
            return "new:$name"
        } else {
            return "skip:"
        }
    } else {
        Write-Warning "Invalid choice, defaulting to create new"
        $name = Read-Host "Enter $ResourceType name [$DefaultName]"
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = $DefaultName
        }
        return "new:$name"
    }
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
    
    # Search for existing resource groups
    $existingRGs = Search-ResourceGroups
    
    if ($existingRGs.Count -gt 0) {
        Write-Host "Existing resource groups found:"
        for ($i = 0; $i -lt $existingRGs.Count; $i++) {
            Write-Host "  [$i] $($existingRGs[$i])"
        }
        Write-Host "  [n] Create new"
        $rgChoice = Read-Host "Select option (0-$($existingRGs.Count - 1)) or 'n' for new"
        
        if ($rgChoice -match '^\d+$' -and [int]$rgChoice -lt $existingRGs.Count) {
            $RESOURCE_GROUP = $existingRGs[[int]$rgChoice]
            Write-Success "Using existing resource group: $RESOURCE_GROUP"
            # Get location from existing RG
            $LOCATION = az group show --name $RESOURCE_GROUP --query location -o tsv
        } else {
            $RESOURCE_GROUP = Read-Host "Enter resource group name [pa-gcloud15-rg]"
            if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
                $RESOURCE_GROUP = "pa-gcloud15-rg"
            }
            
            # Check if name already exists (suppress errors)
            $ErrorActionPreference = 'SilentlyContinue'
            $rgCheck = az group show --name $RESOURCE_GROUP 2>&1
            $ErrorActionPreference = 'Stop'
            if ($LASTEXITCODE -eq 0) {
                Write-Error "Resource group '$RESOURCE_GROUP' already exists. Please choose a different name."
                exit 1
            }
            
            $LOCATION = Read-Host "Enter location for resource group [uksouth]"
            if ([string]::IsNullOrWhiteSpace($LOCATION)) {
                $LOCATION = "uksouth"
            }
            Write-Info "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
            az group create --name $RESOURCE_GROUP --location $LOCATION | Out-Null
            Write-Success "Resource group created"
        }
    } else {
        $RESOURCE_GROUP = Read-Host "Enter resource group name [pa-gcloud15-rg]"
        if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
            $RESOURCE_GROUP = "pa-gcloud15-rg"
        }
        
        # Check if resource group exists (suppress errors)
        $ErrorActionPreference = 'SilentlyContinue'
        $rgCheck = az group show --name $RESOURCE_GROUP 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -eq 0) {
            Write-Warning "Resource group '$RESOURCE_GROUP' already exists"
            $useExisting = Read-Host "Use existing resource group? (y/n) [y]"
            if ([string]::IsNullOrWhiteSpace($useExisting) -or $useExisting -ne "n") {
                # Use existing - get location
                $LOCATION = az group show --name $RESOURCE_GROUP --query location -o tsv
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
    }
    
    # Prompt for Function App name
    Write-Info "Step 2: Function App Configuration"
    $existingFunctionApps = Search-FunctionApps -ResourceGroup $RESOURCE_GROUP
    
    if ($existingFunctionApps.Count -gt 0) {
        Write-Host "Existing Function Apps found in resource group:"
        for ($i = 0; $i -lt $existingFunctionApps.Count; $i++) {
            Write-Host "  [$i] $($existingFunctionApps[$i])"
        }
        Write-Host "  [n] Create new"
        $faChoice = Read-Host "Select option (0-$($existingFunctionApps.Count - 1)) or 'n' for new"
        
        if ($faChoice -match '^\d+$' -and [int]$faChoice -lt $existingFunctionApps.Count) {
            $FUNCTION_APP_NAME = $existingFunctionApps[[int]$faChoice]
            Write-Success "Using existing Function App: $FUNCTION_APP_NAME"
        } else {
            $FUNCTION_APP_NAME = Read-Host "Enter Function App name for backend API [pa-gcloud15-api]"
            if ([string]::IsNullOrWhiteSpace($FUNCTION_APP_NAME)) {
                $FUNCTION_APP_NAME = "pa-gcloud15-api"
            }
        }
    } else {
        $FUNCTION_APP_NAME = Read-Host "Enter Function App name for backend API [pa-gcloud15-api]"
        if ([string]::IsNullOrWhiteSpace($FUNCTION_APP_NAME)) {
            $FUNCTION_APP_NAME = "pa-gcloud15-api"
        }
    }
    
    # Prompt for Static Web App / App Service name
    Write-Info "Step 3: Frontend Configuration"
    $existingWebApps = Search-WebApps -ResourceGroup $RESOURCE_GROUP
    
    if ($existingWebApps.Count -gt 0) {
        Write-Host "Existing Web Apps found in resource group:"
        for ($i = 0; $i -lt $existingWebApps.Count; $i++) {
            Write-Host "  [$i] $($existingWebApps[$i])"
        }
        Write-Host "  [n] Create new"
        $waChoice = Read-Host "Select option (0-$($existingWebApps.Count - 1)) or 'n' for new"
        
        if ($waChoice -match '^\d+$' -and [int]$waChoice -lt $existingWebApps.Count) {
            $WEB_APP_NAME = $existingWebApps[[int]$waChoice]
            Write-Success "Using existing Web App: $WEB_APP_NAME"
        } else {
            $WEB_APP_NAME = Read-Host "Enter Static Web App name [pa-gcloud15-web]"
            if ([string]::IsNullOrWhiteSpace($WEB_APP_NAME)) {
                $WEB_APP_NAME = "pa-gcloud15-web"
            }
        }
    } else {
        $WEB_APP_NAME = Read-Host "Enter Static Web App name [pa-gcloud15-web]"
        if ([string]::IsNullOrWhiteSpace($WEB_APP_NAME)) {
            $WEB_APP_NAME = "pa-gcloud15-web"
        }
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
    
    if (-not [string]::IsNullOrWhiteSpace($SHAREPOINT_SITE_URL)) {
        $SHAREPOINT_SITE_ID = Read-Host "Enter SharePoint site ID (leave empty to auto-detect)"
        
        # Auto-detect site ID if not provided
        if ([string]::IsNullOrWhiteSpace($SHAREPOINT_SITE_ID)) {
            Write-Info "Attempting to auto-detect SharePoint site ID..."
            try {
                $siteUrl = $SHAREPOINT_SITE_URL -replace '^https://', ''
                $siteId = az rest --method GET `
                    --uri "https://graph.microsoft.com/v1.0/sites/$siteUrl" `
                    --query "id" -o tsv 2>&1
                
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($siteId)) {
                    $SHAREPOINT_SITE_ID = $siteId
                    Write-Success "Auto-detected Site ID: $SHAREPOINT_SITE_ID"
                } else {
                    Write-Warning "Could not auto-detect Site ID. You can find it later in SharePoint site settings."
                    $SHAREPOINT_SITE_ID = ""
                }
            } catch {
                Write-Warning "Could not auto-detect Site ID. You can find it later in SharePoint site settings."
                $SHAREPOINT_SITE_ID = ""
            }
        }
    } else {
        $SHAREPOINT_SITE_ID = ""
    }
    
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
    
    # Prompt for Storage Account
    Write-Info "Step 8: Storage Account Configuration"
    $storageChoice = Get-ResourceChoice -ResourceType "Storage Account" -DefaultName "$($FUNCTION_APP_NAME -replace '-','').ToLower()st" -ResourceGroup $RESOURCE_GROUP -SearchFunction ${function:Search-StorageAccounts}
    $STORAGE_CHOICE_TYPE = ($storageChoice -split ':')[0]
    $STORAGE_ACCOUNT_NAME = ($storageChoice -split ':', 2)[1]
    
    # Prompt for Private DNS Zone
    Write-Info "Step 9: Private DNS Zone Configuration"
    $dnsChoice = Get-ResourceChoice -ResourceType "Private DNS Zone" -DefaultName "privatelink.azurewebsites.net" -ResourceGroup $RESOURCE_GROUP -SearchFunction ${function:Search-PrivateDnsZones}
    $PRIVATE_DNS_CHOICE_TYPE = ($dnsChoice -split ':')[0]
    $PRIVATE_DNS_ZONE_NAME = ($dnsChoice -split ':', 2)[1]
    
    # Prompt for Application Insights
    Write-Info "Step 10: Application Insights Configuration"
    $aiChoice = Get-ResourceChoice -ResourceType "Application Insights" -DefaultName "$FUNCTION_APP_NAME-insights" -ResourceGroup $RESOURCE_GROUP -SearchFunction ${function:Search-AppInsights}
    $APP_INSIGHTS_CHOICE_TYPE = ($aiChoice -split ':')[0]
    $APP_INSIGHTS_NAME = ($aiChoice -split ':', 2)[1]
    
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
    Write-Host "  Storage Account: $STORAGE_CHOICE_TYPE ($STORAGE_ACCOUNT_NAME)"
    Write-Host "  Private DNS Zone: $PRIVATE_DNS_CHOICE_TYPE ($PRIVATE_DNS_ZONE_NAME)"
    Write-Host "  Application Insights: $APP_INSIGHTS_CHOICE_TYPE ($APP_INSIGHTS_NAME)"
    Write-Host ""
    
    $confirm = Read-Host "Proceed with deployment? (y/n) [y]"
    if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm -eq "y") {
        # Save configuration
        if (-not (Test-Path "config")) {
            New-Item -ItemType Directory -Path "config" | Out-Null
        }
        
        # Set default location if not set
        if ([string]::IsNullOrWhiteSpace($LOCATION)) {
            $LOCATION = 'uksouth'
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
LOCATION=$LOCATION
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
STORAGE_ACCOUNT_CHOICE=$STORAGE_CHOICE_TYPE
STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT_NAME
PRIVATE_DNS_CHOICE=$PRIVATE_DNS_CHOICE_TYPE
PRIVATE_DNS_ZONE_NAME=$PRIVATE_DNS_ZONE_NAME
APP_INSIGHTS_CHOICE=$APP_INSIGHTS_CHOICE_TYPE
APP_INSIGHTS_NAME=$APP_INSIGHTS_NAME
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

