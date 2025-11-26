# Simple frontend deployment that actually works
# This builds locally and deploys the dist folder

param(
    [string]$BuildLocally = "true"
)

# Load config
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

$WEB_APP_NAME = $config.WEB_APP_NAME
$RESOURCE_GROUP = $config.RESOURCE_GROUP
$FUNCTION_APP_NAME = $config.FUNCTION_APP_NAME

if ([string]::IsNullOrWhiteSpace($WEB_APP_NAME) -or [string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
    Write-Host "[ERROR] Missing required config values" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Deploying frontend to: $WEB_APP_NAME" -ForegroundColor Blue

Push-Location frontend

# Check if dist exists, if not, build it
if (-not (Test-Path "dist") -or $BuildLocally -eq "true") {
    Write-Host "[INFO] Building frontend..." -ForegroundColor Blue
    
    # Check if Node.js is available
    $nodeAvailable = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeAvailable) {
        Write-Host "[ERROR] Node.js not found. Please install Node.js or use Azure Oryx build." -ForegroundColor Red
        Write-Host "[INFO] You can install Node.js from: https://nodejs.org/" -ForegroundColor Yellow
        Write-Host "[INFO] Or use the Oryx build method: .\scripts\deploy-frontend.ps1" -ForegroundColor Yellow
        Pop-Location
        exit 1
    }
    
    # Install dependencies
    Write-Host "[INFO] Installing dependencies..." -ForegroundColor Blue
    npm install
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] npm install failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    
    # Build
    Write-Host "[INFO] Building production bundle..." -ForegroundColor Blue
    npm run build
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Build failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }
}

if (-not (Test-Path "dist")) {
    Write-Host "[ERROR] dist folder not found after build" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "[SUCCESS] Build complete" -ForegroundColor Green

# Get Function App URL
Write-Host "[INFO] Getting Function App URL..." -ForegroundColor Blue
$ErrorActionPreference = 'SilentlyContinue'
$FUNCTION_APP_URL = az functionapp show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP --query defaultHostName -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($FUNCTION_APP_URL)) {
    Write-Host "[WARNING] Could not get Function App URL, using placeholder" -ForegroundColor Yellow
    $FUNCTION_APP_URL = "$FUNCTION_APP_NAME.azurewebsites.net"
}

# Configure Web App for static site
Write-Host "[INFO] Configuring Web App for static site..." -ForegroundColor Blue
az webapp config set `
    --name $WEB_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --startup-file "" `
    --output none

# Deploy dist folder
Write-Host "[INFO] Deploying dist folder to Web App..." -ForegroundColor Blue
$tempZip = "..\dist-deploy.zip"

# Create zip of dist folder
Compress-Archive -Path "dist\*" -DestinationPath $tempZip -Force

# Deploy
az webapp deployment source config-zip `
    --resource-group $RESOURCE_GROUP `
    --name $WEB_APP_NAME `
    --src $tempZip `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Frontend deployed successfully!" -ForegroundColor Green
    Write-Host "[INFO] Your app should be available at: https://$WEB_APP_NAME.azurewebsites.net" -ForegroundColor Blue
    Write-Host "[INFO] It may take 1-2 minutes for changes to appear" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Deployment failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Cleanup
if (Test-Path $tempZip) {
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
}

Pop-Location

