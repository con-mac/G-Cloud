# Deploy Frontend Script (PowerShell)
# Deploys React frontend to Static Web App or App Service

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

$WEB_APP_NAME = $config.WEB_APP_NAME
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

Write-Info "Deploying frontend to Web App..."

# Check if frontend directory exists
if (-not (Test-Path "frontend")) {
    Write-Warning "Frontend directory not found. Creating structure..."
    New-Item -ItemType Directory -Path "frontend" | Out-Null
}

Push-Location frontend

# Build frontend
Write-Info "Building frontend..."
if (-not (Test-Path "package.json")) {
    Write-Warning "package.json not found. Frontend may need to be copied from main repo."
    Pop-Location
    exit 1
}

npm install
npm run build

# Get Function App URL for API configuration
$FUNCTION_APP_URL = az functionapp show `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --query defaultHostName -o tsv

# Create .env.production with API URL
# Note: For private endpoints, this will be the private DNS name
$envContent = @"
VITE_API_BASE_URL=https://${FUNCTION_APP_URL}/api/v1
VITE_AZURE_AD_TENANT_ID=PLACEHOLDER_TENANT_ID
VITE_AZURE_AD_CLIENT_ID=PLACEHOLDER_CLIENT_ID
VITE_AZURE_AD_REDIRECT_URI=https://${WEB_APP_NAME}.azurewebsites.net
"@

$envContent | Out-File -FilePath ".env.production" -Encoding utf8

# Rebuild with production env
npm run build

# Deploy to App Service
Write-Info "Deploying to Web App: $WEB_APP_NAME"

# Create deployment package
Push-Location dist
Compress-Archive -Path * -DestinationPath ..\deployment.zip -Force
Pop-Location

# Deploy using zip deploy
az webapp deployment source config-zip `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME `
    --src deployment.zip | Out-Null

# Configure app settings
Write-Info "Configuring Web App settings..."

az webapp config appsettings set `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --settings `
        "WEBSITES_ENABLE_APP_SERVICE_STORAGE=false" `
        "SCM_DO_BUILD_DURING_DEPLOYMENT=false" `
    --output none | Out-Null

Write-Success "Frontend deployment complete!"
Write-Info "Note: Azure AD configuration needs to be updated with actual values"
Write-Info "Note: Private endpoint configuration may be required"

Pop-Location

