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

$APP_REGISTRATION_NAME = $config.APP_REGISTRATION_NAME
$KEY_VAULT_NAME = $config.KEY_VAULT_NAME
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME
$WEB_APP_NAME = $config.WEB_APP_NAME
$SHAREPOINT_SITE_URL = $config.SHAREPOINT_SITE_URL
$SHAREPOINT_SITE_ID = $config.SHAREPOINT_SITE_ID

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }

Write-Info "Configuring Microsoft 365 SSO authentication..."

# Check if App Registration exists
Write-Info "Checking for App Registration: $APP_REGISTRATION_NAME"
$ErrorActionPreference = 'SilentlyContinue'
$appListJson = az ad app list --display-name $APP_REGISTRATION_NAME --query "[].{AppId:appId, DisplayName:displayName}" -o json 2>&1
$ErrorActionPreference = 'Stop'

$APP_ID = ""
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($appListJson)) {
    try {
        $appList = $appListJson | ConvertFrom-Json
        if ($appList -and $appList.Count -gt 0) {
            $APP_ID = $appList[0].AppId
        }
    } catch {
        Write-Warning "Could not parse App Registration response: $_"
    }
}

# Get Web App URL (needed for redirect URIs and app settings)
$WEB_APP_URL = "https://${WEB_APP_NAME}.azurewebsites.net"

if ([string]::IsNullOrWhiteSpace($APP_ID)) {
    Write-Warning "App Registration not found. Creating..."
    
    # Create App Registration with redirect URIs (production and localhost for development)
    $appJson = az ad app create `
        --display-name $APP_REGISTRATION_NAME `
        --web-redirect-uris "${WEB_APP_URL}/auth/callback" "http://localhost:3000/auth/callback" "http://localhost:5173/auth/callback" | ConvertFrom-Json
    
    $APP_ID = $appJson.appId
    
    Write-Success "App Registration created: $APP_ID"
    
    # Create service principal
    az ad sp create --id $APP_ID --output none | Out-Null
    
    # Add API permissions for SharePoint/Graph
    Write-Info "Adding API permissions for SharePoint/Graph API..."
    
    # Microsoft Graph API ID
    $GRAPH_API_ID = "00000003-0000-0000-c000-000000000000"
    
    # Add User.Read permission
    Write-Info "Adding User.Read permission..."
    az ad app permission add `
        --id $APP_ID `
        --api $GRAPH_API_ID `
        --api-permissions "e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope" `
        --output none 2>&1 | Out-Null
    
    # Add SharePoint permissions - using Application permissions for server-to-server access
    # Reference: https://learn.microsoft.com/en-us/dynamics365/customerengagement/on-premises/admin/on-prem-server-configure-azure-app-with-sharepoint-access
    # For Azure App Service (server-to-server), we need Application permissions, not delegated
    
    # Sites.FullControl.All - Application permission (for full SharePoint site access)
    Write-Info "Adding Sites.FullControl.All permission (Application permission for SharePoint)..."
    az ad app permission add `
        --id $APP_ID `
        --api $GRAPH_API_ID `
        --api-permissions "678536fe-1083-478a-9c59-b99265e6b0d3=Role" `
        --output none 2>&1 | Out-Null
    
    # Sites.ReadWrite.All - Application permission (alternative, more restrictive)
    Write-Info "Adding Sites.ReadWrite.All permission (Application permission)..."
    az ad app permission add `
        --id $APP_ID `
        --api $GRAPH_API_ID `
        --api-permissions "0c0bf378-bf22-4481-978f-6afc4c88705c=Role" `
        --output none 2>&1 | Out-Null
    
    # Files.ReadWrite.All - Application permission (for file operations)
    Write-Info "Adding Files.ReadWrite.All permission (Application permission)..."
    az ad app permission add `
        --id $APP_ID `
        --api $GRAPH_API_ID `
        --api-permissions "75359482-378d-4052-8f01-80520e7db3cd=Role" `
        --output none 2>&1 | Out-Null
    
    # Add offline_access permission
    Write-Info "Adding offline_access permission..."
    az ad app permission add `
        --id $APP_ID `
        --api $GRAPH_API_ID `
        --api-permissions "7427e0e9-2fba-42fe-b0c0-848c9e6a8182=Scope" `
        --output none 2>&1 | Out-Null
    
    # Grant admin consent
    Write-Info "Granting admin consent for API permissions..."
    Write-Info "Note: Application permissions (Role) require admin consent - this is required for SharePoint access"
    $grantConsent = Read-Host "Grant admin consent now? (y/n) [y]"
    if ([string]::IsNullOrWhiteSpace($grantConsent) -or $grantConsent -eq "y") {
        az ad app permission admin-consent --id $APP_ID --output none | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Admin consent granted for all API permissions"
        } else {
            Write-Warning "Could not grant admin consent automatically. This is REQUIRED for SharePoint access."
            Write-Warning "Please grant manually in Azure Portal:"
            Write-Warning "  1. Go to Azure Portal -> App Registrations -> $APP_REGISTRATION_NAME"
            Write-Warning "  2. API permissions -> Grant admin consent for '<tenant name>'"
            Write-Warning "  3. This is required for Sites.FullControl.All and other Application permissions"
        }
    } else {
        Write-Warning "Admin consent not granted. This is REQUIRED for SharePoint Application permissions."
        Write-Warning "Please grant manually in Azure Portal:"
        Write-Warning "  App Registration -> API permissions -> Grant admin consent"
    }
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

# Update Function App settings (build array to avoid PowerShell parsing issues)
Write-Info "Updating Function App with authentication settings..."
$kvUri = "https://${KEY_VAULT_NAME}.vault.azure.net"
# Build Key Vault references using string concatenation to avoid PowerShell expansion issues
$kvTenantRef = '@Microsoft.KeyVault(SecretUri=' + $kvUri + '/secrets/AzureADTenantId/)'
$kvClientIdRef = '@Microsoft.KeyVault(SecretUri=' + $kvUri + '/secrets/AzureADClientId/)'
$kvClientSecretRef = '@Microsoft.KeyVault(SecretUri=' + $kvUri + '/secrets/AzureADClientSecret/)'

$funcAuthSettings = @(
    "AZURE_AD_TENANT_ID=$kvTenantRef",
    "AZURE_AD_CLIENT_ID=$kvClientIdRef",
    "AZURE_AD_CLIENT_SECRET=$kvClientSecretRef"
)

# Set app settings one by one to avoid PowerShell parsing issues
Write-Info "Setting Function App auth settings one by one..."
foreach ($setting in $funcAuthSettings) {
    $ErrorActionPreference = 'SilentlyContinue'
    az functionapp config appsettings set `
        --name "$FUNCTION_APP_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --settings "$setting" `
        --output none 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
}

# Update Web App settings (build array to avoid PowerShell parsing issues)
Write-Info "Updating Web App with authentication settings..."
$webAuthSettings = @(
    "VITE_AZURE_AD_TENANT_ID=$TENANT_ID",
    "VITE_AZURE_AD_CLIENT_ID=$APP_ID",
    "VITE_AZURE_AD_REDIRECT_URI=${WEB_APP_URL}/auth/callback"
)

az webapp config appsettings set `
    --name "$WEB_APP_NAME" `
    --resource-group "$RESOURCE_GROUP" `
    --settings $webAuthSettings `
    --output none | Out-Null

# Configure SharePoint site permissions (if SharePoint is configured)
if (-not [string]::IsNullOrWhiteSpace($SHAREPOINT_SITE_URL) -and -not [string]::IsNullOrWhiteSpace($SHAREPOINT_SITE_ID)) {
    Write-Info "Configuring SharePoint site permissions..."
    $grantSharePoint = Read-Host "Grant App Registration access to SharePoint site? (y/n) [y]"
    if ([string]::IsNullOrWhiteSpace($grantSharePoint) -or $grantSharePoint -eq "y") {
        Write-Info "Attempting to grant SharePoint permissions via Graph API..."
        try {
            $token = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
            $body = @{
                roles = @("write")
                grantedToIdentities = @(@{
                    application = @{
                        id = $APP_ID
                        displayName = $APP_REGISTRATION_NAME
                    }
                })
            } | ConvertTo-Json -Depth 10
            
            az rest --method POST `
                --uri "https://graph.microsoft.com/v1.0/sites/$SHAREPOINT_SITE_ID/permissions" `
                --headers "Authorization=Bearer $token" "Content-Type=application/json" `
                --body $body 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "SharePoint permissions granted via Graph API"
            } else {
                Write-Warning "Could not grant permissions via API. Please grant manually:"
                Write-Info "1. Go to SharePoint site: $SHAREPOINT_SITE_URL"
                Write-Info "2. Settings -> Site permissions -> Grant permissions"
                Write-Info "3. Add App Registration: $APP_REGISTRATION_NAME"
                Write-Info "4. Grant 'Edit' or 'Full Control' permissions"
            }
        } catch {
            Write-Warning "Could not grant SharePoint permissions automatically. Please grant manually:"
            Write-Info "1. Go to SharePoint site: $SHAREPOINT_SITE_URL"
            Write-Info "2. Settings -> Site permissions -> Grant permissions"
            Write-Info "3. Add App Registration: $APP_REGISTRATION_NAME"
        }
    }
}

Write-Success "Authentication configuration complete!"
if ([string]::IsNullOrWhiteSpace($SHAREPOINT_SITE_URL) -or [string]::IsNullOrWhiteSpace($SHAREPOINT_SITE_ID)) {
    Write-Warning "SharePoint not configured. Configure SharePoint site permissions manually if needed."
}

