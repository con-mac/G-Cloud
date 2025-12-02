# Script to push ONLY pa-deployment folder to public repository
# This ensures only the deployment folder goes to the public repo

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Push pa-deployment to PUBLIC Repository" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# Get the script directory (pa-deployment folder)
$paDeploymentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $paDeploymentPath
$tempRepoPath = Join-Path $env:TEMP "g-cloud-pa-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "[INFO] Creating temporary repository for public push..." -ForegroundColor Blue
Write-Host "[INFO] Source: $paDeploymentPath" -ForegroundColor Gray
Write-Host "[INFO] Temp repo: $tempRepoPath" -ForegroundColor Gray
Write-Host ""

# Create temporary directory
if (Test-Path $tempRepoPath) {
    Remove-Item $tempRepoPath -Recurse -Force
}
New-Item -ItemType Directory -Path $tempRepoPath -Force | Out-Null

try {
    # Initialize git repo
    Set-Location $tempRepoPath
    git init | Out-Null
    
    # Copy pa-deployment contents (excluding .git if it exists)
    Write-Host "[INFO] Copying pa-deployment files..." -ForegroundColor Blue
    Get-ChildItem $paDeploymentPath -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
        Copy-Item $_.FullName -Destination $tempRepoPath -Recurse -Force
    }
    
    # Create .gitignore for public repo
    $gitignoreContent = @"
# Environment variables
*.env
!*.env.template
config/deployment-config.env
config/deployment-config.env.*

# Python
__pycache__/
*.py[cod]
venv/
env/

# Node
node_modules/
dist/
build/
*.log

# Azure
.azure/
*.publishsettings

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Secrets
secrets/
*.key
*.pem

# Temporary files
tmp/
temp/
*.tmp

*.Zone.Identifier
"@
    $gitignoreContent | Out-File -FilePath (Join-Path $tempRepoPath ".gitignore") -Encoding utf8
    
    # Add public repo as remote
    git remote add origin https://github.com/con-mac/G-Cloud.git
    
    # Check if public repo exists and has content
    Write-Host "[INFO] Checking public repository status..." -ForegroundColor Blue
    $remoteExists = git ls-remote --heads origin main 2>&1
    if ($LASTEXITCODE -eq 0 -and $remoteExists) {
        Write-Host "[WARNING] Public repository already has content!" -ForegroundColor Yellow
        Write-Host "[WARNING] This will FORCE PUSH and replace everything with pa-deployment only!" -ForegroundColor Red
        Write-Host ""
        $confirm = Read-Host "Type 'YES' to proceed with force push (this will DELETE all non-pa-deployment content from public repo)"
        if ($confirm -ne "YES") {
            Write-Host "[INFO] Aborted. No changes made." -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Stage all files
    Write-Host "[INFO] Staging files..." -ForegroundColor Blue
    git add .
    
    # Check what will be committed
    $filesToCommit = git diff --cached --name-only
    Write-Host "[INFO] Files to commit:" -ForegroundColor Blue
    $filesToCommit | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    
    # Commit
    Write-Host "[INFO] Creating commit..." -ForegroundColor Blue
    git commit -m "PA Deployment Repository - pa-deployment folder only" | Out-Null
    
    # Push to public repo
    Write-Host "[INFO] Pushing to public repository..." -ForegroundColor Blue
    Write-Host "[WARNING] This will FORCE PUSH and replace all content!" -ForegroundColor Yellow
    git push -u origin main --force
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "[SUCCESS] Public repository updated with pa-deployment only!" -ForegroundColor Green
        Write-Host "[INFO] Verify at: https://github.com/con-mac/G-Cloud" -ForegroundColor Blue
    } else {
        Write-Host "[ERROR] Push failed!" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Set-Location $projectRoot
    if (Test-Path $tempRepoPath) {
        Write-Host "[INFO] Cleaning up temporary repository..." -ForegroundColor Blue
        Remove-Item $tempRepoPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "[INFO] Done!" -ForegroundColor Green

