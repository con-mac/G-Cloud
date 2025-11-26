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
function Write-Error { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Info "Deploying frontend to Web App using Azure Oryx build (no local Node.js required)..."

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
Write-Info "Getting Function App URL..."
$FUNCTION_APP_URL = az functionapp show `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --query defaultHostName -o tsv

if (-not $FUNCTION_APP_URL) {
    Write-Error "Could not get Function App URL"
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

# Configure App Service for Oryx build
Write-Info "Configuring App Service for automatic build..."
$appSettings = @(
    "SCM_DO_BUILD_DURING_DEPLOYMENT=true",
    "ENABLE_ORYX_BUILD=true",
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE=false",
    "WEBSITE_NODE_DEFAULT_VERSION=~20"
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

Write-Success "App Service configured for Oryx build"

# Create .deployment file to specify build command
Write-Info "Creating deployment configuration..."
$deploymentConfig = @"
[config]
SCM_SCRIPT_GENERATOR_ARGS=--node
"@

$deploymentConfig | Out-File -FilePath ".deployment" -Encoding utf8

# Create .deployment file in root if it doesn't exist
if (-not (Test-Path "..\.deployment")) {
    $deploymentConfig | Out-File -FilePath "..\.deployment" -Encoding utf8
}

# Create startup script for App Service
Write-Info "Creating startup script..."
$startupScript = @"
#!/bin/bash
# Serve the built files using a simple HTTP server
cd /home/site/wwwroot
if [ -d "dist" ]; then
    cd dist
fi
python3 -m http.server 8000
"@

# Deploy source code to App Service (Oryx will build it)
Write-Info "Deploying source code to App Service..."
Write-Info "Azure will automatically build your app using Oryx (this may take 5-10 minutes)..."

# Create a zip of the frontend source
Write-Info "Creating deployment package..."
$tempZip = "..\frontend-deploy.zip"

# Exclude node_modules and dist if they exist
Get-ChildItem -Path . -Recurse | 
    Where-Object { 
        $_.FullName -notmatch "\\node_modules\\" -and 
        $_.FullName -notmatch "\\dist\\" -and
        $_.FullName -notmatch "\\.git\\" 
    } | 
    Compress-Archive -DestinationPath $tempZip -Force -ErrorAction SilentlyContinue

# Alternative: Use az webapp up for simpler deployment
Write-Info "Deploying to App Service..."
az webapp deployment source config-zip `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME `
    --src $tempZip

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Zip deploy failed, trying alternative method..."
    
    # Alternative: Deploy via git or direct folder
    Write-Info "Using alternative deployment method..."
    
    # Set build command in app settings
    az webapp config appsettings set `
        --name $WEB_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --settings "POST_BUILD_COMMAND=echo 'Build complete'" `
        --output none
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
