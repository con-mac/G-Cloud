# Deploy Functions Script (PowerShell)
# Deploys backend API code to Azure Function App

$ErrorActionPreference = "Stop"

# Load configuration
if (-not (Test-Path "config\deployment-config.env")) {
    Write-Error "deployment-config.env not found. Please run deploy.ps1 first."
    exit 1
}

# Parse environment file
$config = @{}
$configPath = "config\deployment-config.env"
$fileLines = Get-Content $configPath -Encoding UTF8
foreach ($line in $fileLines) {
    $line = $line.Trim()
    if ($line -and -not $line.StartsWith('#')) {
        $equalsIndex = $line.IndexOf('=')
        if ($equalsIndex -gt 0) {
            $key = $line.Substring(0, $equalsIndex).Trim()
            $value = $line.Substring($equalsIndex + 1).Trim()
            if ($key -and $value) {
                $config[$key] = $value
            }
        }
    }
}

$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$KEY_VAULT_NAME = $config.KEY_VAULT_NAME
$SHAREPOINT_SITE_URL = $config.SHAREPOINT_SITE_URL
$SHAREPOINT_SITE_ID = $config.SHAREPOINT_SITE_ID

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

Write-Info "Deploying backend API to Function App..."

# Check if backend directory exists
if (-not (Test-Path "backend")) {
    Write-Warning "Backend directory not found. Creating structure..."
    New-Item -ItemType Directory -Path "backend" | Out-Null
}

# Create deployment package
Write-Info "Creating deployment package..."
Push-Location backend

# Create requirements.txt if it doesn't exist
if (-not (Test-Path "requirements.txt")) {
    Write-Warning "requirements.txt not found. Creating from template..."
    @"
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
azure-functions>=1.18.0
azure-identity>=1.15.0
azure-keyvault-secrets>=4.7.0
python-docx>=1.1.0
openpyxl>=3.1.0
pydantic>=2.5.0
pydantic-settings>=2.1.0
# SharePoint/Graph API dependencies
msgraph-sdk>=1.0.0
# Placeholder: Add other dependencies as needed
"@ | Out-File -FilePath "requirements.txt" -Encoding utf8
}

# Deploy to Function App
Write-Info "Deploying to Function App: $FUNCTION_APP_NAME"
try {
    $funcCheck = Get-Command func -ErrorAction SilentlyContinue
    if ($funcCheck) {
        func azure functionapp publish $FUNCTION_APP_NAME --python
    } else {
        Write-Warning "Azure Functions Core Tools not found. Skipping code deployment."
        Write-Warning "Install with: npm install -g azure-functions-core-tools@4"
        Write-Info "Function App exists and will be configured, but code deployment skipped."
    }
} catch {
    Write-Warning "Code deployment failed or skipped. Function App will be configured with settings."
}

# Configure app settings (updates existing or creates new)
Write-Info "Configuring Function App settings..."

# Get Key Vault reference
$KEY_VAULT_URI = az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query properties.vaultUri -o tsv

# Build settings array to avoid PowerShell parsing issues with @ symbols
# Use single quotes for Key Vault references to prevent PowerShell expansion
$kvStorageRef = '@Microsoft.KeyVault(SecretUri=' + $KEY_VAULT_URI + '/secrets/StorageConnectionString/)'
$kvAppInsightsRef = '@Microsoft.KeyVault(SecretUri=' + $KEY_VAULT_URI + '/secrets/AppInsightsConnectionString/)'

$appSettings = @(
    "AZURE_KEY_VAULT_URL=$KEY_VAULT_URI",
    "SHAREPOINT_SITE_URL=$SHAREPOINT_SITE_URL",
    "SHAREPOINT_SITE_ID=$SHAREPOINT_SITE_ID",
    "USE_SHAREPOINT=true",
    "AZURE_STORAGE_CONNECTION_STRING=$kvStorageRef",
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$kvAppInsightsRef"
)

# Set app settings - pass as array to Azure CLI
az functionapp config appsettings set `
    --name "$FUNCTION_APP_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --settings $appSettings `
    --output none | Out-Null

Write-Success "Backend deployment complete!"
Write-Info "Note: SharePoint credentials need to be added to Key Vault"
Write-Info "Note: App Registration credentials need to be configured"

Pop-Location

