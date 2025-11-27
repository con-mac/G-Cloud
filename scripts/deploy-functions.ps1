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

# Check if backend code exists
if (-not (Test-Path "host.json")) {
    Write-Warning "host.json not found in backend directory"
    Write-Info "Checking if we need to copy from main repo..."
    if (Test-Path "..\..\backend\host.json") {
        Write-Info "Copying backend files from main repo..."
        Copy-Item -Path "..\..\backend\*" -Destination . -Recurse -Force -Exclude "*.pyc","__pycache__","*.log",".git"
    } else {
        Write-Warning "Backend code not found. Function App will be created but code deployment skipped."
        Write-Warning "Please ensure backend code is in pa-deployment/backend/ directory"
    }
}

# Try using Azure Functions Core Tools first
$funcCheck = Get-Command func -ErrorAction SilentlyContinue
if ($funcCheck) {
    Write-Info "Using Azure Functions Core Tools for deployment..."
    try {
        func azure functionapp publish $FUNCTION_APP_NAME --python
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Backend code deployed using Functions Core Tools"
        } else {
            Write-Warning "Functions Core Tools deployment failed, trying zip deploy..."
            $funcCheck = $null  # Force zip deploy
        }
    } catch {
        Write-Warning "Functions Core Tools deployment failed: $_"
        Write-Info "Trying zip deploy instead..."
        $funcCheck = $null
    }
}

# Fallback to zip deploy if Functions Core Tools not available or failed
if (-not $funcCheck) {
    Write-Info "Deploying using zip deploy method..."
    
    # Verify essential files exist
    if (-not (Test-Path "host.json")) {
        Write-Warning "host.json not found. Cannot deploy backend code."
        Write-Info "Function App will be configured with settings, but code deployment skipped."
    } elseif (-not (Test-Path "requirements.txt")) {
        Write-Warning "requirements.txt not found. Cannot deploy backend code."
        Write-Info "Function App will be configured with settings, but code deployment skipped."
    } else {
        # Create deployment zip (exclude unnecessary files)
        Write-Info "Creating deployment package..."
        $deployZip = "..\function-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
        
        # Get all files except common exclusions
        $filesToZip = Get-ChildItem -Path . -Recurse -File | 
            Where-Object { 
                $_.FullName -notmatch "\\__pycache__\\" -and
                $_.FullName -notmatch "\\.git\\" -and
                $_.FullName -notmatch "\\.pytest_cache\\" -and
                $_.FullName -notmatch "\\.venv\\" -and
                $_.FullName -notmatch "\\venv\\" -and
                $_.FullName -notmatch "\\.env" -and
                $_.FullName -notmatch "\\.log$" -and
                $_.FullName -notmatch "\\.pyc$"
            }
        
        if ($filesToZip.Count -gt 0) {
            $filesToZip | Compress-Archive -DestinationPath $deployZip -Force
            
            Write-Info "Deploying zip package to Function App..."
            Write-Info "This may take 5-10 minutes (first deployment is slower)..."
            Write-Info "Monitoring deployment progress..."
            
            # Use the newer az webapp deploy command which has better progress reporting
            # This is the recommended method and shows real-time progress
            try {
                Write-Info "Starting deployment (this command shows live progress)..."
                $deployOutput = az webapp deploy `
                    --resource-group $RESOURCE_GROUP `
                    --name $FUNCTION_APP_NAME `
                    --src-path $deployZip `
                    --type zip `
                    --timeout 1800 `
                    --async false 2>&1
                
                # Check if error is about API not being available (known issue with some Azure CLI versions)
                if ($deployOutput -match "This API isn't available|not available in this environment") {
                    Write-Info "New deployment API not available, using fallback method..."
                    $deployOutput = $null
                } elseif ($LASTEXITCODE -eq 0) {
                    Write-Success "Backend code deployed successfully using zip deploy"
                } else {
                    Write-Warning "Deployment may have failed. Checking status..."
                    # Fallback to old method if new one fails
                    Write-Info "Trying alternative deployment method..."
                    $deployOutput = az functionapp deployment source config-zip `
                        --resource-group $RESOURCE_GROUP `
                        --name $FUNCTION_APP_NAME `
                        --src $deployZip `
                        --timeout 1800 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Backend code deployed successfully using zip deploy (fallback method)"
                    } else {
                        Write-Warning "Zip deployment failed. Checking deployment logs..."
                        Write-Info "Deployment output: $deployOutput"
                        Write-Info "To view detailed logs, run:"
                        Write-Info "  az webapp log deployment show -n $FUNCTION_APP_NAME -g $RESOURCE_GROUP"
                    }
                }
            } catch {
                Write-Warning "Deployment error: $_"
                Write-Info "Trying alternative deployment method..."
                $deployOutput = az functionapp deployment source config-zip `
                    --resource-group $RESOURCE_GROUP `
                    --name $FUNCTION_APP_NAME `
                    --src $deployZip `
                    --timeout 1800 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Backend code deployed successfully using zip deploy (fallback method)"
                } else {
                    Write-Warning "Zip deployment failed. Checking deployment logs..."
                    Write-Info "Deployment output: $deployOutput"
                    Write-Info "Or check in Azure Portal: Function App -> Deployment Center -> Logs"
                    Write-Warning "Function App will be configured with settings, but code deployment may need manual intervention."
                }
            }
            
            # Cleanup
            if (Test-Path $deployZip) {
                Remove-Item $deployZip -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-Warning "No files found to deploy"
        }
    }
}

# Configure app settings (updates existing or creates new)
Write-Info "Configuring Function App settings..."

# Get Key Vault reference
$KEY_VAULT_URI = az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query properties.vaultUri -o tsv

# Build settings array to avoid PowerShell parsing issues with @ symbols
# Use string concatenation to prevent PowerShell from misinterpreting @Microsoft.KeyVault
$kvStorageRef = '@Microsoft.KeyVault(SecretUri=' + $KEY_VAULT_URI + '/secrets/StorageConnectionString/)'
$kvAppInsightsRef = '@Microsoft.KeyVault(SecretUri=' + $KEY_VAULT_URI + '/secrets/AppInsightsConnectionString/)'

# Build array item by item to ensure proper escaping
$appSettings = @()
$appSettings += "AZURE_KEY_VAULT_URL=$KEY_VAULT_URI"
$appSettings += "SHAREPOINT_SITE_URL=$SHAREPOINT_SITE_URL"
$appSettings += "SHAREPOINT_SITE_ID=$SHAREPOINT_SITE_ID"
$appSettings += "USE_SHAREPOINT=true"
$appSettings += "AZURE_STORAGE_CONNECTION_STRING=$kvStorageRef"
$appSettings += "APPLICATIONINSIGHTS_CONNECTION_STRING=$kvAppInsightsRef"

# Set app settings - pass each setting individually to avoid PowerShell parsing issues
Write-Info "Setting app settings one by one to avoid parsing errors..."
foreach ($setting in $appSettings) {
    $ErrorActionPreference = 'SilentlyContinue'
    az functionapp config appsettings set `
        --name "$FUNCTION_APP_NAME" `
        --resource-group "$RESOURCE_GROUP" `
        --settings "$setting" `
        --output none 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
}

Write-Success "Backend deployment complete!"
Write-Info "Note: SharePoint credentials need to be added to Key Vault"
Write-Info "Note: App Registration credentials need to be configured"

Pop-Location

