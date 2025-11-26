# Grant SharePoint Permissions to App Registration
# This script grants your App Registration access to a specific SharePoint site

param(
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$AppId,
    
    [Parameter(Mandatory=$false)]
    [string]$AppDisplayName = "pa-gcloud15-app",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Read", "Write", "FullControl")]
    [string]$PermissionLevel = "Write"
)

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-Error { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Info "Granting SharePoint permissions to App Registration..."

# Check if PnP.PowerShell is installed
$pnpModule = Get-Module -ListAvailable -Name PnP.PowerShell
if (-not $pnpModule) {
    Write-Info "PnP.PowerShell module not found. Installing..."
    try {
        Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
        Write-Success "PnP.PowerShell module installed"
    } catch {
        Write-Error "Failed to install PnP.PowerShell module: $_"
        Write-Info "Trying alternative method with Microsoft Graph PowerShell..."
        
        # Alternative: Use Microsoft Graph PowerShell
        $graphModule = Get-Module -ListAvailable -Name Microsoft.Graph
        if (-not $graphModule) {
            Write-Info "Installing Microsoft.Graph module..."
            Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
        }
        
        Import-Module Microsoft.Graph -Force
        
        Write-Info "Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "Sites.FullControl.All" -NoWelcome
        
        # Get site ID from URL
        Write-Info "Getting site ID from URL: $SiteUrl"
        $siteId = $SiteUrl -replace 'https://', '' -replace 'http://', ''
        $siteId = $siteId -replace '/sites/', ':/sites/'
        
        # Grant permission using Graph API
        Write-Info "Granting $PermissionLevel permission to app $AppId..."
        $params = @{
            roles = @($PermissionLevel.ToLower())
            grantedToIdentities = @(
                @{
                    application = @{
                        id = $AppId
                        displayName = $AppDisplayName
                    }
                }
            )
        }
        
        try {
            $permission = New-MgSitePermission -SiteId $siteId -BodyParameter $params
            Write-Success "Permission granted successfully via Microsoft Graph!"
            Write-Info "Permission ID: $($permission.Id)"
        } catch {
            Write-Error "Failed to grant permission: $_"
            Write-Info "You may need to grant permissions manually in SharePoint"
            exit 1
        }
        
        Disconnect-MgGraph
        exit 0
    }
}

# Import PnP.PowerShell module
Import-Module PnP.PowerShell -Force

# Connect to SharePoint
Write-Info "Connecting to SharePoint site: $SiteUrl"
try {
    Connect-PnPOnline -Url $SiteUrl -Interactive
    Write-Success "Connected to SharePoint"
} catch {
    Write-Error "Failed to connect to SharePoint: $_"
    exit 1
}

# Check if the cmdlet exists (it might have a different name in newer versions)
$cmdletName = "Grant-PnPAzureADAppSitePermission"
$cmdlet = Get-Command -Name $cmdletName -ErrorAction SilentlyContinue

if (-not $cmdlet) {
    # Try alternative cmdlet names
    $alternatives = @(
        "Grant-PnPAzureADAppSitePermission",
        "Add-PnPAzureADAppSitePermission",
        "Set-PnPAzureADAppSitePermission"
    )
    
    $found = $false
    foreach ($alt in $alternatives) {
        $cmdlet = Get-Command -Name $alt -ErrorAction SilentlyContinue
        if ($cmdlet) {
            $cmdletName = $alt
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        Write-Warning "PnP cmdlet not found. Using Microsoft Graph API method instead..."
        
        # Use Graph API via REST
        $token = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to get access token. Please run 'az login' first."
            exit 1
        }
        
        # Get site ID
        $siteId = $SiteUrl -replace 'https://', '' -replace 'http://', ''
        $siteId = $siteId -replace '/sites/', ':/sites/'
        
        # Grant permission
        $body = @{
            roles = @($PermissionLevel.ToLower())
            grantedToIdentities = @(
                @{
                    application = @{
                        id = $AppId
                        displayName = $AppDisplayName
                    }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        Write-Info "Granting $PermissionLevel permission via Graph API..."
        $response = az rest --method POST `
            --uri "https://graph.microsoft.com/v1.0/sites/$siteId/permissions" `
            --headers "Authorization=Bearer $token" "Content-Type=application/json" `
            --body $body 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Permission granted successfully via Graph API!"
        } else {
            Write-Error "Failed to grant permission: $response"
            exit 1
        }
        
        Disconnect-PnPOnline
        exit 0
    }
}

# Use PnP cmdlet
Write-Info "Granting $PermissionLevel permission to app $AppId..."
try {
    & $cmdletName -AppId $AppId -DisplayName $AppDisplayName -Site $SiteUrl -Permissions $PermissionLevel
    Write-Success "Permission granted successfully!"
} catch {
    Write-Error "Failed to grant permission: $_"
    Write-Info "Error details: $($_.Exception.Message)"
    exit 1
}

# Verify permission
Write-Info "Verifying permission..."
try {
    $permissions = Get-PnPAzureADAppSitePermission -AppIdentity $AppId -ErrorAction SilentlyContinue
    if ($permissions) {
        Write-Success "Permission verified. App has access to the site."
        Write-Info "Permission details:"
        $permissions | Format-List
    } else {
        Write-Warning "Could not verify permission, but it may have been granted."
    }
} catch {
    Write-Warning "Could not verify permission: $_"
}

Disconnect-PnPOnline
Write-Success "Script completed successfully!"


