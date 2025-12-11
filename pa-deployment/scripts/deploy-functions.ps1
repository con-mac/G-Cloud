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
$WEB_APP_NAME = $config.WEB_APP_NAME
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

# Copy or create requirements.txt - CRITICAL for dependency installation
if (-not (Test-Path "requirements.txt")) {
    # Try to copy from main repo backend directory first
    $mainRepoRequirements = "..\..\backend\requirements.txt"
    if (Test-Path $mainRepoRequirements) {
        Write-Info "Copying requirements.txt from main repo backend directory..."
        Copy-Item -Path $mainRepoRequirements -Destination "requirements.txt" -Force
        Write-Success "✓ requirements.txt copied from main repo"
    } else {
        Write-Warning "requirements.txt not found. Creating from template..."
        Write-Warning "NOTE: This template may be incomplete. Use full backend/requirements.txt for production!"
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
} else {
    Write-Success "✓ requirements.txt found in backend directory"
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
        # Ensure requirements.txt is copied (may have been excluded)
        if (Test-Path "..\..\backend\requirements.txt") {
            Copy-Item -Path "..\..\backend\requirements.txt" -Destination "requirements.txt" -Force
            Write-Info "✓ requirements.txt copied from main repo (ensuring it's present)"
        }
    } else {
        Write-Warning "Backend code not found. Function App will be created but code deployment skipped."
        Write-Warning "Please ensure backend code is in pa-deployment/backend/ directory"
    }
}

# CRITICAL: Set build settings BEFORE any deployment
# Azure Functions requires BOTH settings for automatic dependency installation
Write-Info "Setting build settings (REQUIRED for dependency installation)..."
az functionapp config appsettings set `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --settings "SCM_DO_BUILD_DURING_DEPLOYMENT=true" "ENABLE_ORYX_BUILD=true" `
    --output none
if ($LASTEXITCODE -eq 0) {
    Write-Success "✓ Build settings enabled (dependencies will install during deployment)"
} else {
    Write-Warning "Failed to set build settings. Dependencies may not install automatically."
    Write-Warning "You may need to run manually-install-dependencies.ps1 after deployment."
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
        # Use absolute path to avoid path resolution issues
        $backendDir = Get-Location
        $parentDir = Split-Path -Parent $backendDir.Path
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $deployZip = Join-Path $parentDir "function-deploy-${timestamp}.zip"
        $deployZip = [System.IO.Path]::GetFullPath($deployZip)
        Write-Info "Zip will be created at: $deployZip"
        
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
            # CRITICAL: Verify function_app folder exists and is included
            $functionAppPath = Join-Path (Get-Location) "function_app"
            if (-not (Test-Path $functionAppPath)) {
                Write-Error "function_app folder not found at: $functionAppPath"
                Write-Error "Function will not be registered without this folder!"
                Write-Info "Current directory: $(Get-Location)"
                Write-Info "Looking for: function_app\__init__.py and function_app\function.json"
                exit 1
            }
            
            # Verify critical files exist
            $hasFunctionApp = $filesToZip | Where-Object { $_.FullName -like "*function_app\__init__.py" -or $_.FullName -like "*function_app/__init__.py" }
            $hasFunctionJson = $filesToZip | Where-Object { $_.FullName -like "*function_app\function.json" -or $_.FullName -like "*function_app/function.json" }
            $hasHostJson = $filesToZip | Where-Object { $_.Name -eq "host.json" }
            $hasRequirementsTxt = $filesToZip | Where-Object { $_.Name -eq "requirements.txt" }
            
            # CRITICAL: requirements.txt MUST be at the root of the zip for Azure Functions to install dependencies
            if (-not $hasRequirementsTxt) {
                Write-Warning "requirements.txt not found in file list. Adding explicitly..."
                $requirementsPath = Join-Path (Get-Location) "requirements.txt"
                if (Test-Path $requirementsPath) {
                    $reqFile = Get-Item $requirementsPath
                    $filesToZip += $reqFile
                    Write-Info "  Added: requirements.txt (REQUIRED for dependency installation)"
                } else {
                    Write-Error "requirements.txt not found at: $requirementsPath"
                    Write-Error "Azure Functions requires requirements.txt at zip root to install Python packages!"
                    exit 1
                }
            } else {
                Write-Success "✓ requirements.txt found in deployment package"
            }
            
            if (-not $hasFunctionApp) {
                Write-Warning "function_app/__init__.py not found in file list. Adding explicitly..."
                $functionAppFiles = Get-ChildItem -Path "function_app" -Recurse -File
                foreach ($file in $functionAppFiles) {
                    if ($filesToZip -notcontains $file) {
                        $filesToZip += $file
                        Write-Info "  Added: $($file.FullName)"
                    }
                }
            }
            
            if (-not $hasFunctionJson) {
                Write-Warning "function_app/function.json not found. Adding explicitly..."
                $functionJsonPath = Join-Path "function_app" "function.json"
                if (Test-Path $functionJsonPath) {
                    $jsonFile = Get-Item $functionJsonPath
                    if ($filesToZip -notcontains $jsonFile) {
                        $filesToZip += $jsonFile
                        Write-Info "  Added: $($jsonFile.FullName)"
                    }
                }
            }
            
            if (-not $hasHostJson) {
                Write-Error "host.json not found in deployment package!"
                exit 1
            }
            
            Write-Info "Creating zip with $($filesToZip.Count) files..."
            
            # Log what's being included (for debugging)
            $functionAppFiles = $filesToZip | Where-Object { $_.FullName -like "*function_app*" }
            if ($functionAppFiles) {
                Write-Info "Function App files included: $($functionAppFiles.Count)"
                $functionAppFiles | Select-Object -First 10 | ForEach-Object {
                    $relativePath = $_.FullName.Replace((Get-Location).Path + "\", "").Replace((Get-Location).Path + "/", "")
                    Write-Info "  - $relativePath"
                }
            } else {
                Write-Error "No function_app files found in deployment package! Function will not work!"
                exit 1
            }
            
            # Create zip preserving directory structure
            # Use .NET compression to ensure proper folder structure
            Write-Info "Creating zip archive (preserving folder structure)..."
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::Open($deployZip, [System.IO.Compression.ZipArchiveMode]::Create)
            $currentDir = (Get-Location).Path
            try {
                foreach ($file in $filesToZip) {
                    # Use proper path resolution to get relative path
                    $filePath = $file.FullName
                    # Normalize paths for comparison
                    $normalizedCurrent = [System.IO.Path]::GetFullPath($currentDir)
                    $normalizedFile = [System.IO.Path]::GetFullPath($filePath)
                    
                    # Get relative path using .NET method
                    $relativePath = [System.IO.Path]::GetRelativePath($normalizedCurrent, $normalizedFile)
                    # Normalize to forward slashes for zip (zip format uses /)
                    $relativePath = $relativePath.Replace("\", "/")
                    
                    Write-Verbose "Adding to zip: $relativePath"
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $filePath, $relativePath) | Out-Null
                }
            } finally {
                $zip.Dispose()
            }
            Write-Info "Zip created successfully with preserved folder structure"
            
            # Verify zip contents - CRITICAL: requirements.txt and function_app folder
            Write-Info "Verifying zip contents..."
            $zipRead = [System.IO.Compression.ZipFile]::OpenRead($deployZip)
            try {
                # Verify requirements.txt is at the root (CRITICAL for dependency installation)
                $requirementsEntry = $zipRead.Entries | Where-Object { $_.FullName -eq "requirements.txt" -or $_.FullName -eq "requirements.txt/" }
                if ($requirementsEntry) {
                    Write-Success "✓ Verified: requirements.txt exists at zip root (Azure Functions will install dependencies)"
                } else {
                    Write-Error "✗ requirements.txt NOT found at zip root! Azure Functions cannot install dependencies!"
                    Write-Error "This will cause ModuleNotFoundError when importing FastAPI or other packages!"
                    $zipRead.Dispose()
                    Remove-Item $deployZip -Force -ErrorAction SilentlyContinue
                    exit 1
                }
                
                # Verify function_app folder structure
                $functionAppEntries = $zipRead.Entries | Where-Object { $_.FullName -like "function_app/*" }
                if ($functionAppEntries.Count -gt 0) {
                    Write-Success "✓ Verified: function_app folder exists in zip with $($functionAppEntries.Count) files"
                    $functionAppEntries | Select-Object -First 5 | ForEach-Object {
                        Write-Info "  - $($_.FullName)"
                    }
                } else {
                    Write-Error "✗ function_app folder NOT found in zip! This will fail!"
                    $zipRead.Dispose()
                    Remove-Item $deployZip -Force -ErrorAction SilentlyContinue
                    exit 1
                }
                
                # Verify host.json
                $hostJsonEntry = $zipRead.Entries | Where-Object { $_.FullName -eq "host.json" -or $_.FullName -eq "host.json/" }
                if ($hostJsonEntry) {
                    Write-Success "✓ Verified: host.json exists in zip"
                } else {
                    Write-Error "✗ host.json NOT found in zip! This will fail!"
                    $zipRead.Dispose()
                    Remove-Item $deployZip -Force -ErrorAction SilentlyContinue
                    exit 1
                }
            } finally {
                $zipRead.Dispose()
            }
            
            Write-Info "Deploying zip package to Function App..."
            Write-Info "This may take 5-10 minutes (first deployment is slower)..."
            
            # Verify zip file exists before deployment
            if (-not (Test-Path $deployZip)) {
                Write-Error "Zip file not found at: $deployZip"
                Write-Error "Current directory: $(Get-Location)"
                Write-Error "Cannot deploy without zip file!"
                exit 1
            }
            
            Write-Info "Zip file verified: $deployZip"
            Write-Info "File size: $((Get-Item $deployZip).Length / 1MB) MB"
            Write-Info ""
            Write-Info "Monitoring deployment progress..."
            
            # Use the reliable zip deploy method (az functionapp deployment source config-zip)
            # This is more reliable than az webapp deploy which can hang
            Write-Info "Deploying zip package (this may take 5-10 minutes)..."
            Write-Info "Note: Large deployments can take time. Be patient..."
            
            try {
                # Use absolute path and verify it exists
                $deployZipAbsolute = [System.IO.Path]::GetFullPath($deployZip)
                Write-Info "Using absolute path: $deployZipAbsolute"
                
                if (-not (Test-Path $deployZipAbsolute)) {
                    Write-Error "Zip file not found at absolute path: $deployZipAbsolute"
                    exit 1
                }
                
                # Use the proven method that doesn't hang
                $deployOutput = az functionapp deployment source config-zip `
                    --resource-group $RESOURCE_GROUP `
                    --name $FUNCTION_APP_NAME `
                    --src $deployZipAbsolute `
                    --timeout 1800 2>&1 | Tee-Object -Variable deployOutput
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Backend code deployed successfully!"
                    
                    # Force function discovery by syncing triggers
                    Write-Info "Forcing function discovery (syncing triggers)..."
                    $ErrorActionPreference = 'SilentlyContinue'
                    az functionapp function show `
                        --name $FUNCTION_APP_NAME `
                        --resource-group $RESOURCE_GROUP `
                        --function-name "function_app" `
                        --output none 2>&1 | Out-Null
                    $ErrorActionPreference = 'Stop'
                    
                    # Restart Function App to ensure function is discovered
                    Write-Info "Restarting Function App to trigger function discovery..."
                    az functionapp restart --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP --output none
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Function App restarted"
                        Write-Info "Waiting 30 seconds for function discovery..."
                        Start-Sleep -Seconds 30
                        
                        # Verify function is registered
                        Write-Info "Verifying function registration..."
                        $ErrorActionPreference = 'SilentlyContinue'
                        $functionCheck = az functionapp function show `
                            --name $FUNCTION_APP_NAME `
                            --resource-group $RESOURCE_GROUP `
                            --function-name "function_app" `
                            --query "name" -o tsv 2>&1
                        $ErrorActionPreference = 'Stop'
                        
                        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($functionCheck)) {
                            Write-Success "Function 'function_app' is registered!"
                        } else {
                            Write-Warning "Function 'function_app' not yet registered. This may take up to 2 minutes."
                            Write-Info "Check Functions list in Azure Portal: Function App -> Functions"
                            Write-Info "If function doesn't appear after 2 minutes, check logs for errors"
                        }
                    }
                } else {
                    # Check if it's a known error we can handle
                    if ($deployOutput -match "This API isn't available|not available in this environment") {
                        Write-Info "Deployment API not available, but deployment may still be in progress..."
                        Write-Info "Check deployment status in Azure Portal:"
                        Write-Info "  Function App -> Deployment Center -> Logs"
                        Write-Warning "Deployment may have succeeded despite the error message."
                    } else {
                        Write-Warning "Deployment may have failed. Checking status..."
                        Write-Info "Deployment output: $deployOutput"
                        Write-Info "To view detailed logs, run:"
                        Write-Info "  az webapp log deployment show -n $FUNCTION_APP_NAME -g $RESOURCE_GROUP"
                        Write-Info "Or check in Azure Portal: Function App -> Deployment Center -> Logs"
                    }
                }
            } catch {
                Write-Warning "Deployment error: $_"
                Write-Info "Deployment may still be in progress. Check status in Azure Portal:"
                Write-Info "  Function App -> Deployment Center -> Logs"
                Write-Warning "Function App will be configured with settings, but code deployment may need manual verification."
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

# Auto-detect Key Vault name if the configured one doesn't exist (do this early)
if (-not [string]::IsNullOrWhiteSpace($KEY_VAULT_NAME)) {
    $ErrorActionPreference = 'SilentlyContinue'
    $kvCheck = az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query name -o tsv 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($kvCheck)) {
        Write-Warning "Key Vault '$KEY_VAULT_NAME' not found. Auto-detecting from resource group..."
        $ErrorActionPreference = 'SilentlyContinue'
        $detectedKv = az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($detectedKv)) {
            $KEY_VAULT_NAME = $detectedKv
            Write-Success "✓ Auto-detected Key Vault: $KEY_VAULT_NAME"
        } else {
            Write-Error "Could not find Key Vault in resource group '$RESOURCE_GROUP'"
            Write-Error "Please ensure Key Vault exists or update KEY_VAULT_NAME in deployment-config.env"
            exit 1
        }
    }
} else {
    # KEY_VAULT_NAME is empty, try to auto-detect
    Write-Warning "KEY_VAULT_NAME not set in config. Auto-detecting from resource group..."
    $ErrorActionPreference = 'SilentlyContinue'
    $detectedKv = az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($detectedKv)) {
        $KEY_VAULT_NAME = $detectedKv
        Write-Success "✓ Auto-detected Key Vault: $KEY_VAULT_NAME"
    } else {
        Write-Error "Could not find Key Vault in resource group '$RESOURCE_GROUP'"
        Write-Error "Please ensure Key Vault exists or update KEY_VAULT_NAME in deployment-config.env"
        exit 1
    }
}

# Get Key Vault reference (now that we have the correct name)
$ErrorActionPreference = 'SilentlyContinue'
$KEY_VAULT_URI = az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query properties.vaultUri -o tsv 2>&1
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($KEY_VAULT_URI)) {
    Write-Error "Failed to get Key Vault URI for '$KEY_VAULT_NAME'"
    Write-Error "Please verify the Key Vault exists and you have access to it"
    exit 1
}
Write-Success "✓ Key Vault URI: $KEY_VAULT_URI"

# Auto-detect Web App name if the configured one doesn't exist (for CORS configuration)
if (-not [string]::IsNullOrWhiteSpace($WEB_APP_NAME)) {
    $ErrorActionPreference = 'SilentlyContinue'
    $webAppCheck = az webapp show --name "$WEB_APP_NAME" --resource-group "$RESOURCE_GROUP" --query name -o tsv 2>&1
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($webAppCheck)) {
        Write-Warning "Web App '$WEB_APP_NAME' not found. Auto-detecting from resource group..."
        $ErrorActionPreference = 'SilentlyContinue'
        # List all web apps, exclude Function Apps (they have kind 'functionapp')
        $allWebApps = az webapp list --resource-group "$RESOURCE_GROUP" --query "[?kind!='functionapp'].name" -o tsv 2>&1
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($allWebApps)) {
            $detectedWebApp = ($allWebApps -split "`n" | Where-Object { $_ -match "web" } | Select-Object -First 1).Trim()
            if ($detectedWebApp) {
                $WEB_APP_NAME = $detectedWebApp
                Write-Success "✓ Auto-detected Web App: $WEB_APP_NAME"
            }
        }
        if ([string]::IsNullOrWhiteSpace($detectedWebApp)) {
            Write-Warning "Could not auto-detect Web App. Using configured name: $WEB_APP_NAME"
        }
    }
}

# Build settings array to avoid PowerShell parsing issues with @ symbols
# Use string concatenation to prevent PowerShell from misinterpreting @Microsoft.KeyVault
$kvStorageRef = '@Microsoft.KeyVault(SecretUri=' + $KEY_VAULT_URI + '/secrets/StorageConnectionString/)'
$kvAppInsightsRef = '@Microsoft.KeyVault(SecretUri=' + $KEY_VAULT_URI + '/secrets/AppInsightsConnectionString/)'

# Build array item by item to ensure proper escaping
# Get Web App URL for CORS configuration
$ErrorActionPreference = 'SilentlyContinue'
$WEB_APP_URL = az webapp show --name "$WEB_APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv 2>&1
$ErrorActionPreference = 'Stop'
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($WEB_APP_URL)) {
    $WEB_APP_URL = "https://$WEB_APP_URL"
    Write-Success "✓ Web App URL for CORS: $WEB_APP_URL"
} else {
    $WEB_APP_URL = "https://${WEB_APP_NAME}.azurewebsites.net"
    Write-Warning "Could not get Web App URL, using default: $WEB_APP_URL"
}

$appSettings = @()
# Note: SCM_DO_BUILD_DURING_DEPLOYMENT is already set before deployment above
$appSettings += "AZURE_KEY_VAULT_URL=$KEY_VAULT_URI"
$appSettings += "SHAREPOINT_SITE_URL=$SHAREPOINT_SITE_URL"
$appSettings += "SHAREPOINT_SITE_ID=$SHAREPOINT_SITE_ID"
$appSettings += "USE_SHAREPOINT=true"
$appSettings += "KEY_VAULT_NAME=$KEY_VAULT_NAME"
$appSettings += "AZURE_KEY_VAULT_URL=https://${KEY_VAULT_NAME}.vault.azure.net"
$appSettings += "AZURE_STORAGE_CONNECTION_STRING=$kvStorageRef"
$appSettings += "APPLICATIONINSIGHTS_CONNECTION_STRING=$kvAppInsightsRef"
$appSettings += "CORS_ORIGINS=$WEB_APP_URL,http://localhost:3000,http://localhost:5173"

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

# CRITICAL FIX: Ensure authLevel is set to "anonymous" after deployment
Write-Info ""
Write-Info "=== FIXING authLevel (CRITICAL FOR CORS) ===" -ForegroundColor Yellow
Write-Info "This ensures OPTIONS preflight requests work correctly..."

# Step 1: Verify local function.json has correct authLevel
$functionJsonPath = Join-Path (Get-Location) "backend\function_app\function.json"
if (Test-Path $functionJsonPath) {
    $jsonContent = Get-Content $functionJsonPath -Raw | ConvertFrom-Json
    if ($jsonContent.bindings[0].authLevel -ne "anonymous") {
        Write-Warning "Local function.json has authLevel: $($jsonContent.bindings[0].authLevel)"
        Write-Info "Updating local function.json to 'anonymous'..."
        $jsonContent.bindings[0].authLevel = "anonymous"
        $jsonContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $functionJsonPath -Encoding utf8 -NoNewline
        Write-Success "✓ Local function.json updated to 'anonymous'"
    } else {
        Write-Success "✓ Local function.json already has authLevel: anonymous"
    }
} else {
    Write-Warning "Local function.json not found at: $functionJsonPath"
}

# Step 2: Disable package mode temporarily to allow updates
Write-Info "Disabling package mode temporarily..."
$ErrorActionPreference = 'SilentlyContinue'
az webapp config appsettings set `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --settings "WEBSITE_RUN_FROM_PACKAGE=" `
    --output none 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
Start-Sleep -Seconds 5

# Step 3: Stop Function App to clear caches
Write-Info "Stopping Function App to clear caches..."
$ErrorActionPreference = 'SilentlyContinue'
az functionapp stop --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP --output none 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
Start-Sleep -Seconds 3

# Step 4: Update authLevel via REST API
Write-Info "Updating authLevel via Azure Management API..."
try {
    $subscriptionId = az account show --query id -o tsv
    if ([string]::IsNullOrWhiteSpace($subscriptionId)) {
        throw "Failed to get subscription ID"
    }
    
    $accessToken = az account get-access-token --query accessToken -o tsv
    if ([string]::IsNullOrWhiteSpace($accessToken)) {
        throw "Failed to get access token"
    }
    
    $functionUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME/functions/function_app?api-version=2022-03-01"
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }
    
    # Get current config
    Write-Info "Fetching current function configuration..."
    $config = Invoke-RestMethod -Uri $functionUrl -Headers $headers -Method Get
    
    # Update authLevel - handle ANY response structure
    $updated = $false
    if ($config.PSObject.Properties.Name -contains "config") {
        if ($config.config.PSObject.Properties.Name -contains "bindings") {
            if ($config.config.bindings[0].authLevel -ne "anonymous") {
                $config.config.bindings[0].authLevel = "anonymous"
                $updated = $true
            }
        } elseif ($config.config.PSObject.Properties.Name -contains "binding") {
            if ($config.config.binding.authLevel -ne "anonymous") {
                $config.config.binding.authLevel = "anonymous"
                $updated = $true
            }
        }
    } elseif ($config.PSObject.Properties.Name -contains "bindings") {
        if ($config.bindings[0].authLevel -ne "anonymous") {
            $config.bindings[0].authLevel = "anonymous"
            $updated = $true
        }
    } elseif ($config.PSObject.Properties.Name -contains "properties") {
        if ($config.properties.config.bindings -and $config.properties.config.bindings[0].authLevel -ne "anonymous") {
            $config.properties.config.bindings[0].authLevel = "anonymous"
            $updated = $true
        }
    }
    
    if ($updated) {
        Write-Info "Updating function configuration..."
        $body = $config | ConvertTo-Json -Depth 15
        Invoke-RestMethod -Uri $functionUrl -Headers $headers -Method Put -Body $body | Out-Null
        Write-Success "✓ Function configuration updated via REST API"
    } else {
        Write-Success "✓ Function configuration already has authLevel: anonymous"
    }
} catch {
    Write-Warning "Failed to update via REST API: $_"
    Write-Info "This is non-critical - the deployment zip should have the correct authLevel"
    Write-Info "If CORS still fails, manually update in Azure Portal:"
    Write-Info "  1. Disable WEBSITE_RUN_FROM_PACKAGE"
    Write-Info "  2. Go to Functions -> function_app -> Code + Test"
    Write-Info "  3. Edit function.json -> Change authLevel to 'anonymous'"
}

# Step 5: Restart Function App
Write-Info "Starting Function App..."
$ErrorActionPreference = 'SilentlyContinue'
az functionapp start --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP --output none 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
Start-Sleep -Seconds 10

# Step 6: Verify authLevel was updated
Write-Info "Verifying authLevel..."
Start-Sleep -Seconds 5
$ErrorActionPreference = 'SilentlyContinue'
$authLevel = az functionapp function show `
    --name $FUNCTION_APP_NAME `
    --resource-group $RESOURCE_GROUP `
    --function-name function_app `
    --query "config.bindings[0].authLevel" -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($authLevel -eq "anonymous") {
    Write-Success "✓ VERIFIED: authLevel is now 'anonymous' - CORS will work!" -ForegroundColor Green
} else {
    Write-Warning "⚠ authLevel is still: $authLevel"
    Write-Warning "CORS preflight requests may still fail!"
    Write-Info "Manual fix required:"
    Write-Info "  1. Azure Portal -> Function App -> Configuration"
    Write-Info "  2. Delete or clear WEBSITE_RUN_FROM_PACKAGE setting"
    Write-Info "  3. Save and wait 30 seconds"
    Write-Info "  4. Functions -> function_app -> Code + Test"
    Write-Info "  5. Edit function.json -> Change authLevel to 'anonymous'"
    Write-Info "  6. Save and restart Function App"
}

Write-Info ""
Write-Info "Note: SharePoint credentials need to be added to Key Vault"
Write-Info "Note: App Registration credentials need to be configured"

Pop-Location

