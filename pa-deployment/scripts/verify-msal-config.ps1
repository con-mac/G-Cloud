# Script to verify MSAL/App Registration configuration for redirect flow

param(
    [string]$AppRegistrationName = "pa-gcloud15-app"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MSAL Configuration Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Load config
$configPath = Join-Path $PSScriptRoot "..\config\deployment-config.env"
if (-not (Test-Path $configPath)) {
    Write-Host "[ERROR] Config file not found: $configPath" -ForegroundColor Red
    Write-Host "Please run deploy.ps1 first" -ForegroundColor Yellow
    exit 1
}

$config = @{}
Get-Content $configPath | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        $config[$matches[1]] = $matches[2]
    }
}

$APP_REGISTRATION_NAME = $config['APP_REGISTRATION_NAME'] ?? $AppRegistrationName
$WEB_APP_URL = $config['WEB_APP_NAME'] ? "https://$($config['WEB_APP_NAME']).azurewebsites.net" : ""

Write-Host "[INFO] Checking App Registration: $APP_REGISTRATION_NAME" -ForegroundColor Blue
Write-Host ""

# Get App Registration
$appJson = az ad app list --display-name $APP_REGISTRATION_NAME --output json 2>&1 | ConvertFrom-Json
if (-not $appJson -or $appJson.Count -eq 0) {
    Write-Host "[ERROR] App Registration not found: $APP_REGISTRATION_NAME" -ForegroundColor Red
    exit 1
}

$APP_ID = $appJson[0].appId
Write-Host "[SUCCESS] App Registration found: $APP_ID" -ForegroundColor Green
Write-Host ""

# Get full app details
Write-Host "[INFO] Fetching App Registration details..." -ForegroundColor Blue
$appDetails = az ad app show --id $APP_ID --output json 2>&1 | ConvertFrom-Json

# Check redirect URIs
Write-Host ""
Write-Host "=== Redirect URIs ===" -ForegroundColor Yellow
$webUris = $appDetails.web.redirectUris
$spaUris = $appDetails.spa.redirectUris

Write-Host "Web Platform Redirect URIs:" -ForegroundColor Cyan
if ($webUris) {
    $webUris | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} else {
    Write-Host "  (none)" -ForegroundColor Red
}

Write-Host ""
Write-Host "SPA Platform Redirect URIs:" -ForegroundColor Cyan
if ($spaUris) {
    $spaUris | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} else {
    Write-Host "  (none) - THIS IS THE PROBLEM!" -ForegroundColor Red
    Write-Host ""
    Write-Host "[CRITICAL] App Registration is NOT configured as SPA platform!" -ForegroundColor Red
    Write-Host "[CRITICAL] This causes MSAL to fall back to popup flow, causing COOP errors" -ForegroundColor Red
    Write-Host ""
    Write-Host "Fix: Run configure-auth.ps1 to configure SPA platform" -ForegroundColor Yellow
    exit 1
}

# Check if base URL is in SPA redirect URIs
if ($WEB_APP_URL) {
    Write-Host ""
    Write-Host "=== Redirect URI Verification ===" -ForegroundColor Yellow
    if ($spaUris -contains $WEB_APP_URL) {
        Write-Host "[SUCCESS] Base URL found in SPA redirect URIs: $WEB_APP_URL" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Base URL NOT found in SPA redirect URIs: $WEB_APP_URL" -ForegroundColor Yellow
        Write-Host "Expected: $WEB_APP_URL" -ForegroundColor Gray
    }
}

# Check API permissions
Write-Host ""
Write-Host "=== API Permissions ===" -ForegroundColor Yellow
$permissions = $appDetails.requiredResourceAccess
if ($permissions) {
    $permissions | ForEach-Object {
        $resourceAppId = $_.resourceAppId
        $resourceName = if ($resourceAppId -eq "00000003-0000-0000-c000-000000000000") { "Microsoft Graph" } else { $resourceAppId }
        Write-Host "Resource: $resourceName" -ForegroundColor Cyan
        $_.resourceAccess | ForEach-Object {
            $permId = $_.id
            $permType = if ($_.type -eq "Role") { "Application" } else { "Delegated" }
            Write-Host "  - $permId ($permType)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  (none)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Yellow
if ($spaUris -and $spaUris.Count -gt 0) {
    Write-Host "[SUCCESS] App Registration is configured as SPA platform" -ForegroundColor Green
    Write-Host "[INFO] Redirect flow should work correctly" -ForegroundColor Green
} else {
    Write-Host "[ERROR] App Registration is NOT configured as SPA platform" -ForegroundColor Red
    Write-Host "[ACTION] Run: .\pa-deployment\scripts\configure-auth.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "[INFO] Configuration looks correct!" -ForegroundColor Green

