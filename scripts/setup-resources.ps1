# Setup Azure Resources Script (PowerShell)
# Creates all necessary Azure resources for PA deployment

$ErrorActionPreference = "Stop"

# Load configuration
if (-not (Test-Path "config\deployment-config.env")) {
    Write-Error "deployment-config.env not found. Please run deploy.ps1 first."
    exit 1
}

# Parse environment file
$config = @{}
Get-Content "config\deployment-config.env" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $config[$matches[1]] = $matches[2]
    }
}

# Set variables
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME
$WEB_APP_NAME = $config.WEB_APP_NAME
$KEY_VAULT_NAME = $config.KEY_VAULT_NAME
$LOCATION = $config.LOCATION
$SUBSCRIPTION_ID = $config.SUBSCRIPTION_ID

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

Write-Info "Setting up Azure resources..."

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID" | Out-Null

# Handle Storage Account
$STORAGE_ACCOUNT_CHOICE = $config.STORAGE_ACCOUNT_CHOICE
$STORAGE_ACCOUNT_NAME = $config.STORAGE_ACCOUNT_NAME

# Clean storage account name if it contains invalid characters or expressions
if (-not [string]::IsNullOrWhiteSpace($STORAGE_ACCOUNT_NAME)) {
    # Remove any PowerShell expressions that might have been saved literally
    if ($STORAGE_ACCOUNT_NAME -match '\.ToLower\(\)|\.Substring\(|\[Math\]') {
        Write-Warning "Storage account name contains invalid expression, regenerating..."
        $STORAGE_ACCOUNT_NAME = ""
    }
}

if ([string]::IsNullOrWhiteSpace($STORAGE_ACCOUNT_CHOICE) -or $STORAGE_ACCOUNT_CHOICE -eq "new") {
    Write-Info "Creating Storage Account (for temporary files)..."
    if ([string]::IsNullOrWhiteSpace($STORAGE_ACCOUNT_NAME)) {
        # Generate storage account name: remove hyphens/underscores, lowercase, max 22 chars + "st"
        $cleanName = ($FUNCTION_APP_NAME -replace '-', '' -replace '_', '').ToLower()
        $maxLength = [Math]::Min(22, $cleanName.Length)
        $STORAGE_ACCOUNT_NAME = $cleanName.Substring(0, $maxLength) + "st"
    }
    # Validate storage account name (alphanumeric only, 3-24 chars)
    $STORAGE_ACCOUNT_NAME = $STORAGE_ACCOUNT_NAME -replace '[^a-z0-9]', ''
    if ($STORAGE_ACCOUNT_NAME.Length -lt 3 -or $STORAGE_ACCOUNT_NAME.Length -gt 24) {
        Write-Error "Invalid storage account name: $STORAGE_ACCOUNT_NAME (must be 3-24 alphanumeric characters)"
        exit 1
    }
    # Ensure variable is properly set and doesn't contain problematic characters
    if ([string]::IsNullOrWhiteSpace($STORAGE_ACCOUNT_NAME)) {
        Write-Error "Storage account name is empty or invalid"
        exit 1
    }
    Write-Info "Checking for Storage Account: $STORAGE_ACCOUNT_NAME"
    $ErrorActionPreference = 'SilentlyContinue'
    $storageExists = az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        az storage account create `
            --name "$STORAGE_ACCOUNT_NAME" `
            --resource-group "$RESOURCE_GROUP" `
            --location "$LOCATION" `
            --sku Standard_LRS `
            --kind StorageV2 `
            --allow-blob-public-access false `
            --min-tls-version TLS1_2 | Out-Null
        Write-Success "Storage Account created: $STORAGE_ACCOUNT_NAME"
    } else {
        Write-Warning "Storage Account already exists: $STORAGE_ACCOUNT_NAME"
    }
} elseif ($STORAGE_ACCOUNT_CHOICE -eq "existing") {
    if (-not [string]::IsNullOrWhiteSpace($STORAGE_ACCOUNT_NAME)) {
        $storageExists = az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Using existing Storage Account: $STORAGE_ACCOUNT_NAME"
        } else {
            Write-Warning "Storage Account '$STORAGE_ACCOUNT_NAME' not found, skipping"
            $STORAGE_ACCOUNT_NAME = ""
        }
    } else {
        Write-Warning "No Storage Account name provided for existing choice, skipping"
        $STORAGE_ACCOUNT_NAME = ""
    }
} else {
    Write-Info "Skipping Storage Account creation"
    $STORAGE_ACCOUNT_NAME = ""
}

# Create Key Vault
Write-Info "Creating Key Vault..."
$ErrorActionPreference = 'SilentlyContinue'
$kvExists = az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) {
    az keyvault create `
        --name "$KEY_VAULT_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --location "$LOCATION" `
        --sku standard `
        --enable-rbac-authorization true | Out-Null
    
    # Grant current user Key Vault Secrets Officer role for RBAC
    Write-Info "Granting Key Vault permissions to current user..."
    $currentUser = az ad signed-in-user show --query id -o tsv
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($currentUser)) {
        az role assignment create `
            --role "Key Vault Secrets Officer" `
            --assignee "$currentUser" `
            --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" `
            --output none | Out-Null
        Write-Success "Key Vault permissions granted"
    } else {
        Write-Warning "Could not grant Key Vault permissions automatically. Please grant 'Key Vault Secrets Officer' role manually."
    }
    
    Write-Success "Key Vault created: $KEY_VAULT_NAME"
} else {
    Write-Warning "Key Vault already exists: $KEY_VAULT_NAME"
}

# Create or update Function App (Consumption plan for serverless)
Write-Info "Setting up Function App for backend API..."
$ErrorActionPreference = 'SilentlyContinue'
$funcExists = az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) {
    # Create storage account for function app (required)
    $cleanFuncName = ($FUNCTION_APP_NAME -replace '-', '' -replace '_', '').ToLower()
    $maxFuncLength = [Math]::Min(20, $cleanFuncName.Length)
    $FUNC_STORAGE = $cleanFuncName.Substring(0, $maxFuncLength) + "func"
    # Validate function storage account name
    $FUNC_STORAGE = $FUNC_STORAGE -replace '[^a-z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($FUNC_STORAGE)) {
        Write-Error "Function storage account name is empty or invalid"
        exit 1
    }
    $ErrorActionPreference = 'SilentlyContinue'
    $funcStorageExists = az storage account show --name "$FUNC_STORAGE" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        az storage account create `
            --name "$FUNC_STORAGE" `
            --resource-group "$RESOURCE_GROUP" `
            --location "$LOCATION" `
            --sku Standard_LRS | Out-Null
    }
    
    # Create Function App
    az functionapp create `
        --name "$FUNCTION_APP_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --consumption-plan-location "$LOCATION" `
        --runtime python `
        --runtime-version 3.11 `
        --functions-version 4 `
        --storage-account "$FUNC_STORAGE" `
        --os-type Linux | Out-Null
    
    Write-Warning "NOTE: Private endpoint configuration requires VNet integration"
    Write-Warning "Please configure VNet integration and private endpoints manually or via script"
    
    Write-Success "Function App created: $FUNCTION_APP_NAME"
} else {
    Write-Success "Using existing Function App: $FUNCTION_APP_NAME"
    Write-Info "Function App will be updated with new configuration during deployment"
}

# Create or update Static Web App (or App Service for private hosting)
Write-Info "Setting up Web App for frontend..."
$ErrorActionPreference = 'SilentlyContinue'
$webAppExists = az webapp show --name "$WEB_APP_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Static Web Apps have limited private endpoint support"
    Write-Warning "Consider using App Service with private endpoints for full private access"
    
    # Create App Service Plan
    $APP_SERVICE_PLAN = "$WEB_APP_NAME-plan"
    $ErrorActionPreference = 'SilentlyContinue'
    $planExists = az appservice plan show --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        az appservice plan create `
            --name "$APP_SERVICE_PLAN" `
            --resource-group "$RESOURCE_GROUP" `
            --location "$LOCATION" `
            --sku B1 `
            --is-linux | Out-Null
    }
    
    # Create Web App (use node 20 as it's more widely supported)
    az webapp create `
        --name "$WEB_APP_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --plan "$APP_SERVICE_PLAN" `
        --runtime "NODE:20-lts" | Out-Null
    
    Write-Success "Web App created: $WEB_APP_NAME"
} else {
    Write-Success "Using existing Web App: $WEB_APP_NAME"
    Write-Info "Web App will be updated with new configuration during deployment"
}

# Handle Application Insights
$APP_INSIGHTS_CHOICE = $config.APP_INSIGHTS_CHOICE
$APP_INSIGHTS_NAME = $config.APP_INSIGHTS_NAME

if ([string]::IsNullOrWhiteSpace($APP_INSIGHTS_CHOICE) -or $APP_INSIGHTS_CHOICE -eq "new") {
    Write-Info "Creating Application Insights..."
    if ([string]::IsNullOrWhiteSpace($APP_INSIGHTS_NAME)) {
        $APP_INSIGHTS_NAME = "$FUNCTION_APP_NAME-insights"
    }
    $ErrorActionPreference = 'SilentlyContinue'
    $aiExists = az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        az monitor app-insights component create `
            --app "$APP_INSIGHTS_NAME" `
            --location "$LOCATION" `
            --resource-group "$RESOURCE_GROUP" `
            --application-type web | Out-Null
        Write-Success "Application Insights created: $APP_INSIGHTS_NAME"
    } else {
        Write-Warning "Application Insights already exists: $APP_INSIGHTS_NAME"
    }
} elseif ($APP_INSIGHTS_CHOICE -eq "existing") {
    if (-not [string]::IsNullOrWhiteSpace($APP_INSIGHTS_NAME)) {
        $ErrorActionPreference = 'SilentlyContinue'
        $aiExists = az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Using existing Application Insights: $APP_INSIGHTS_NAME"
        } else {
            Write-Warning "Application Insights '$APP_INSIGHTS_NAME' not found, skipping"
            $APP_INSIGHTS_NAME = ""
        }
    } else {
        Write-Warning "No Application Insights name provided for existing choice, skipping"
        $APP_INSIGHTS_NAME = ""
    }
} else {
    Write-Info "Skipping Application Insights creation"
    $APP_INSIGHTS_NAME = ""
}

# Store App Insights connection string (if created/using existing)
if (-not [string]::IsNullOrWhiteSpace($APP_INSIGHTS_NAME)) {
    $ErrorActionPreference = 'SilentlyContinue'
    $APP_INSIGHTS_CONNECTION = az monitor app-insights component show `
        --app "$APP_INSIGHTS_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --query connectionString -o tsv
    $ErrorActionPreference = 'Stop'
    
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($APP_INSIGHTS_CONNECTION)) {
        # Save to Key Vault
        az keyvault secret set `
            --vault-name "$KEY_VAULT_NAME" `
            --name "AppInsightsConnectionString" `
            --value "$APP_INSIGHTS_CONNECTION" `
            --output none | Out-Null
        Write-Success "Application Insights connection string saved to Key Vault"
    } else {
        Write-Warning "Could not retrieve Application Insights connection string"
    }
}

# Handle Private DNS Zone
$PRIVATE_DNS_CHOICE = $config.PRIVATE_DNS_CHOICE
$PRIVATE_DNS_ZONE_NAME = $config.PRIVATE_DNS_ZONE_NAME

if ([string]::IsNullOrWhiteSpace($PRIVATE_DNS_CHOICE) -or $PRIVATE_DNS_CHOICE -eq "new") {
    Write-Info "Creating Private DNS Zone..."
    if ([string]::IsNullOrWhiteSpace($PRIVATE_DNS_ZONE_NAME)) {
        $PRIVATE_DNS_ZONE_NAME = "privatelink.azurewebsites.net"
    }
    $ErrorActionPreference = 'SilentlyContinue'
    $dnsExists = az network private-dns zone show --name "$PRIVATE_DNS_ZONE_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) {
        az network private-dns zone create `
            --name "$PRIVATE_DNS_ZONE_NAME" `
            --resource-group "$RESOURCE_GROUP" | Out-Null
        Write-Success "Private DNS Zone created: $PRIVATE_DNS_ZONE_NAME"
    } else {
        Write-Warning "Private DNS Zone already exists: $PRIVATE_DNS_ZONE_NAME"
    }
} elseif ($PRIVATE_DNS_CHOICE -eq "existing") {
    if (-not [string]::IsNullOrWhiteSpace($PRIVATE_DNS_ZONE_NAME)) {
        $ErrorActionPreference = 'SilentlyContinue'
        $dnsExists = az network private-dns zone show --name "$PRIVATE_DNS_ZONE_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Using existing Private DNS Zone: $PRIVATE_DNS_ZONE_NAME"
        } else {
            Write-Warning "Private DNS Zone '$PRIVATE_DNS_ZONE_NAME' not found, skipping"
            $PRIVATE_DNS_ZONE_NAME = ""
        }
    } else {
        Write-Warning "No Private DNS Zone name provided for existing choice, skipping"
        $PRIVATE_DNS_ZONE_NAME = ""
    }
} else {
    Write-Info "Skipping Private DNS Zone creation"
    $PRIVATE_DNS_ZONE_NAME = ""
}

# Handle VNet and Private Endpoint Configuration
$CONFIGURE_PRIVATE_ENDPOINTS = $config.CONFIGURE_PRIVATE_ENDPOINTS
$VNET_NAME = $config.VNET_NAME
$SUBNET_NAME = $config.SUBNET_NAME

if ($CONFIGURE_PRIVATE_ENDPOINTS -eq "true" -and -not [string]::IsNullOrWhiteSpace($VNET_NAME)) {
    Write-Info "Configuring VNet and Private Endpoints..."
    
    # Check if VNet exists
    $ErrorActionPreference = 'SilentlyContinue'
    $vnetExists = az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Creating VNet: $VNET_NAME"
        az network vnet create `
            --name "$VNET_NAME" `
            --resource-group "$RESOURCE_GROUP" `
            --location "$LOCATION" `
            --address-prefix "10.0.0.0/16" `
            --output none | Out-Null
        Write-Success "VNet created: $VNET_NAME"
    } else {
        Write-Success "Using existing VNet: $VNET_NAME"
    }
    
    # Check if subnet exists
    $ErrorActionPreference = 'SilentlyContinue'
    $subnetExists = az network vnet subnet show --vnet-name "$VNET_NAME" --name "$SUBNET_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Creating subnet: $SUBNET_NAME"
        az network vnet subnet create `
            --vnet-name "$VNET_NAME" `
            --name "$SUBNET_NAME" `
            --resource-group "$RESOURCE_GROUP" `
            --address-prefix "10.0.1.0/24" `
            --output none | Out-Null
        Write-Success "Subnet created: $SUBNET_NAME"
    } else {
        Write-Success "Using existing subnet: $SUBNET_NAME"
    }
    
    # Get subnet ID
    $SUBNET_ID = az network vnet subnet show --vnet-name "$VNET_NAME" --name "$SUBNET_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv
    
    # Configure VNet integration for Function App
    Write-Info "Configuring VNet integration for Function App..."
    az functionapp vnet-integration add `
        --name "$FUNCTION_APP_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --subnet "$SUBNET_ID" `
        --output none | Out-Null
    Write-Success "VNet integration configured for Function App"
    
    # Configure VNet integration for Web App
    Write-Info "Configuring VNet integration for Web App..."
    az webapp vnet-integration add `
        --name "$WEB_APP_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --subnet "$SUBNET_ID" `
        --output none | Out-Null
    Write-Success "VNet integration configured for Web App"
    
    # Create private endpoint for Function App
    Write-Info "Creating private endpoint for Function App..."
    $funcPeName = "$FUNCTION_APP_NAME-pe"
    $ErrorActionPreference = 'SilentlyContinue'
    $funcPeExists = az network private-endpoint show --name "$funcPeName" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    
    if ($LASTEXITCODE -ne 0) {
        # Get Function App resource ID
        $FUNC_APP_ID = az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv
        
        az network private-endpoint create `
            --name "$funcPeName" `
            --resource-group "$RESOURCE_GROUP" `
            --vnet-name "$VNET_NAME" `
            --subnet "$SUBNET_NAME" `
            --private-connection-resource-id "$FUNC_APP_ID" `
            --group-id "sites" `
            --connection-name "$FUNCTION_APP_NAME-connection" `
            --output none | Out-Null
        Write-Success "Private endpoint created for Function App"
    } else {
        Write-Success "Private endpoint already exists for Function App"
    }
    
    # Create private endpoint for Web App
    Write-Info "Creating private endpoint for Web App..."
    $webPeName = "$WEB_APP_NAME-pe"
    $ErrorActionPreference = 'SilentlyContinue'
    $webPeExists = az network private-endpoint show --name "$webPeName" --resource-group "$RESOURCE_GROUP" 2>&1
    $ErrorActionPreference = 'Stop'
    
    if ($LASTEXITCODE -ne 0) {
        # Get Web App resource ID
        $WEB_APP_ID = az webapp show --name "$WEB_APP_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv
        
        az network private-endpoint create `
            --name "$webPeName" `
            --resource-group "$RESOURCE_GROUP" `
            --vnet-name "$VNET_NAME" `
            --subnet "$SUBNET_NAME" `
            --private-connection-resource-id "$WEB_APP_ID" `
            --group-id "sites" `
            --connection-name "$WEB_APP_NAME-connection" `
            --output none | Out-Null
        Write-Success "Private endpoint created for Web App"
    } else {
        Write-Success "Private endpoint already exists for Web App"
    }
    
    # Link Private DNS Zone to VNet (if DNS zone was created)
    if (-not [string]::IsNullOrWhiteSpace($PRIVATE_DNS_ZONE_NAME) -and $PRIVATE_DNS_CHOICE -ne "skip") {
        Write-Info "Linking Private DNS Zone to VNet..."
        $ErrorActionPreference = 'SilentlyContinue'
        $dnsLinkExists = az network private-dns link vnet show --name "$VNET_NAME-link" --zone-name "$PRIVATE_DNS_ZONE_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
        $ErrorActionPreference = 'Stop'
        
        if ($LASTEXITCODE -ne 0) {
            az network private-dns link vnet create `
                --name "$VNET_NAME-link" `
                --zone-name "$PRIVATE_DNS_ZONE_NAME" `
                --resource-group "$RESOURCE_GROUP" `
                --virtual-network "$VNET_NAME" `
                --registration-enabled false `
                --output none | Out-Null
            Write-Success "Private DNS Zone linked to VNet"
        } else {
            Write-Success "Private DNS Zone already linked to VNet"
        }
    }
    
    Write-Success "Private endpoint configuration complete!"
} else {
    Write-Info "Skipping private endpoint configuration (can be configured later)"
}

Write-Success "Resources setup complete!"
Write-Info "Next: Run deploy-functions.ps1 to deploy backend code"

