# Configure Authentication Script (PowerShell)
# Sets up Microsoft 365 SSO integration

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

$APP_REGISTRATION_NAME = $config.APP_REGISTRATION_NAME
$KEY_VAULT_NAME = $config.KEY_VAULT_NAME
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME
$WEB_APP_NAME = $config.WEB_APP_NAME

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

Write-Info "Configuring Microsoft 365 SSO authentication..."

# Check if App Registration exists
Write-Info "Checking for App Registration: $APP_REGISTRATION_NAME"
$appList = az ad app list --display-name $APP_REGISTRATION_NAME | ConvertFrom-Json
$APP_ID = $appList | Select-Object -First 1 -ExpandProperty appId

if ([string]::IsNullOrWhiteSpace($APP_ID)) {
    Write-Warning "App Registration not found. Creating..."
    
    # Get Web App URL
    $WEB_APP_URL = "https://${WEB_APP_NAME}.azurewebsites.net"
    
    # Create App Registration
    $appJson = az ad app create `
        --display-name $APP_REGISTRATION_NAME `
        --web-redirect-uris "${WEB_APP_URL}/auth/callback" | ConvertFrom-Json
    
    $APP_ID = $appJson.appId
    
    Write-Success "App Registration created: $APP_ID"
    
    # Create service principal
    az ad sp create --id $APP_ID --output none | Out-Null
    
    # Add API permissions for SharePoint/Graph
    Write-Info "Adding API permissions..."
    Write-Warning "NOTE: The following permissions need to be added manually in Azure Portal:"
    Write-Warning "  - Microsoft Graph: User.Read"
    Write-Warning "  - Microsoft Graph: Files.ReadWrite.All (or Sites.ReadWrite.All)"
    Write-Warning "  - Microsoft Graph: offline_access"
    Write-Warning "Admin consent will be required for these permissions"
} else {
    Write-Success "App Registration found: $APP_ID"
}

# Create client secret
Write-Info "Creating client secret..."
$secretJson = az ad app credential reset --id $APP_ID | ConvertFrom-Json
$SECRET = $secretJson.password

# Store in Key Vault
az keyvault secret set `
    --vault-name $KEY_VAULT_NAME `
    --name "AzureADClientId" `
    --value $APP_ID `
    --output none | Out-Null

az keyvault secret set `
    --vault-name $KEY_VAULT_NAME `
    --name "AzureADClientSecret" `
    --value $SECRET `
    --output none | Out-Null

# Get tenant ID
$account = az account show | ConvertFrom-Json
$TENANT_ID = $account.tenantId

az keyvault secret set `
    --vault-name $KEY_VAULT_NAME `
    --name "AzureADTenantId" `
    --value $TENANT_ID `
    --output none | Out-Null

# Update Function App settings
Write-Info "Updating Function App with authentication settings..."
az functionapp config appsettings set `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --settings `
        "AZURE_AD_TENANT_ID=@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/AzureADTenantId/)" `
        "AZURE_AD_CLIENT_ID=@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/AzureADClientId/)" `
        "AZURE_AD_CLIENT_SECRET=@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/AzureADClientSecret/)" `
    --output none | Out-Null

# Update Web App settings
Write-Info "Updating Web App with authentication settings..."
az webapp config appsettings set `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --settings `
        "VITE_AZURE_AD_TENANT_ID=$TENANT_ID" `
        "VITE_AZURE_AD_CLIENT_ID=$APP_ID" `
        "VITE_AZURE_AD_REDIRECT_URI=${WEB_APP_URL}/auth/callback" `
    --output none | Out-Null

Write-Success "Authentication configuration complete!"
Write-Warning "IMPORTANT: Grant admin consent for API permissions in Azure Portal"
Write-Warning "IMPORTANT: Configure SharePoint site permissions for the App Registration"

