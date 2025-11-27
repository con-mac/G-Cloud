# Build and Push Docker Images Script (PowerShell)
# Builds frontend Docker image and pushes to Azure Container Registry
# This script should be run once before deployment, or when images need updating

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

$ACR_NAME = $config.ACR_NAME
$IMAGE_TAG = $config.IMAGE_TAG
$RESOURCE_GROUP = $config.RESOURCE_GROUP

function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param([string]$msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-Error { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Info "Building and pushing Docker images to Azure Container Registry..."

# Validate configuration
if ([string]::IsNullOrWhiteSpace($ACR_NAME)) {
    Write-Error "ACR_NAME is missing in config file!"
    Write-Info "Please run deploy.ps1 and configure Container Registry"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($IMAGE_TAG)) {
    $IMAGE_TAG = "latest"
    Write-Warning "IMAGE_TAG not specified, using 'latest'"
}

if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) {
    Write-Error "RESOURCE_GROUP is missing in config file!"
    exit 1
}

# Check if Docker is available
Write-Info "Checking Docker installation..."
$ErrorActionPreference = 'SilentlyContinue'
$dockerVersion = docker --version 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not installed or not in PATH"
    Write-Info "Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
}

Write-Success "Docker found: $dockerVersion"

# Verify ACR exists
Write-Info "Verifying Azure Container Registry: $ACR_NAME..."
$ErrorActionPreference = 'SilentlyContinue'
$acrExists = az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query "name" -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($acrExists)) {
    Write-Error "Azure Container Registry '$ACR_NAME' not found in resource group '$RESOURCE_GROUP'"
    Write-Info "Please run deploy.ps1 first to create the ACR"
    exit 1
}

Write-Success "ACR verified: $ACR_NAME"

# Check if frontend directory exists
# Try multiple paths: relative to pa-deployment/scripts, relative to pa-deployment, or root
$frontendPath = $null
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$possiblePaths = @(
    "$scriptDir\..\frontend",           # From pa-deployment/scripts -> pa-deployment/frontend
    "$scriptDir\..\..\frontend",        # From pa-deployment/scripts -> root/frontend
    "..\frontend",                      # Relative from current directory
    "..\..\frontend",                   # Relative from current directory (if in scripts)
    "frontend"                          # If frontend is in current directory
)

foreach ($path in $possiblePaths) {
    $fullPath = Resolve-Path $path -ErrorAction SilentlyContinue
    if ($fullPath -and (Test-Path $fullPath)) {
        $frontendPath = $path
        Write-Info "Found frontend directory: $path"
        break
    }
}

if ($null -eq $frontendPath) {
    Write-Error "Frontend directory not found!"
    Write-Info ""
    Write-Info "Searched in the following locations:"
    foreach ($path in $possiblePaths) {
        Write-Info "  - $path"
    }
    Write-Info ""
    Write-Info "Please ensure:"
    Write-Info "  1. Frontend directory exists (either in root or pa-deployment)"
    Write-Info "  2. You're running from pa-deployment directory"
    Write-Info ""
    Write-Info "Current directory: $(Get-Location)"
    exit 1
}

Write-Info "Frontend directory found: $frontendPath"

# Check if Dockerfile exists
if (-not (Test-Path "$frontendPath\Dockerfile")) {
    Write-Error "Dockerfile not found in frontend directory!"
    Write-Info "Expected: $frontendPath\Dockerfile"
    exit 1
}

Write-Success "Dockerfile found"

# Login to ACR
Write-Info "Logging in to Azure Container Registry..."
az acr login --name "$ACR_NAME" | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to login to ACR"
    exit 1
}

Write-Success "Logged in to ACR"

# Build and push frontend image
Write-Info "Building frontend Docker image..."
Write-Info "This may take several minutes (first build is slower)..."
Write-Info ""

$acrLoginServer = "$ACR_NAME.azurecr.io"
$imageName = "frontend"
$fullImageName = "$acrLoginServer/${imageName}:$IMAGE_TAG"

# Ask user which build method to use
Write-Host ""
Write-Host "Build method:"
Write-Host "  [1] ACR build (builds in Azure cloud, no local Docker needed) - Recommended for dev team"
Write-Host "  [2] Local build and push (requires Docker Desktop) - Recommended for initial setup"
Write-Host ""
$buildMethod = Read-Host "Select build method (1 or 2) [1]"
if ([string]::IsNullOrWhiteSpace($buildMethod)) {
    $buildMethod = "1"
}

if ($buildMethod -eq "2") {
    # Local build method
    Write-Info "Using local Docker build..."
    
    # Build image locally
    Write-Info "Building Docker image locally..."
    docker build -t "$fullImageName" -f "$frontendPath\Dockerfile" "$frontendPath"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Docker image locally"
        exit 1
    }
    
    Write-Success "Image built locally: $fullImageName"
    
    # Push to ACR
    Write-Info "Pushing image to ACR..."
    docker push "$fullImageName"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push image to ACR"
        exit 1
    }
    
    Write-Success "Image pushed to ACR: $fullImageName"
} else {
    # ACR build method (builds in Azure)
    Write-Info "Using ACR build task (builds in Azure cloud, no local Docker needed)..."
    
    # Convert path to absolute and normalize separators for ACR build
    $absoluteFrontendPath = (Resolve-Path $frontendPath).Path
    $dockerfilePath = Join-Path $absoluteFrontendPath "Dockerfile"
    
    if (-not (Test-Path $dockerfilePath)) {
        Write-Error "Dockerfile not found at: $dockerfilePath"
        exit 1
    }
    
    # ACR build uses the directory as context, Dockerfile path is relative to context
    # Since context is the frontend directory, Dockerfile is just "Dockerfile"
    Write-Info "Build context: $absoluteFrontendPath"
    Write-Info "Dockerfile: Dockerfile (relative to context)"
    
    az acr build `
        --registry "$ACR_NAME" `
        --image "${imageName}:$IMAGE_TAG" `
        --file "Dockerfile" `
        "$absoluteFrontendPath" `
        --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build frontend image in ACR"
        Write-Info "Check the error above for details"
        Write-Info "Build context was: $absoluteFrontendPath"
        exit 1
    }
    
    Write-Success "Frontend image built successfully in ACR: $fullImageName"
}

# Verify image was pushed
Write-Info "Verifying image in ACR..."
$ErrorActionPreference = 'SilentlyContinue'
$imageTags = az acr repository show-tags --name "$ACR_NAME" --repository "$imageName" --query "[?name=='$IMAGE_TAG'].name" -o tsv 2>&1
$ErrorActionPreference = 'Stop'

if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($imageTags)) {
    Write-Success "Image verified in ACR: ${imageName}:$IMAGE_TAG"
} else {
    Write-Warning "Could not verify image tag, but build completed"
}

Write-Success "Build and push complete!"
Write-Info ""
Write-Info "Image details:"
Write-Info "  Registry: $acrLoginServer"
Write-Info "  Image: ${imageName}:$IMAGE_TAG"
Write-Info "  Full name: $fullImageName"
Write-Info ""
Write-Info "Next steps:"
Write-Info "  1. Run deployment: .\deploy.ps1"
Write-Info "  2. Or deploy frontend only: .\scripts\deploy-frontend.ps1"
Write-Info ""
Write-Info "To view images in ACR:"
Write-Info "  az acr repository show-tags --name $ACR_NAME --repository $imageName --output table"

