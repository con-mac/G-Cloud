# Deploy Frontend Script (PowerShell)
# Deploys React frontend to Azure App Service using Oryx build (no local Node.js required)

$ErrorActionPreference = "Stop"

# Load configuration
if (-not (Test-Path "config\deployment-config.env")) {
    Write-Error "deployment-config.env not found. Please run deploy.ps1 first."
    exit 1
}

# Parse environment file
$config = @{}
$configPath = "config\deployment-config.env"

if (-not (Test-Path $configPath)) {
    Write-Error "Config file not found: $configPath"
    exit 1
}

# Read file line by line (more reliable than Raw)
$fileLines = Get-Content $configPath -Encoding UTF8
foreach ($line in $fileLines) {
    $line = $line.Trim()
    if ($line -and -not $line.StartsWith('#')) {
        # Find first = sign and split on it
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

$WEB_APP_NAME = $config.WEB_APP_NAME
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-Error { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Info "Deploying frontend to Web App using Azure Oryx build (no local Node.js required)..."

# Validate configuration
if ([string]::IsNullOrWhiteSpace($FUNCTION_APP_NAME)) {
    Write-Error "FUNCTION_APP_NAME is missing or empty in config file!"
    Write-Info "Please check config\deployment-config.env"
    Write-Info "Expected format: FUNCTION_APP_NAME=pa-gcloud15-api"
    Write-Info ""
    Write-Info "Current config values:"
    Write-Info "  FUNCTION_APP_NAME: '$FUNCTION_APP_NAME'"
    Write-Info "  WEB_APP_NAME: '$WEB_APP_NAME'"
    Write-Info "  RESOURCE_GROUP: '$RESOURCE_GROUP'"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($WEB_APP_NAME)) {
    Write-Error "WEB_APP_NAME is missing or empty in config file!"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
    Write-Error "RESOURCE_GROUP is missing or empty in config file!"
    exit 1
}

# Debug output - show raw values
Write-Info "Configuration loaded:"
Write-Info "  Function App: '$FUNCTION_APP_NAME' (length: $($FUNCTION_APP_NAME.Length))"
Write-Info "  Web App: '$WEB_APP_NAME' (length: $($WEB_APP_NAME.Length))"
Write-Info "  Resource Group: '$RESOURCE_GROUP' (length: $($RESOURCE_GROUP.Length))"

# Show all config keys for debugging
Write-Info "All config keys found: $($config.Keys -join ', ')"

# Check if frontend directory exists
if (-not (Test-Path "frontend")) {
    Write-Error "Frontend directory not found!"
    exit 1
}

Push-Location frontend

# Verify essential files exist
Write-Info "Verifying frontend files..."

if (-not (Test-Path "package.json")) {
    Write-Error "package.json not found. Frontend source files are missing."
    Pop-Location
    exit 1
}

if (-not (Test-Path "src") -or -not (Test-Path "src\main.tsx")) {
    Write-Error "Frontend src folder or main.tsx not found. Please ensure frontend/src/ directory exists with your React source files."
    Pop-Location
    exit 1
}

Write-Success "Frontend files verified"

# Get Function App URL for API configuration
Write-Info "Getting Function App URL for: $FUNCTION_APP_NAME..."
$ErrorActionPreference = 'SilentlyContinue'
$FUNCTION_APP_URL = az functionapp show `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --query defaultHostName -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($FUNCTION_APP_URL)) {
    Write-Error "Could not get Function App URL"
    Write-Info "Function App name: '$FUNCTION_APP_NAME'"
    Write-Info "Resource Group: '$RESOURCE_GROUP'"
    Write-Info ""
    Write-Info "Please verify:"
    Write-Info "  1. Function App exists: az functionapp list --resource-group $RESOURCE_GROUP"
    Write-Info "  2. Config file has correct name: Get-Content config\deployment-config.env"
    Pop-Location
    exit 1
}

Write-Success "Function App URL: https://$FUNCTION_APP_URL"

# Create .env.production with API URL
Write-Info "Creating production environment file..."
$envContent = @"
VITE_API_BASE_URL=https://${FUNCTION_APP_URL}/api/v1
VITE_AZURE_AD_TENANT_ID=PLACEHOLDER_TENANT_ID
VITE_AZURE_AD_CLIENT_ID=PLACEHOLDER_CLIENT_ID
VITE_AZURE_AD_REDIRECT_URI=https://${WEB_APP_NAME}.azurewebsites.net
"@

$envContent | Out-File -FilePath ".env.production" -Encoding utf8
Write-Success "Environment file created"

# Configure App Service for static site hosting
Write-Info "Configuring App Service for static site hosting..."

# Set app settings for Oryx build
$appSettings = @(
    "SCM_DO_BUILD_DURING_DEPLOYMENT=true",
    "ENABLE_ORYX_BUILD=true",
    "WEBSITE_RUN_FROM_PACKAGE=0",
    "WEBSITE_NODE_DEFAULT_VERSION=~20",
    "POST_BUILD_COMMAND=if [ -d dist ]; then cp -r dist/* /home/site/wwwroot/ 2>/dev/null || true; fi",
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE=false"
)

az webapp config appsettings set `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --settings $appSettings `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to configure App Service settings"
    Pop-Location
    exit 1
}

# For static sites, no startup command needed - Azure serves wwwroot automatically
# Don't set startup-file for static sites (it causes errors with empty string)
Write-Info "Static site configured - Azure will serve files from wwwroot automatically"

# Create .deployment file for Oryx
Write-Info "Creating deployment configuration..."
$deploymentConfig = @"
[config]
SCM_SCRIPT_GENERATOR_ARGS=--node
"@

$deploymentConfig | Out-File -FilePath ".deployment" -Encoding utf8

# Deploy using Oryx build
Write-Info "Deploying source code to App Service..."
Write-Info "Azure Oryx will build your app automatically (this may take 5-10 minutes)..."

# Create a zip of the frontend source (exclude node_modules and dist, Oryx will build)
Write-Info "Creating deployment package..."
$tempZip = "..\frontend-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"

# Get all files except node_modules, dist, and .git
$filesToZip = Get-ChildItem -Path . -Recurse -File | 
    Where-Object { 
        $_.FullName -notmatch "\\node_modules\\" -and 
        $_.FullName -notmatch "\\dist\\" -and
        $_.FullName -notmatch "\\.git\\" 
    }

if ($filesToZip.Count -eq 0) {
    Write-Error "No source files found to deploy"
    Pop-Location
    exit 1
}

$filesToZip | Compress-Archive -DestinationPath $tempZip -Force

Write-Info "Deploying to App Service..."
Write-Info "Oryx will:"
Write-Info "  1. Install dependencies (npm install)"
Write-Info "  2. Build the app (npm run build)"
Write-Info "  3. Copy dist/* to wwwroot for serving"

az webapp deployment source config-zip `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME `
    --src $tempZip `
    --timeout 1800

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed. Check the error above."
    Write-Info "You can check build logs at: https://$WEB_APP_NAME.scm.azurewebsites.net/logstream"
    Pop-Location
    exit 1
}

# Wait a moment for deployment to start
Start-Sleep -Seconds 3

# Check deployment status
Write-Info "Checking deployment status..."
$deployments = az webapp deployment list `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --query "[0].{Status:status, Message:message}" `
    -o json 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Success "Deployment initiated"
} else {
    Write-Warning "Could not check deployment status, but deployment should be in progress"
}

Write-Success "Frontend deployment initiated!"
Write-Info ""
Write-Info "Next steps:"
Write-Info "  1. Azure is now building your app using Oryx (no local Node.js needed!)"
Write-Info "  2. This typically takes 5-10 minutes"
Write-Info "  3. Monitor progress at: https://$WEB_APP_NAME.scm.azurewebsites.net"
Write-Info "  4. Your app will be available at: https://$WEB_APP_NAME.azurewebsites.net"
Write-Info ""
Write-Info "Note: Azure AD configuration needs to be updated with actual values"
Write-Info "Note: Private endpoint configuration may be required"

# Cleanup
if (Test-Path $tempZip) {
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
}

Pop-Location
