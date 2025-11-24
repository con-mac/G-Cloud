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
az account set --subscription $SUBSCRIPTION_ID | Out-Null

# Create Storage Account (for temp files only, if needed)
Write-Info "Creating Storage Account (for temporary files)..."
$STORAGE_ACCOUNT_NAME = ($FUNCTION_APP_NAME -replace '-', '').ToLower().Substring(0, [Math]::Min(24, ($FUNCTION_APP_NAME -replace '-', '').Length)) + "st"
$storageExists = az storage account show --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP 2>&1
if ($LASTEXITCODE -ne 0) {
    az storage account create `
        --name $STORAGE_ACCOUNT_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --sku Standard_LRS `
        --kind StorageV2 `
        --allow-blob-public-access false `
        --min-tls-version TLS1_2 | Out-Null
    Write-Success "Storage Account created: $STORAGE_ACCOUNT_NAME"
} else {
    Write-Warning "Storage Account already exists: $STORAGE_ACCOUNT_NAME"
}

# Create Key Vault
Write-Info "Creating Key Vault..."
$kvExists = az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP 2>&1
if ($LASTEXITCODE -ne 0) {
    az keyvault create `
        --name $KEY_VAULT_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --sku standard `
        --enable-rbac-authorization true | Out-Null
    Write-Success "Key Vault created: $KEY_VAULT_NAME"
} else {
    Write-Warning "Key Vault already exists: $KEY_VAULT_NAME"
}

# Create Function App (Consumption plan for serverless)
Write-Info "Creating Function App for backend API..."
$funcExists = az functionapp show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP 2>&1
if ($LASTEXITCODE -ne 0) {
    # Create storage account for function app (required)
    $FUNC_STORAGE = ($FUNCTION_APP_NAME -replace '-', '').ToLower().Substring(0, [Math]::Min(24, ($FUNCTION_APP_NAME -replace '-', '').Length)) + "func"
    $funcStorageExists = az storage account show --name $FUNC_STORAGE --resource-group $RESOURCE_GROUP 2>&1
    if ($LASTEXITCODE -ne 0) {
        az storage account create `
            --name $FUNC_STORAGE `
            --resource-group $RESOURCE_GROUP `
            --location $LOCATION `
            --sku Standard_LRS | Out-Null
    }
    
    # Create Function App
    az functionapp create `
        --name $FUNCTION_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --consumption-plan-location $LOCATION `
        --runtime python `
        --runtime-version 3.11 `
        --functions-version 4 `
        --storage-account $FUNC_STORAGE `
        --os-type Linux | Out-Null
    
    Write-Warning "NOTE: Private endpoint configuration requires VNet integration"
    Write-Warning "Please configure VNet integration and private endpoints manually or via script"
    
    Write-Success "Function App created: $FUNCTION_APP_NAME"
} else {
    Write-Warning "Function App already exists: $FUNCTION_APP_NAME"
}

# Create Static Web App (or App Service for private hosting)
Write-Info "Creating Static Web App for frontend..."
$webExists = az staticwebapp show --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Static Web Apps have limited private endpoint support"
    Write-Warning "Consider using App Service with private endpoints for full private access"
    
    # Create App Service Plan
    $APP_SERVICE_PLAN = "$WEB_APP_NAME-plan"
    $planExists = az appservice plan show --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP 2>&1
    if ($LASTEXITCODE -ne 0) {
        az appservice plan create `
            --name $APP_SERVICE_PLAN `
            --resource-group $RESOURCE_GROUP `
            --location $LOCATION `
            --sku B1 `
            --is-linux | Out-Null
    }
    
    # Create Web App
    $webAppExists = az webapp show --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP 2>&1
    if ($LASTEXITCODE -ne 0) {
        az webapp create `
            --name $WEB_APP_NAME `
            --resource-group $RESOURCE_GROUP `
            --plan $APP_SERVICE_PLAN `
            --runtime "NODE:18-lts" | Out-Null
        
        Write-Success "Web App created: $WEB_APP_NAME"
    } else {
        Write-Warning "Web App already exists: $WEB_APP_NAME"
    }
} else {
    Write-Warning "Static Web App already exists: $WEB_APP_NAME"
}

# Create Application Insights
Write-Info "Creating Application Insights..."
$APP_INSIGHTS_NAME = "$FUNCTION_APP_NAME-insights"
$aiExists = az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP 2>&1
if ($LASTEXITCODE -ne 0) {
    az monitor app-insights component create `
        --app $APP_INSIGHTS_NAME `
        --location $LOCATION `
        --resource-group $RESOURCE_GROUP `
        --application-type web | Out-Null
    Write-Success "Application Insights created: $APP_INSIGHTS_NAME"
} else {
    Write-Warning "Application Insights already exists: $APP_INSIGHTS_NAME"
}

# Store App Insights connection string
$APP_INSIGHTS_CONNECTION = az monitor app-insights component show `
    --app $APP_INSIGHTS_NAME `
    --resource-group $RESOURCE_GROUP `
    --query connectionString -o tsv

# Save to Key Vault
az keyvault secret set `
    --vault-name $KEY_VAULT_NAME `
    --name "AppInsightsConnectionString" `
    --value $APP_INSIGHTS_CONNECTION `
    --output none | Out-Null

Write-Success "Resources setup complete!"
Write-Info "Next: Configure private endpoints and VNet integration"
Write-Info "Next: Run deploy-functions.ps1 to deploy backend code"

