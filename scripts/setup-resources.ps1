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

if ([string]::IsNullOrWhiteSpace($STORAGE_ACCOUNT_CHOICE) -or $STORAGE_ACCOUNT_CHOICE -eq "new") {
    Write-Info "Creating Storage Account (for temporary files)..."
    if ([string]::IsNullOrWhiteSpace($STORAGE_ACCOUNT_NAME)) {
        $STORAGE_ACCOUNT_NAME = ($FUNCTION_APP_NAME -replace '-', '').ToLower().Substring(0, [Math]::Min(24, ($FUNCTION_APP_NAME -replace '-', '').Length)) + "st"
    }
    $storageExists = az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
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
$kvExists = az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
if ($LASTEXITCODE -ne 0) {
    az keyvault create `
        --name "$KEY_VAULT_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --location "$LOCATION" `
        --sku standard `
        --enable-rbac-authorization true | Out-Null
    Write-Success "Key Vault created: $KEY_VAULT_NAME"
} else {
    Write-Warning "Key Vault already exists: $KEY_VAULT_NAME"
}

# Create or update Function App (Consumption plan for serverless)
Write-Info "Setting up Function App for backend API..."
$funcExists = az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
if ($LASTEXITCODE -ne 0) {
    # Create storage account for function app (required)
    $FUNC_STORAGE = ($FUNCTION_APP_NAME -replace '-', '').ToLower().Substring(0, [Math]::Min(24, ($FUNCTION_APP_NAME -replace '-', '').Length)) + "func"
    $funcStorageExists = az storage account show --name "$FUNC_STORAGE" --resource-group "$RESOURCE_GROUP" 2>&1
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
$webAppExists = az webapp show --name "$WEB_APP_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Static Web Apps have limited private endpoint support"
    Write-Warning "Consider using App Service with private endpoints for full private access"
    
    # Create App Service Plan
    $APP_SERVICE_PLAN = "$WEB_APP_NAME-plan"
    $planExists = az appservice plan show --name "$APP_SERVICE_PLAN" --resource-group "$RESOURCE_GROUP" 2>&1
    if ($LASTEXITCODE -ne 0) {
        az appservice plan create `
            --name "$APP_SERVICE_PLAN" `
            --resource-group "$RESOURCE_GROUP" `
            --location "$LOCATION" `
            --sku B1 `
            --is-linux | Out-Null
    }
    
    # Create Web App
    az webapp create `
        --name "$WEB_APP_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --plan "$APP_SERVICE_PLAN" `
        --runtime "NODE:18-lts" | Out-Null
    
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
    $aiExists = az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
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
        $aiExists = az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
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
    $APP_INSIGHTS_CONNECTION = az monitor app-insights component show `
        --app "$APP_INSIGHTS_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --query connectionString -o tsv
    
    # Save to Key Vault
    az keyvault secret set `
        --vault-name "$KEY_VAULT_NAME" `
        --name "AppInsightsConnectionString" `
        --value "$APP_INSIGHTS_CONNECTION" `
        --output none | Out-Null
}

# Handle Private DNS Zone
$PRIVATE_DNS_CHOICE = $config.PRIVATE_DNS_CHOICE
$PRIVATE_DNS_ZONE_NAME = $config.PRIVATE_DNS_ZONE_NAME

if ([string]::IsNullOrWhiteSpace($PRIVATE_DNS_CHOICE) -or $PRIVATE_DNS_CHOICE -eq "new") {
    Write-Info "Creating Private DNS Zone..."
    if ([string]::IsNullOrWhiteSpace($PRIVATE_DNS_ZONE_NAME)) {
        $PRIVATE_DNS_ZONE_NAME = "privatelink.azurewebsites.net"
    }
    $dnsExists = az network private-dns zone show --name "$PRIVATE_DNS_ZONE_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
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
        $dnsExists = az network private-dns zone show --name "$PRIVATE_DNS_ZONE_NAME" --resource-group "$RESOURCE_GROUP" 2>&1
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

Write-Success "Resources setup complete!"
Write-Info "Next: Configure private endpoints and VNet integration"
Write-Info "Next: Run deploy-functions.ps1 to deploy backend code"

