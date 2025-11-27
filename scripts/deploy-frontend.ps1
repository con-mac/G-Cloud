# Deploy Frontend Script (PowerShell)
# Deploys React frontend to Azure App Service using Docker container from ACR

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
$ACR_NAME = $config.ACR_NAME
$IMAGE_TAG = $config.IMAGE_TAG

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-Error { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Info "Deploying frontend to Web App using Docker container from ACR..."

# Validate configuration
if ([string]::IsNullOrWhiteSpace($FUNCTION_APP_NAME)) {
    Write-Error "FUNCTION_APP_NAME is missing or empty in config file!"
    Write-Info "Please check config\deployment-config.env"
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

if ([string]::IsNullOrWhiteSpace($ACR_NAME)) {
    Write-Error "ACR_NAME is missing in config file!"
    Write-Info "Please run deploy.ps1 and configure Container Registry"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($IMAGE_TAG)) {
    $IMAGE_TAG = "latest"
    Write-Warning "IMAGE_TAG not specified, using 'latest'"
}

# Debug output
Write-Info "Configuration loaded:"
Write-Info "  Function App: '$FUNCTION_APP_NAME'"
Write-Info "  Web App: '$WEB_APP_NAME'"
Write-Info "  Resource Group: '$RESOURCE_GROUP'"
Write-Info "  ACR: '$ACR_NAME'"
Write-Info "  Image Tag: '$IMAGE_TAG'"

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
    exit 1
}

Write-Success "Function App URL: https://$FUNCTION_APP_URL"

# Verify ACR exists
Write-Info "Verifying Azure Container Registry: $ACR_NAME..."
$ErrorActionPreference = 'SilentlyContinue'
$acrExists = az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query "name" -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($acrExists)) {
    Write-Error "Azure Container Registry '$ACR_NAME' not found in resource group '$RESOURCE_GROUP'"
    Write-Info "Please ensure:"
    Write-Info "  1. ACR exists: az acr list --resource-group $RESOURCE_GROUP"
    Write-Info "  2. Images are built and pushed: .\scripts\build-and-push-images.ps1"
    exit 1
}

Write-Success "ACR verified: $ACR_NAME"

# Check if frontend image exists in ACR
Write-Info "Checking if frontend image exists in ACR..."
$ErrorActionPreference = 'SilentlyContinue'
$imageExists = az acr repository show-tags --name "$ACR_NAME" --repository "frontend" --query "[?name=='$IMAGE_TAG'].name" -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($imageExists)) {
    Write-Warning "Frontend image 'frontend:$IMAGE_TAG' not found in ACR '$ACR_NAME'"
    Write-Info "Please build and push the image first:"
    Write-Info "  .\scripts\build-and-push-images.ps1"
    Write-Info ""
    Write-Info "Or verify the image tag is correct. Available tags:"
    $ErrorActionPreference = 'SilentlyContinue'
    az acr repository show-tags --name "$ACR_NAME" --repository "frontend" --output table 2>&1
    $ErrorActionPreference = 'Stop'
    exit 1
}

Write-Success "Frontend image found: frontend:$IMAGE_TAG"

# Get ACR credentials
Write-Info "Getting ACR credentials..."
$ErrorActionPreference = 'SilentlyContinue'
$acrUsername = az acr credential show --name "$ACR_NAME" --query "username" -o tsv 2>&1
$acrPassword = az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($acrUsername) -or [string]::IsNullOrWhiteSpace($acrPassword)) {
    Write-Error "Failed to get ACR credentials"
    Write-Info "Please ensure ACR admin user is enabled:"
    Write-Info "  az acr update --name $ACR_NAME --admin-enabled true"
    exit 1
}

Write-Success "ACR credentials retrieved"

# Configure Web App to use Docker container
Write-Info "Configuring Web App to use Docker container..."
$acrLoginServer = "$ACR_NAME.azurecr.io"
$dockerImage = "$acrLoginServer/frontend:$IMAGE_TAG"

Write-Info "Setting container configuration..."
Write-Info "  Image: $dockerImage"
Write-Info "  Registry: $acrLoginServer"

az webapp config container set `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --docker-custom-image-name $dockerImage `
    --docker-registry-server-url "https://$acrLoginServer" `
    --docker-registry-server-user $acrUsername `
    --docker-registry-server-password $acrPassword `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to configure Web App container"
    exit 1
}

Write-Success "Web App configured to use Docker container"

# Set app settings for API URL and other configuration
Write-Info "Configuring app settings..."
$appSettings = @(
    "VITE_API_BASE_URL=https://${FUNCTION_APP_URL}/api/v1",
    "VITE_AZURE_AD_TENANT_ID=PLACEHOLDER_TENANT_ID",
    "VITE_AZURE_AD_CLIENT_ID=PLACEHOLDER_CLIENT_ID",
    "VITE_AZURE_AD_REDIRECT_URI=https://${WEB_APP_NAME}.azurewebsites.net",
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE=false",
    "PORT=80"
)

# Set app settings one by one to avoid parsing issues
foreach ($setting in $appSettings) {
    $ErrorActionPreference = 'SilentlyContinue'
    $result = az webapp config appsettings set `
        --name $WEB_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --settings "$setting" `
        --output none 2>&1
    $ErrorActionPreference = 'Stop'
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to set: $setting"
    }
}

Write-Success "App settings configured"

# Restart the app to apply container changes
Write-Info "Restarting Web App to apply container configuration..."
az webapp restart `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to restart Web App, but configuration should still apply"
} else {
    Write-Success "Web App restarted"
}

Write-Success "Frontend deployment complete!"
Write-Info ""
Write-Info "Next steps:"
Write-Info "  1. Wait 30-60 seconds for the container to start"
Write-Info "  2. Check the app: https://$WEB_APP_NAME.azurewebsites.net"
Write-Info "  3. Check logs: az webapp log tail --name $WEB_APP_NAME --resource-group $RESOURCE_GROUP"
Write-Info ""
Write-Info "Note: Azure AD configuration needs to be updated with actual values"
Write-Info "Note: Private endpoint configuration may be required"
